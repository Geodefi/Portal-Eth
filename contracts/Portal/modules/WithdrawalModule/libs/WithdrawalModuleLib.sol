// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {DataStoreModuleLib as DSML} from "../../DataStoreModule/libs/DataStoreModuleLib.sol";

library WithdrawalModuleLib {
  using DSML for DSML.IsolatedStorage;

  struct PooledWithdrawal {
    uint256 pooledTokenId;
    uint256[15] __gap;
  }
}
