// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

interface IFreshSlotModule {
  function setFreshSlot(uint256 value) external;

  function getFreshSlot() external view returns (uint256);
}
