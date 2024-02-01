// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @notice Helper Struct to pack constant data that does not change per validator on batch proposals
 * * needed for that famous Solidity feature.
 */
struct ConstantValidatorData {
  uint64 index;
  uint64 period;
  uint256 poolFee;
  uint256 operatorFee;
  uint256 infrastructureFee;
  bytes withdrawalCredential;
}
