// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// libraries
import {WithdrawalModuleLib as WML} from "./libs/WithdrawalModuleLib.sol";
// contracts
import {DataStoreModule} from "../DataStoreModule/DataStoreModule.sol";
// external
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

abstract contract WithdrawalModule is
  DataStoreModule,
  ERC1155HolderUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable
{
  using WML for WML.PooledWithdrawal;
  /**
   * @custom:section                           ** VARIABLES **
   *
   * @dev Do not add any other variables here. Modules do NOT have a gap.
   * Library's main struct has a gap, providing up to 16 storage slots for this module.
   */
  WML.PooledWithdrawal internal WITHDRAWAL;

  function __WithdrawalModule_init(uint256 _pooledTokenId) internal onlyInitializing {
    __WithdrawalModule_init_unchained(_pooledTokenId);
  }

  function __WithdrawalModule_init_unchained(uint256 _pooledTokenId) internal onlyInitializing {
    WITHDRAWAL.pooledTokenId = _pooledTokenId;
  }
}
