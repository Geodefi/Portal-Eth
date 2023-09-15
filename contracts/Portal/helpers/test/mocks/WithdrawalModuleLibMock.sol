// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {StakeModule} from "../../../modules/StakeModule/StakeModule.sol";
import {StakeModuleLib} from "../../../modules/StakeModule/libs/StakeModuleLib.sol";
import {WithdrawalModule} from "../../../modules/WithdrawalModule/WithdrawalModule.sol";
import {WithdrawalModuleLib} from "../../../modules/WithdrawalModule/libs/WithdrawalModuleLib.sol";
import {InitiatorExtensionLib} from "../../../modules/StakeModule/libs/InitiatorExtensionLib.sol";
import {OracleExtensionLib} from "../../../modules/StakeModule/libs/OracleExtensionLib.sol";
import {DataStoreModuleLib} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";

contract WithdrawalModuleLibMock is WithdrawalModule {
  using WithdrawalModuleLib for WithdrawalModuleLib.PooledWithdrawal;

  event return$initiatePool(uint256 poolId);

  function initialize(
    address _gETH_position,
    address _portal_position,
    uint256 _poolId
  ) external initializer {
    __WithdrawalModule_init(_gETH_position, _portal_position, _poolId);
  }

  function pause() external virtual override(WithdrawalModule) {
    _pause();
  }

  function unpause() external virtual override(WithdrawalModule) {
    _unpause();
  }

  function setExitThreshold(uint256 newThreshold) external virtual override(WithdrawalModule) {
    WITHDRAWAL.setExitThreshold(newThreshold);
  }

  function $getWithdrawalParams()
    external
    view
    returns (address gETH, address PORTAL, uint256 POOL_ID, uint256 EXIT_THRESHOLD)
  {
    gETH = address(WITHDRAWAL.gETH);
    PORTAL = address(WITHDRAWAL.PORTAL);
    POOL_ID = WITHDRAWAL.POOL_ID;
    EXIT_THRESHOLD = WITHDRAWAL.EXIT_THRESHOLD;
  }
}
