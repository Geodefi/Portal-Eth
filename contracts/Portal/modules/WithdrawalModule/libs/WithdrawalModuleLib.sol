// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
// libraries
import {DataStoreModuleLib as DSML} from "../../DataStoreModule/libs/DataStoreModuleLib.sol";
// interfaces
import {IgETH} from "../../../interfaces/IgETH.sol";
import {IPortal} from "../../../interfaces/IPortal.sol";
// external
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

library WithdrawalModuleLib {
  using DSML for DSML.IsolatedStorage;

  struct PooledWithdrawal {
    uint256 pooledTokenId;
    uint256[15] __gap;
  }
