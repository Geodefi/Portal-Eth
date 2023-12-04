// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

/**
 * @param state state of the validator, refer to globals.sol
 * @param index representing this validator's placement on the chronological order of the validators proposals
 * @param createdAt the timestamp pointing the proposal to create a validator with given pubkey.
 * @param period the latest point in time the operator is allowed to maintain this validator (createdAt + validatorPeriod).
 * @param poolId needed for withdrawal_credential
 * @param operatorId needed for staking after allowance
 * @param poolFee percentage of the rewards that will go to pool's maintainer, locked when the validator is proposed
 * @param operatorFee percentage of the rewards that will go to operator's maintainer, locked when the validator is proposed
 * @param governanceFee although governance fee is zero right now, all fees are crucial for the price calculation by the oracle.
 * @param signature31 BLS12-381 signature for the validator, used when the remaining 31 ETH is sent on validator activation.
 **/
struct Validator {
  uint64 state;
  uint64 index;
  uint64 createdAt;
  uint64 period;
  uint256 poolId;
  uint256 operatorId;
  uint256 poolFee;
  uint256 operatorFee;
  uint256 governanceFee;
  bytes signature31;
}
