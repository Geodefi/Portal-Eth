// SPDX-License-Identifier: MIT

pragma solidity =0.8.7;

import {IGeodePackage} from "./IGeodePackage.sol";
import {IPortal} from "../IPortal.sol";
import {ILiquidityModule} from "../modules/ILiquidityModule.sol";

interface ILiquidityPool is ILiquidityModule, IGeodePackage {}
