// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IWithdrawalModule} from "../modules/IWithdrawalModule.sol";
import {IGeodePackage} from "./IGeodePackage.sol";

interface IWithdrawalPackage is IGeodePackage, IWithdrawalModule {}
