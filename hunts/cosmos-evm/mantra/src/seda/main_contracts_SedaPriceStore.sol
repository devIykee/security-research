// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title SedaPriceStore
/// @notice Stores SEDA oracle prices pushed by an authorized relayer.
///         Provides AggregatorV3Interface-compatible reads per feed.
/// @dev UUPS upgradeable. Owner manages relayer whitelist. Pausable for emergencies.
contract SedaPriceStore is OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    // ============ Storage (ERC-7201 style) ============

    struct PriceData {
        int256 price;
        uint256 timestamp;
        uint80 roundId;
    }

    /// @notice Latest price data per feedId
    mapping(bytes32 => PriceData) private _prices;

    /// @notice Authorized relayer addresses
    mapping(address => bool) public relayers;

    // ============ Events ============

    event PriceUpdated(bytes32 indexed feedId, int256 price, uint256 timestamp, uint80 roundId);
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);

    // ============ Errors ============

    error OnlyRelayer();
    error ArrayLengthMismatch();
    error StaleTimestamp(bytes32 feedId, uint256 newTimestamp, uint256 storedTimestamp);
    error ZeroAddress();

    // ============ Modifiers ============

    modifier onlyRelayer() {
        if (!relayers[msg.sender]) revert OnlyRelayer();
        _;
    }

    // ============ Initialization ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, address relayer) public initializer {
        if (owner == address(0) || relayer == address(0)) revert ZeroAddress();

        __Ownable_init(owner);
        __Pausable_init();

        relayers[relayer] = true;
        emit RelayerAdded(relayer);
    }

    // ============ Relayer Functions ============

    /// @notice Batch-update prices for multiple feeds in a single transaction
    /// @param feedIds Array of feed identifiers (keccak256 of symbol string)
    /// @param prices Array of prices (18-decimal int256)
    /// @param timestamps Array of timestamps (unix seconds)
    function updatePrices(
        bytes32[] calldata feedIds,
        int256[] calldata prices,
        uint256[] calldata timestamps
    ) external onlyRelayer whenNotPaused {
        if (feedIds.length != prices.length || feedIds.length != timestamps.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < feedIds.length; ++i) {
            PriceData storage stored = _prices[feedIds[i]];

            if (timestamps[i] <= stored.timestamp) {
                revert StaleTimestamp(feedIds[i], timestamps[i], stored.timestamp);
            }

            uint80 newRound = stored.roundId + 1;
            stored.price = prices[i];
            stored.timestamp = timestamps[i];
            stored.roundId = newRound;

            emit PriceUpdated(feedIds[i], prices[i], timestamps[i], newRound);
        }
    }

    // ============ Read Functions ============

    /// @notice Get latest price data for a feed
    function getLatestPrice(bytes32 feedId) external view returns (int256 price, uint256 timestamp, uint80 roundId) {
        PriceData storage d = _prices[feedId];
        return (d.price, d.timestamp, d.roundId);
    }

    /// @notice AggregatorV3Interface-compatible read
    function latestRoundData(bytes32 feedId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        PriceData storage d = _prices[feedId];
        return (d.roundId, d.price, d.timestamp, d.timestamp, d.roundId);
    }

    /// @notice All feeds use 18 decimals
    function decimals() external pure returns (uint8) {
        return 18;
    }

    // ============ Admin Functions ============

    function addRelayer(address relayer) external onlyOwner {
        if (relayer == address(0)) revert ZeroAddress();
        relayers[relayer] = true;
        emit RelayerAdded(relayer);
    }

    function removeRelayer(address relayer) external onlyOwner {
        relayers[relayer] = false;
        emit RelayerRemoved(relayer);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ UUPS ============

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
