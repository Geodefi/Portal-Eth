// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./DataStoreUtilsLib.sol";
import "./StakeClean.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";

import "../../interfaces/IgETH.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title OracleUtils library
 */
