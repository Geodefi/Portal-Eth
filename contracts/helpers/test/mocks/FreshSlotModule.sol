// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {FreshSlotModuleLib as FSL, FreshSlotStruct} from "./FreshSlotModuleLib.sol";
import {IFreshSlotModule} from "./interfaces/IFreshSlotModule.sol";

// external
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

abstract contract FreshSlotModule is IFreshSlotModule, UUPSUpgradeable, PausableUpgradeable {
  using FSL for FreshSlotStruct;

  /**
   * @custom:section                           ** VARIABLES **
   *
   * @dev Do not add any other variables here. Modules do not have a gap.
   * Library's main struct has a gap, providing up to 16 storage slots for this module.
   */
  FreshSlotStruct internal FRESH_STRUCT;

  function __FreshSlotModule_init(uint256 value) internal {
    __Pausable_init();
    __FreshSlotModule_init_unchained(value);
  }

  function __FreshSlotModule_init_unchained(uint256 value) internal {
    FRESH_STRUCT.setFreshSlot(value);
  }

  function setFreshSlot(uint256 value) external override {
    FRESH_STRUCT.setFreshSlot(value);
  }

  function getFreshSlot() external view override returns (uint256) {
    return FRESH_STRUCT.getFreshSlot();
  }
}
