// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {DataStoreModuleStorage} from "../../../modules/DataStoreModule/structs/storage.sol";
import {StakeModuleStorage} from "../../../modules/StakeModule/structs/storage.sol";
import {StakeModule} from "../../../modules/StakeModule/StakeModule.sol";
import {StakeModuleLib} from "../../../modules/StakeModule/libs/StakeModuleLib.sol";
import {OracleExtensionLib} from "../../../modules/StakeModule/libs/OracleExtensionLib.sol";
import {DataStoreModuleLib} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";

contract OracleExtensionLibMock is StakeModule {
  using StakeModuleLib for StakeModuleStorage;
  using OracleExtensionLib for StakeModuleStorage;
  using DataStoreModuleLib for DataStoreModuleStorage;

  function initialize(address _gETH_position, address _oracle_position) external initializer {
    __StakeModule_init(_gETH_position, _oracle_position);
  }

  function pause() external virtual override {
    _pause();
  }

  function unpause() external virtual override {
    _unpause();
  }

  function setInfrastructureFee(uint256 _type, uint256 fee) external virtual override {
    _getStakeModuleStorage().setInfrastructureFee(_type, fee);
  }

  function setBeaconDelays(uint256 entry, uint256 exit) external virtual override {
    _getStakeModuleStorage().setBeaconDelays(entry, exit);
  }

  /**
   * @custom:section                           ** DATA MANIPULATORS **
   */
  function $writeUint(uint256 _id, bytes32 _key, uint256 _data) external {
    _getDataStoreModuleStorage().writeUint(_id, _key, _data);
  }

  function $writeBytes(uint256 _id, bytes32 _key, bytes calldata _data) external {
    _getDataStoreModuleStorage().writeBytes(_id, _key, _data);
  }

  function $writeAddress(uint256 _id, bytes32 _key, address _data) external {
    _getDataStoreModuleStorage().writeAddress(_id, _key, _data);
  }

  function $set_ORACLE_POSITION(address _data) external {
    _getStakeModuleStorage().ORACLE_POSITION = _data;
  }

  function $set_VALIDATORS_INDEX(uint256 _data) external {
    _getStakeModuleStorage().VALIDATORS_INDEX = _data;
  }

  function $set_VERIFICATION_INDEX(uint256 _data) external {
    _getStakeModuleStorage().VERIFICATION_INDEX = _data;
  }

  function $set_MONOPOLY_THRESHOLD(uint256 _data) external {
    _getStakeModuleStorage().MONOPOLY_THRESHOLD = _data;
  }

  function $set_ORACLE_UPDATE_TIMESTAMP(uint256 _data) external {
    _getStakeModuleStorage().ORACLE_UPDATE_TIMESTAMP = _data;
  }

  function $set_package(uint256 _type, uint256 package) external {
    _getStakeModuleStorage().packages[_type] = package;
  }

  function $set_middleware(uint256 _type, uint256 middleware) external {
    _getStakeModuleStorage().middlewares[_type][middleware] = true;
  }

  function $set_PricePerShare(uint256 price, uint256 poolId) external {
    _getStakeModuleStorage().gETH.setPricePerShare(price, poolId);
  }

  /**
   * @custom:section                           ** INTERNAL **
   */
  function $_alienateValidator(bytes calldata _pk) external {
    return
      _getStakeModuleStorage()._alienateValidator(
        _getDataStoreModuleStorage(),
        _getStakeModuleStorage().VERIFICATION_INDEX,
        _pk
      );
  }

  function $_sanityCheck(uint256 _id, uint256 _newPrice) external view {
    return _getStakeModuleStorage()._sanityCheck(_getDataStoreModuleStorage(), _id, _newPrice);
  }

  /**
   * @notice fallback functions
   */

  receive() external payable {}
}
