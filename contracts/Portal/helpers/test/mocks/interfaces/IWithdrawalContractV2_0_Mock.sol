// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IWithdrawalModule} from "../../../../interfaces/modules/IWithdrawalModule.sol";
import {IGeodePackage} from "../../../../interfaces/packages/IGeodePackage.sol";

interface IWithdrawalContractV2_0_Mock is IGeodePackage, IWithdrawalModule {
  function initializeV2_0_Mock(uint256 _freshSlot) external;

  function setFreshSlot(uint256 value) external;

  function getFreshSlot() external view returns (uint256);
}