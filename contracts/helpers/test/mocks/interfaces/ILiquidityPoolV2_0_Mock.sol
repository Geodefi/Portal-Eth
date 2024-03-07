// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {ILiquidityModule} from "../../../../interfaces/modules/ILiquidityModule.sol";
import {IGeodePackage} from "../../../../interfaces/packages/IGeodePackage.sol";

interface ILiquidityPoolV2_0_Mock is IGeodePackage, ILiquidityModule {
  function initializeV2_0_Mock(uint256 _freshSlot) external;

  function setFreshSlot(uint256 value) external;

  function getFreshSlot() external view returns (uint256);
}
