// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

// structs
import {StakeModuleStorage} from "../../../modules/StakeModule/structs/storage.sol";
import {DataStoreModuleStorage} from "../../../modules/DataStoreModule/structs/storage.sol";

import {StakeModule} from "../../../modules/StakeModule/StakeModule.sol";
import {StakeModuleLib} from "../../../modules/StakeModule/libs/StakeModuleLib.sol";
import {InitiatorExtensionLib} from "../../../modules/StakeModule/libs/InitiatorExtensionLib.sol";
import {OracleExtensionLib} from "../../../modules/StakeModule/libs/OracleExtensionLib.sol";
import {DataStoreModuleLib} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";

contract StakeModuleLibMock is StakeModule {
  using DataStoreModuleLib for DataStoreModuleStorage;
  using StakeModuleLib for StakeModuleStorage;
  using OracleExtensionLib for StakeModuleStorage;
  using InitiatorExtensionLib for StakeModuleStorage;

  event return$_buyback(uint256 remETH, uint256 boughtgETH);

  event return$initiatePool(uint256 poolId);

  event return$deposit(uint256 boughtgETH, uint256 mintedgETH);

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
   * @custom:section                           ** INTERNAL TO EXTERNAL **
   */

  function $_authenticate(
    uint256 _id,
    bool _expectCONTROLLER,
    bool _expectMaintainer,
    bool[2] memory _restrictionMap
  ) external view {
    StakeModuleLib._authenticate(
      _getDataStoreModuleStorage(),
      _id,
      _expectCONTROLLER,
      _expectMaintainer,
      _restrictionMap
    );
  }

  function $_setgETHMiddleware(uint256 id, address _middleware) external {
    _getStakeModuleStorage()._setgETHMiddleware(_getDataStoreModuleStorage(), id, _middleware);
  }

  function $_deploygETHMiddleware(
    uint256 _id,
    uint256 _versionId,
    bytes calldata _middleware_data
  ) external {
    _getStakeModuleStorage()._deploygETHMiddleware(
      _getDataStoreModuleStorage(),
      _id,
      _versionId,
      _middleware_data
    );
  }

  function $_deployGeodePackage(
    uint256 _type,
    uint256 _poolId,
    bytes memory _package_data
  ) external returns (address packageInstance) {
    return
      _getStakeModuleStorage()._deployGeodePackage(
        _getDataStoreModuleStorage(),
        _type,
        _poolId,
        _package_data
      );
  }

  function $_deployWithdrawalContract(uint256 _poolId) external {
    _getStakeModuleStorage()._deployWithdrawalContract(_getDataStoreModuleStorage(), _poolId);
  }

  function $_setMaintainer(uint256 _id, address _newMaintainer) external {
    StakeModuleLib._setMaintainer(_getDataStoreModuleStorage(), _id, _newMaintainer);
  }

  function $_setMaintenanceFee(uint256 _id, uint256 _newFee) external {
    StakeModuleLib._setMaintenanceFee(_getDataStoreModuleStorage(), _id, _newFee);
  }

  function $_increaseWalletBalance(uint256 _id, uint256 _value) external {
    StakeModuleLib._increaseWalletBalance(_getDataStoreModuleStorage(), _id, _value);
  }

  function $_decreaseWalletBalance(uint256 _id, uint256 _value) external {
    StakeModuleLib._decreaseWalletBalance(_getDataStoreModuleStorage(), _id, _value);
  }

  function $_imprison(uint256 _operatorId, bytes calldata _proof) external {
    OracleExtensionLib._imprison(_getDataStoreModuleStorage(), _operatorId, _proof);
  }

  function $_setValidatorPeriod(uint256 _operatorId, uint256 _newPeriod) external {
    StakeModuleLib._setValidatorPeriod(_getDataStoreModuleStorage(), _operatorId, _newPeriod);
  }

  function $_approveOperator(
    uint256 poolId,
    uint256 operatorId,
    uint256 allowance
  ) external returns (uint256 oldAllowance) {
    return
      StakeModuleLib._approveOperator(_getDataStoreModuleStorage(), poolId, operatorId, allowance);
  }

  function $_mintgETH(uint256 _poolId, uint256 _ethAmount) external returns (uint256 mintedgETH) {
    return _getStakeModuleStorage()._mintgETH(_getDataStoreModuleStorage(), _poolId, _ethAmount);
  }

  function $_buyback(
    uint256 _poolId,
    uint256 _maxEthToSell,
    uint256 _deadline
  ) external payable returns (uint256 remETH, uint256 boughtgETH) {
    (remETH, boughtgETH) = StakeModuleLib._buyback(
      _getDataStoreModuleStorage(),
      _poolId,
      _maxEthToSell,
      _deadline
    );
    emit return$_buyback(remETH, boughtgETH);
  }

  function $_canStake(
    bytes calldata _pubkey,
    uint256 _verificationIndex
  ) external view returns (bool) {
    return _getStakeModuleStorage()._canStake(_pubkey, _verificationIndex);
  }

  /**
   * @custom:section                           ** FOR RETURN STATEMENTS **
   */
  function initiatePool(
    uint256 fee,
    uint256 middlewareVersion,
    address maintainer,
    bytes calldata NAME,
    bytes calldata middleware_data,
    bool[3] calldata config
  ) external payable virtual override whenNotPaused returns (uint256 poolId) {
    poolId = _getStakeModuleStorage().initiatePool(
      _getDataStoreModuleStorage(),
      fee,
      middlewareVersion,
      maintainer,
      NAME,
      middleware_data,
      config
    );
    emit return$initiatePool(poolId);
  }

  function deposit(
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProof,
    uint256 mingETH,
    uint256 deadline,
    address receiver
  )
    external
    payable
    virtual
    override
    nonReentrant
    whenNotPaused
    returns (uint256 boughtgETH, uint256 mintedgETH)
  {
    (boughtgETH, mintedgETH) = _getStakeModuleStorage().deposit(
      _getDataStoreModuleStorage(),
      poolId,
      mingETH,
      deadline,
      receiver
    );
    emit return$deposit(boughtgETH, mintedgETH);
  }

  /**
   * @notice fallback functions
   */

  receive() external payable {}
}
