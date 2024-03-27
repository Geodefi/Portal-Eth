// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {ILiquidityModule} from "../modules/ILiquidityModule.sol";
import {IGeodePackage} from "./IGeodePackage.sol";

interface ILiquidityPackage is IGeodePackage, ILiquidityModule {}
