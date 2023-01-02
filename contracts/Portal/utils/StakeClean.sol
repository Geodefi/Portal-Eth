// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./DataStoreUtilsLib.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";

import "../../interfaces/IgETH.sol";
import "../../interfaces/IMiniGovernance.sol";
import "../../interfaces/ISwap.sol";
import "../../interfaces/ILPToken.sol";
import {IERC20InterfacePermitUpgradable as IgETHInterface} from "../../interfaces/IERC20InterfacePermitUpgradable.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title StakeUtils library
 */
