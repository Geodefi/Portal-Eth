// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {IWithdrawalModule} from "../modules/IWithdrawalModule.sol";
import {IGeodePackage} from "./IGeodePackage.sol";

interface IWithdrawalContract is IWithdrawalModule, IGeodePackage {}
