// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISlvrGridLottery} from "./interfaces/ISlvrGridLottery.sol";

/// @title SlvrMultiClaim
/// @notice Claims lottery winnings from many rounds in a single transaction.
/// @dev The lottery only exposes single-round claims, and its delegate system is the only way a
///      contract can claim on a user's behalf. A generic executor (e.g. Multicall3) can't be that
///      delegate safely: anyone may call it, and claimAdvanced lets the caller pick recipients, so
///      approving it would let a third party route your winnings to themselves.
///
///      This contract is safe to approve because `user` and both recipients are hardcoded to
///      msg.sender: a third party calling it can only claim their OWN rounds to their OWN wallet.
///      Usage: approveDelegate(address(this)) on the lottery once, then claimMany(roundIds).
contract SlvrMultiClaim {
    ISlvrGridLottery public immutable LOTTERY;

    /// @notice Nothing was claimed — every round in the batch was unresolved, not won,
    ///         already claimed, or the caller hasn't approved this contract as a delegate.
    error NothingClaimed();
    error ZeroAddress();

    event MultiClaimed(address indexed user, uint256 requested, uint256 claimed);

    constructor(address lottery_) {
        if (lottery_ == address(0)) revert ZeroAddress();
        LOTTERY = ISlvrGridLottery(lottery_);
    }

    /// @notice Claim winnings from multiple rounds for the caller in one transaction.
    /// @dev Rounds that can't be claimed (unresolved, no winning bet, already claimed — e.g. an
    ///      auto-commit auto-claim raced this call) are skipped instead of reverting the batch.
    ///      ETH (and SLVR when !ethOnly) is paid by the lottery directly to the caller; this
    ///      contract never holds funds.
    /// @param roundIds The rounds to claim. Callers should size batches to the block gas limit
    ///        (each claim costs a few hundred thousand gas).
    /// @param ethOnly If true, claim only the ETH winnings and leave SLVR unrefined in miner
    ///        state (it keeps earning dividends); if false, also refine + transfer the SLVR.
    /// @return claimed Number of rounds successfully claimed.
    function claimMany(uint256[] calldata roundIds, bool ethOnly) external returns (uint256 claimed) {
        for (uint256 i = 0; i < roundIds.length; i++) {
            ISlvrGridLottery.ClaimParams memory p;
            p.user = msg.sender;
            p.roundId = roundIds[i];
            p.recipientNative = msg.sender;
            p.recipientSlvr = msg.sender;
            p.bypassFee = false;
            p.ethOnly = ethOnly;
            try LOTTERY.claimAdvanced(p) {
                claimed++;
            } catch {}
        }
        // A no-op batch is almost certainly a mistake (missing delegate approval, stale round
        // list); revert so the caller isn't charged for a tx that did nothing.
        if (claimed == 0) revert NothingClaimed();
        emit MultiClaimed(msg.sender, roundIds.length, claimed);
    }
}
