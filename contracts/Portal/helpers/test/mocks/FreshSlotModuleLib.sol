// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

struct FreshSlotStruct {
  uint256 freshSlot;
  uint256[15] __gap;
}

library FreshSlotModuleLib {
  function setFreshSlot(FreshSlotStruct storage self, uint256 value) external {
    self.freshSlot = value;
  }

  function getFreshSlot(FreshSlotStruct storage self) external view returns (uint256) {
    return self.freshSlot;
  }
}
