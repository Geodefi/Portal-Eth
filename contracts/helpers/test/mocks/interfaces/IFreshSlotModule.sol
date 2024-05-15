// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

interface IFreshSlotModule {
  function setFreshSlot(uint256 value) external;

  function getFreshSlot() external view returns (uint256);
}
