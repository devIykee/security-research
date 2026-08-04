// SPDX-License-Identifier: MIT
// Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OpenFairToken} from "./OpenFairToken.sol";
import {OpenSimpleToken} from "./OpenSimpleToken.sol";
import {
    OpenLaunch, INonfungiblePositionManager, IUniswapV3Factory, IUniswapV3PoolState, IWETH9
} from "./OpenLaunch.sol";
import {OpenLPHarvester} from "./OpenLPHarvester.sol";
import {OpenTeamVesting} from "./OpenTeamVesting.sol";
import {LaunchDeployer} from "./LaunchDeployer.sol";
import {SimpleTokenDeployer} from "./SimpleTokenDeployer.sol";
import {FairTokenDeployer} from "./FairTokenDeployer.sol";

/**
 * @title LaunchFactory
 * @notice openfair.app launch factory: `createLaunch` deploys, wires and opens a
 * full fair-launch set (token + bonding curve + LP harvester + optional team
 * vesting) in one transaction. Every launch is a fully-deployed immutable
 * contract – no clones, no proxies, no delegatecall.
 *
 * Power boundaries (deliberately narrow):
 *  - The factory holds NO funds of any launch and has NO authority over live
 *    launches: it cannot pause, mint, upgrade or withdraw anything.
 *  - The owner can only tune platform-side knobs: the flat creation fee and the
 *    platform treasury address for FUTURE launches. Existing launches keep the
 *    values they were created with, immutably.
 *  - New factory versions are new deployments; already-created launches are
 *    never migrated or touched.
 */
contract LaunchFactory is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ----------------------------- Errors -----------------------------
    error WrongPayment(uint256 sent, uint256 required);
    error SelfReferral();
    error BadConfig();
    error UnknownToken();
    error NotCreator();
    error EthSendFailed();
    error VanityNotAllowed();

    /// @notice Curve launches leaving the platform >= this fee share get the
    /// supporter perks: half deploy fee (+ half promo prices in OpenPromotions).
    uint16 public constant SUPPORTER_SHARE_BPS = 5_000;
    /// @notice Vanity addresses require leaving the platform at least this share.
    uint16 public constant VANITY_MIN_SHARE_BPS = 1_500;

    // ----------------------------- Events -----------------------------
    event LaunchCreated(
        address indexed creator,
        address indexed token,
        address launch,
        address harvester,
        address teamVesting,
        address referrer,
        string metadataCID,
        CreateParams params
    );
    event MetadataUpdated(address indexed token, string metadataCID, address indexed updater);
    event DeployFeeChanged(uint256 newFee);
    event SupporterFeeChanged(uint16 newBps);
    event PlatformTreasuryChanged(address newTreasury);
    event DirectListingCreated(
        address indexed creator,
        address indexed token,
        address harvester,
        address pool,
        uint256 liquidityEth,
        uint256 poolTokens,
        string metadataCID,
        DirectParams params
    );

    // ----------------------------- Types ------------------------------

    /// @notice Everything a creator configures for a launch.
    struct CreateParams {
        // identity
        string name;
        string symbol;
        // supply split
        uint256 totalSupply; // 18 decimals
        uint256 saleSupply; // sold on the curve; pool amount is derived from the curve
        // curve
        uint8 curveType; // 0 classic / 1 linear / 2 exponential
        uint256 priceMultiple; // final price / start price, integer >= 2
        uint256 targetEth; // ETH collected over the whole sale (net)
        // fees
        uint16 buyFeeBps; // 0..1000; 0 allowed
        uint16 sellFeeBps; // 0..1000; a high sell fee deters curve-phase snipe-flips
        uint16 platformShareBps; // creator-chosen split of the trade fee, 0..10000 (default UI: 1500)
        address feeRecipient; // 0 = creator
        // trading rules
        bool sellsEnabled;
        uint64 startTime; // 0 = immediately; future = "upcoming" launch
        // anti-snipe (token-wei; 0 disables a layer)
        uint256 walletCapFloor;
        uint256 walletCapPerSec;
        uint256 globalRampPerSec;
        // pool
        uint24 poolFeeTier;
        // team vesting (optional)
        uint256 teamAllocation;
        address teamBeneficiary;
        uint64 teamVestingDuration;
        // dev-buy (optional, disclosed; costs the Fair Launch badge)
        uint256 devBuyEth;
        // vanity address (optional): CREATE2 salt mined off-chain + the service
        // fee quoted by the UI tier. salt = 0 -> ordinary CREATE.
        bytes32 salt;
        uint256 vanityFeeWei;
    }

    struct LaunchInfo {
        address launch; // address(0) for direct listings (no bonding curve)
        address harvester;
        address teamVesting;
        address creator;
        uint64 createdAt;
        string metadataCID;
    }

    /// @notice Instant Uniswap listing (no bonding curve). Two flavours:
    ///  - seeded: the creator sends ETH on top of the deploy fee – a classic
    ///    two-sided pool at price = liquidityEth / poolTokens;
    ///  - single-sided (msg.value == deployFee): ONLY tokens go into the pool,
    ///    in a tick range starting at `startPriceWei`. Zero capital needed; the
    ///    starting price acts as a floor and sets the visible market cap.
    struct DirectParams {
        string name;
        string symbol;
        uint256 totalSupply; // 18 decimals
        uint16 poolBps; // share of supply paired into the pool (10000 = all)
        address feeRecipient; // harvester treasury + non-pool supply recipient; 0 = creator
        uint24 poolFeeTier;
        uint256 startPriceWei; // single-sided only: starting price, wei per whole token
        bytes32 salt; // vanity CREATE2 salt (0 = ordinary CREATE)
        uint256 vanityFeeWei;
        // Share of the LP pool fees (ETH side, collected via harvest()) that
        // goes to the platform – the instant-listing analog of the curve fee
        // split. >= 50% unlocks the same supporter perks.
        uint16 platformShareBps;
        // v1.9: referral for instant listings. address(0) = none; otherwise
        // the referrer receives half of the platform's ETH cut of every LP-fee
        // harvest (mirrors the curve's trade-fee referral split).
        address referrer;
    }

    // --------------------------- Immutables ---------------------------
    /// @notice Uniswap V3 wiring for this chain, fixed per factory deployment.
    address public immutable weth;
    address public immutable positionManager;
    address public immutable uniswapV3Factory;
    /// @notice Stateless CREATE helper for OpenLaunch (EIP-170 size split).
    LaunchDeployer public immutable launchDeployer;
    /// @notice CREATE/CREATE2 helper for instant-listing tokens (vanity support).
    SimpleTokenDeployer public immutable simpleTokenDeployer;
    /// @notice v1.9: CREATE/CREATE2 helper for curve tokens (EIP-170 size split;
    /// curve vanity salts are mined against THIS deployer's address).
    FairTokenDeployer public immutable fairTokenDeployer;

    // ------------------------- Platform config ------------------------
    /// @notice Flat creation fee in the chain's gas token (§П2). The only
    /// near-mandatory platform charge; never taken from traders.
    uint256 public deployFee;
    /// @notice Share of `deployFee` supporters actually pay, in bps.
    /// 5000 = half price (default), 0 = free deploys for supporters.
    uint16 public supporterFeeBps = 5_000;
    /// @notice Platform treasury for the deploy fee and (for future launches)
    /// the platform's trade-fee share.
    address public platformTreasury;

    // ----------------------------- Registry ----------------------------
    address[] public allTokens;
    mapping(address => LaunchInfo) public launches;

    constructor(
        address weth_,
        address positionManager_,
        address uniswapV3Factory_,
        address launchDeployer_,
        address simpleTokenDeployer_,
        address fairTokenDeployer_,
        address platformTreasury_,
        uint256 deployFee_
    ) Ownable(msg.sender) {
        if (weth_ == address(0) || positionManager_ == address(0) || uniswapV3Factory_ == address(0)
                || launchDeployer_ == address(0) || simpleTokenDeployer_ == address(0)
                || fairTokenDeployer_ == address(0) || platformTreasury_ == address(0)) revert BadConfig();
        weth = weth_;
        positionManager = positionManager_;
        uniswapV3Factory = uniswapV3Factory_;
        launchDeployer = LaunchDeployer(launchDeployer_);
        simpleTokenDeployer = SimpleTokenDeployer(simpleTokenDeployer_);
        fairTokenDeployer = FairTokenDeployer(fairTokenDeployer_);
        platformTreasury = platformTreasury_;
        deployFee = deployFee_;
    }

    // --------------------------- Creation -----------------------------

    /**
     * @notice Deploys and opens a full launch in one transaction.
     * @param p        Launch configuration.
     * @param referrer Optional referrer (§М1): earns 50% of the platform's
     *                 trade-fee share of this launch forever, immutably. 0 = none.
     * @param metadataCID IPFS CID of the launch metadata JSON (logo, description,
     *                 socials). Recorded on-chain so the binding is verifiable.
     *
     * msg.value must equal deployFee + p.devBuyEth exactly.
     */
    function createLaunch(CreateParams calldata p, address referrer, string calldata metadataCID)
        external
        payable
        nonReentrant
        returns (address tokenAddr, address launchAddr, address harvesterAddr)
    {
        // Supporter perk: leaving the platform >=50% of the fee halves the deploy fee.
        uint256 effDeployFee = _effDeployFee(p.platformShareBps);
        if (msg.value != effDeployFee + p.devBuyEth + p.vanityFeeWei) {
            revert WrongPayment(msg.value, effDeployFee + p.devBuyEth + p.vanityFeeWei);
        }
        // Vanity addresses are a supporter feature (>=15% platform share).
        if (p.salt != bytes32(0) && p.platformShareBps < VANITY_MIN_SHARE_BPS) revert VanityNotAllowed();
        address feeRecipient = p.feeRecipient == address(0) ? msg.sender : p.feeRecipient;
        if (referrer == msg.sender || (referrer != address(0) && referrer == feeRecipient)) revert SelfReferral();
        if (p.saleSupply == 0 || p.saleSupply + p.teamAllocation > p.totalSupply) revert BadConfig();
        if (p.teamAllocation > 0 && (p.teamBeneficiary == address(0) || p.teamVestingDuration == 0)) revert BadConfig();

        // 1. Token: full supply minted to the factory for distribution below.
        // A non-zero salt makes the address deterministic (vanity addresses).
        // v1.9: deployed via the helper (EIP-170 size split); the helper holds
        // the supply and distributes it below on this factory's orders.
        OpenFairToken token = OpenFairToken(fairTokenDeployer.deploy(p.name, p.symbol, p.totalSupply, p.salt));
        tokenAddr = address(token);

        // 2. Harvester: perpetual LP lock; the ETH side of pool fees goes to the
        // creator's fee recipient.
        // Curve launches keep their referral in the curve's trade fees
        // (OpenLaunch), so the harvester referrer stays empty here.
        OpenLPHarvester harvester =
            new OpenLPHarvester(positionManager, tokenAddr, weth, feeRecipient, platformTreasury, p.platformShareBps, address(0));
        harvesterAddr = address(harvester);

        // 3. Optional team vesting safe.
        address vesting = address(0);
        if (p.teamAllocation > 0) {
            vesting = address(
                new OpenTeamVesting(
                    tokenAddr,
                    p.teamBeneficiary,
                    p.startTime == 0 ? uint64(block.timestamp) : p.startTime,
                    p.teamVestingDuration
                )
            );
        }

        // 4. The bonding curve itself (validates the whole economic config).
        // Deployed through the stateless helper purely for EIP-170 size reasons;
        // the result is a normal fully-deployed immutable contract.
        OpenLaunch launch = OpenLaunch(
            payable(
                launchDeployer.deploy(
                    OpenLaunch.Params({
                        factory: address(this),
                        token: tokenAddr,
                weth: weth,
                positionManager: positionManager,
                uniswapV3Factory: uniswapV3Factory,
                harvester: harvesterAddr,
                creator: msg.sender,
                feeRecipient: feeRecipient,
                platformTreasury: platformTreasury,
                referrer: referrer,
                curveType: p.curveType,
                saleSupply: p.saleSupply,
                targetEth: p.targetEth,
                priceMultiple: p.priceMultiple,
                        buyFeeBps: p.buyFeeBps,
                        sellFeeBps: p.sellFeeBps,
                platformShareBps: p.platformShareBps,
                sellsEnabled: p.sellsEnabled,
                startTime: p.startTime,
                walletCapFloor: p.walletCapFloor,
                walletCapPerSec: p.walletCapPerSec,
                globalRampPerSec: p.globalRampPerSec,
                        poolFeeTier: p.poolFeeTier,
                        teamAllocation: p.teamAllocation
                    })
                )
            )
        );
        launchAddr = address(launch);

        // The launch needs sale + graduation tokens; everything else beyond the
        // team allocation stays with the launch and is burned at graduation.
        if (p.saleSupply + launch.graduationTokens() + p.teamAllocation > p.totalSupply) revert BadConfig();

        // 5. Wire and distribute.
        // v1.9: the token's deployer is the FairTokenDeployer – wire the
        // launchpad through it (gated to this factory).
        fairTokenDeployer.setLaunchpad(address(token), launchAddr);
        if (p.teamAllocation > 0) fairTokenDeployer.transferFor(tokenAddr, vesting, p.teamAllocation);
        fairTokenDeployer.transferFor(tokenAddr, launchAddr, p.totalSupply - p.teamAllocation);
        launch.open(p.startTime);

        // 6. Optional disclosed dev-buy on behalf of the creator.
        if (p.devBuyEth > 0) launch.buyFor{value: p.devBuyEth}(msg.sender, 0);

        // 7. Creation fee (+ vanity service fee) to the platform treasury.
        if (effDeployFee + p.vanityFeeWei > 0) {
            (bool ok,) = platformTreasury.call{value: effDeployFee + p.vanityFeeWei}("");
            if (!ok) revert EthSendFailed();
        }

        // 8. Register + announce (the indexer and the auto-verification worker
        // key off this event).
        launches[tokenAddr] = LaunchInfo({
            launch: launchAddr,
            harvester: harvesterAddr,
            teamVesting: vesting,
            creator: msg.sender,
            createdAt: uint64(block.timestamp),
            metadataCID: metadataCID
        });
        allTokens.push(tokenAddr);
        emit LaunchCreated(msg.sender, tokenAddr, launchAddr, harvesterAddr, vesting, referrer, metadataCID, p);
    }

    // ------------------------ Direct listing ---------------------------

    /**
     * @notice Instant Uniswap listing, no bonding curve: deploys the token,
     * creates the V3 pool seeded with the creator's own ETH
     * (msg.value - deployFee) against `poolBps` of the supply, locks the LP NFT
     * in the harvester forever and opens free trading immediately. The rest of
     * the supply goes to `feeRecipient` – disclosed on-chain, so the UI can
     * honestly show how much the creator holds. Never eligible for the Fair
     * Launch seal.
     */
    function createDirectListing(DirectParams calldata p, string calldata metadataCID)
        external
        payable
        nonReentrant
        returns (address tokenAddr, address harvesterAddr, address pool)
    {
        if (p.platformShareBps > 10_000) revert BadConfig();
        // Supporter perk (instant listings share LP fees instead of curve fees).
        uint256 effDeployFee = _effDeployFee(p.platformShareBps);
        if (msg.value < effDeployFee + p.vanityFeeWei) revert WrongPayment(msg.value, effDeployFee + p.vanityFeeWei);
        if (p.salt != bytes32(0) && p.platformShareBps < VANITY_MIN_SHARE_BPS) revert VanityNotAllowed();
        uint256 liquidityEth = msg.value - effDeployFee - p.vanityFeeWei;
        // Single-sided (token-only) listings need a starting price instead of ETH.
        if (liquidityEth == 0 && p.startPriceWei == 0) revert BadConfig();
        if (p.poolBps == 0 || p.poolBps > 10_000 || p.totalSupply == 0) revert BadConfig();
        int24 spacing = IUniswapV3Factory(uniswapV3Factory).feeAmountTickSpacing(p.poolFeeTier);
        if (spacing <= 0) revert BadConfig();
        address recipient = p.feeRecipient == address(0) ? msg.sender : p.feeRecipient;
        if (p.referrer != address(0) && (p.referrer == msg.sender || p.referrer == recipient)) revert SelfReferral();

        // Scanner-clean plain ERC-20: instant listings have no curve phase, so
        // the pre-graduation transfer gate (which automated token scanners
        // misread as a blacklist) is deliberately absent.
        tokenAddr = simpleTokenDeployer.deploy(p.name, p.symbol, p.totalSupply, address(this), p.salt);
        OpenLPHarvester harvester =
            new OpenLPHarvester(positionManager, tokenAddr, weth, recipient, platformTreasury, p.platformShareBps, p.referrer);
        harvesterAddr = address(harvester);

        uint256 poolTokens = p.totalSupply * p.poolBps / 10_000;
        if (poolTokens == 0) revert BadConfig();
        if (p.totalSupply - poolTokens > 0) IERC20(tokenAddr).safeTransfer(recipient, p.totalSupply - poolTokens);

        pool = liquidityEth > 0
            ? _seedAndLockPool(tokenAddr, harvesterAddr, poolTokens, liquidityEth, p.poolFeeTier, spacing)
            : _singleSidedLockPool(tokenAddr, harvesterAddr, poolTokens, p.startPriceWei, p.poolFeeTier, spacing);

        if (effDeployFee + p.vanityFeeWei > 0) {
            (bool ok,) = platformTreasury.call{value: effDeployFee + p.vanityFeeWei}("");
            if (!ok) revert EthSendFailed();
        }

        launches[tokenAddr] = LaunchInfo({
            launch: address(0),
            harvester: harvesterAddr,
            teamVesting: address(0),
            creator: msg.sender,
            createdAt: uint64(block.timestamp),
            metadataCID: metadataCID
        });
        allTokens.push(tokenAddr);
        emit DirectListingCreated(msg.sender, tokenAddr, harvesterAddr, pool, liquidityEth, poolTokens, metadataCID, p);
    }

    /// @dev Wrap ETH, create + initialize the pool at liquidityEth/poolTokens,
    /// mint a full-range position and lock the NFT in the harvester. Dust:
    /// leftover tokens are burned, leftover WETH is returned to the creator.
    function _seedAndLockPool(
        address tokenAddr,
        address harvesterAddr,
        uint256 poolTokens,
        uint256 liquidityEth,
        uint24 feeTier,
        int24 spacing
    ) private returns (address pool) {
        IWETH9(weth).deposit{value: liquidityEth}();

        (address token0, address token1) = tokenAddr < weth ? (tokenAddr, weth) : (weth, tokenAddr);
        (uint256 amount0, uint256 amount1) =
            tokenAddr < weth ? (poolTokens, liquidityEth) : (liquidityEth, poolTokens);
        uint160 sqrtPriceX96 = uint160(Math.sqrt(Math.mulDiv(amount1, 1 << 192, amount0)));

        INonfungiblePositionManager npm = INonfungiblePositionManager(positionManager);
        pool = npm.createAndInitializePoolIfNecessary(token0, token1, feeTier, sqrtPriceX96);

        IERC20(token0).forceApprove(positionManager, amount0);
        IERC20(token1).forceApprove(positionManager, amount1);
        int24 maxTick = (887_272 / spacing) * spacing;
        (uint256 tokenId,, uint256 used0, uint256 used1) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: feeTier,
                tickLower: -maxTick,
                tickUpper: maxTick,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
        npm.safeTransferFrom(address(this), harvesterAddr, tokenId);

        // Dust after the mint.
        (uint256 tokenLeft, uint256 wethLeft) = tokenAddr < weth ? (amount0 - used0, amount1 - used1) : (amount1 - used1, amount0 - used0);
        if (tokenLeft > 0) OpenSimpleToken(tokenAddr).burn(tokenLeft);
        if (wethLeft > 0) {
            IWETH9(weth).withdraw(wethLeft);
            (bool ok,) = msg.sender.call{value: wethLeft}("");
            if (!ok) revert EthSendFailed();
        }
    }

    /**
     * @dev Single-sided (noxa-style) listing: ONLY tokens go into the pool, in
     * a tick range that starts at `startPriceWei` and extends in the buy
     * direction. Zero ETH required; the pool's visible price (and market cap)
     * starts at `startPriceWei`, which also acts as the price floor – sells can
     * never push the price below the launch price.
     */
    function _singleSidedLockPool(
        address tokenAddr,
        address harvesterAddr,
        uint256 poolTokens,
        uint256 startPriceWei,
        uint24 feeTier,
        int24 spacing
    ) private returns (address pool) {
        bool tokenIs0 = tokenAddr < weth;
        // sqrtPriceX96 for price = startPriceWei per whole (1e18) token.
        (uint256 amt0, uint256 amt1) = tokenIs0 ? (uint256(1e18), startPriceWei) : (startPriceWei, uint256(1e18));
        uint160 sqrtPriceX96 = uint160(Math.sqrt(Math.mulDiv(amt1, 1 << 192, amt0)));

        INonfungiblePositionManager npm = INonfungiblePositionManager(positionManager);
        pool = npm.createAndInitializePoolIfNecessary(
            tokenIs0 ? tokenAddr : weth, tokenIs0 ? weth : tokenAddr, feeTier, sqrtPriceX96
        );

        // Token-only range boundaries around the pool's actual starting tick.
        (, int24 tick,,,,,) = IUniswapV3PoolState(pool).slot0();
        int24 maxTick = (887_272 / spacing) * spacing;
        int24 tickLower;
        int24 tickUpper;
        if (tokenIs0) {
            // all-token0 position: range strictly above the current tick
            tickLower = _ceilAligned(tick + 1, spacing);
            tickUpper = maxTick;
        } else {
            // all-token1 position: range at or below the current tick
            tickUpper = _floorAligned(tick, spacing);
            tickLower = -maxTick;
        }
        if (tickLower >= tickUpper) revert BadConfig();

        IERC20(tokenAddr).forceApprove(positionManager, poolTokens);
        (uint256 tokenId,, uint256 used0, uint256 used1) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: tokenIs0 ? tokenAddr : weth,
                token1: tokenIs0 ? weth : tokenAddr,
                fee: feeTier,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: tokenIs0 ? poolTokens : 0,
                amount1Desired: tokenIs0 ? 0 : poolTokens,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
        npm.safeTransferFrom(address(this), harvesterAddr, tokenId);

        uint256 tokenUsed = tokenIs0 ? used0 : used1;
        if (poolTokens - tokenUsed > 0) OpenSimpleToken(tokenAddr).burn(poolTokens - tokenUsed);
    }

    function _ceilAligned(int24 tick, int24 spacing) private pure returns (int24) {
        int24 aligned = (tick / spacing) * spacing;
        if (aligned < tick) aligned += spacing; // int division truncates toward zero
        return aligned;
    }

    function _floorAligned(int24 tick, int24 spacing) private pure returns (int24) {
        int24 aligned = (tick / spacing) * spacing;
        if (aligned > tick) aligned -= spacing;
        return aligned;
    }

    /// @dev Accept ETH only from WETH (dust unwrap in _seedAndLockPool).
    receive() external payable {
        if (msg.sender != weth) revert BadConfig();
    }

    // --------------------------- Metadata ------------------------------

    /// @notice Creator-only: point the token's metadata to a new IPFS CID.
    /// History stays visible through MetadataUpdated events.
    function updateMetadata(address token, string calldata metadataCID) external {
        LaunchInfo storage info = launches[token];
        if (info.creator == address(0)) revert UnknownToken();
        if (msg.sender != info.creator) revert NotCreator();
        info.metadataCID = metadataCID;
        emit MetadataUpdated(token, metadataCID, msg.sender);
    }

    // ----------------------------- Views -------------------------------

    function totalLaunches() external view returns (uint256) {
        return allTokens.length;
    }

    function getTokens(uint256 offset, uint256 limit) external view returns (address[] memory page) {
        uint256 n = allTokens.length;
        if (offset >= n) return new address[](0);
        uint256 end = offset + limit > n ? n : offset + limit;
        page = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = allTokens[i];
        }
    }

    /// @dev Creation fee actually charged for a given platform share:
    /// supporters (share >= 50%) pay `supporterFeeBps` of the full fee.
    function _effDeployFee(uint16 shareBps) internal view returns (uint256) {
        return shareBps >= SUPPORTER_SHARE_BPS ? deployFee * supporterFeeBps / 10_000 : deployFee;
    }

    // ------------------------- Platform admin --------------------------

    function setDeployFee(uint256 newFee) external onlyOwner {
        deployFee = newFee;
        emit DeployFeeChanged(newFee);
    }

    /// @notice Owner knob for the supporter discount: 5000 = half price
    /// (default), 0 = free deploys for supporters. Never above full price.
    function setSupporterFeeBps(uint16 newBps) external onlyOwner {
        if (newBps > 10_000) revert BadConfig();
        supporterFeeBps = newBps;
        emit SupporterFeeChanged(newBps);
    }

    function setPlatformTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert BadConfig();
        platformTreasury = newTreasury;
        emit PlatformTreasuryChanged(newTreasury);
    }
}
