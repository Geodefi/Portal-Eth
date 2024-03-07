// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

// external - contracts
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
// internal - globals
import {PERCENTAGE_DENOMINATOR} from "../../globals/macros.sol";
// internal - interfaces
import {IgETH} from "../../interfaces/IgETH.sol";
import {IStakeModule} from "../../interfaces/modules/IStakeModule.sol";
// internal - structs
import {DataStoreModuleStorage} from "../DataStoreModule/structs/storage.sol";
import {StakeModuleStorage} from "./structs/storage.sol";
import {Validator} from "./structs/utils.sol";
// internal - libraries
import {StakeModuleLib as SML} from "./libs/StakeModuleLib.sol";
import {InitiatorExtensionLib as IEL} from "./libs/InitiatorExtensionLib.sol";
import {OracleExtensionLib as OEL} from "./libs/OracleExtensionLib.sol";
// internal - contracts
import {DataStoreModule} from "../DataStoreModule/DataStoreModule.sol";

/**
 * @title SM: Stake Module
 *
 * @notice Liquid staking for everyone.
 * * pooling and staking for staking derivatives
 * * validator delegation and operator onboarding
 * * oracle operations such as pricing
 *
 * @dev review: this module delegates its functionality to SML (StakeModuleLib).
 * * SML has authenticate function for access control.
 * @dev review: OEL (OracleExtensionLib) is an extension for oracle operations.
 * @dev review: DCL (DepositContractLib) is an helper for validator creation.
 *
 * @dev There is 1 additional functionality implemented apart from the library:
 * * check price validity and accept proofs for updating the price (refer to deposit function).
 * * However, this module inherits and implements nonReentrant & whenNotPaused modifiers.
 * * SM has pausability and expects inheriting contract to provide the access control mechanism.
 *
 * @dev 4 functions need to be overriden when inherited: pause, unpause, setInfrastructureFee, setBeaconDelays.
 *
 * @dev __StakeModule_init (or _unchained) call is NECESSARY when inherited.
 *
 * @dev This module inherits DataStoreModule.
 *
 * @author Ice Bear & Crash Bandicoot
 */
abstract contract StakeModule is
  IStakeModule,
  ERC1155HolderUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  DataStoreModule
{
  using SML for StakeModuleStorage;
  using IEL for StakeModuleStorage;
  using OEL for StakeModuleStorage;

  /**
   * @custom:section                           ** VARIABLES **
   *
   * @dev Do not add any other variables here. Modules do not have a gap.
   * Library's main struct has a gap, providing up to 16 storage slots for this module.
   */
  // keccak256(abi.encode(uint256(keccak256("geode.storage.StakeModuleStorage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant StakeModuleStorageLocation =
    0x642b1534be65022221e9e6919fcbcd097fefb6d9d9b7897cee77332e470da700;

  function _getStakeModuleStorage() internal pure returns (StakeModuleStorage storage $) {
    assembly {
      $.slot := StakeModuleStorageLocation
    }
  }

  /**
   * @custom:section                           ** EVENTS **
   */
  event IdInitiated(uint256 id, uint256 indexed TYPE);
  event MiddlewareDeployed(uint256 poolId, uint256 version);
  event PackageDeployed(uint256 poolId, uint256 packageType, address instance);
  event InfrastructureFeeSet(uint256 _type, uint256 fee);
  event BeaconDelaySet(uint256 entryDelay, uint256 exitDelay);
  event InitiationDepositSet(uint256 initiationDeposit);
  event VisibilitySet(uint256 id, bool isPrivate);
  event YieldReceiverSet(uint256 indexed poolId, address yieldReceiver);
  event MaintainerChanged(uint256 indexed id, address newMaintainer);
  event FeeSwitched(uint256 indexed id, uint256 fee, uint256 effectiveAfter);
  event ValidatorPeriodSwitched(uint256 indexed operatorId, uint256 period, uint256 effectiveAfter);
  event Delegation(uint256 poolId, uint256 indexed operatorId, uint256 allowance);
  event FallbackOperator(uint256 poolId, uint256 indexed operatorId, uint256 threshold);
  event Prisoned(uint256 indexed operatorId, bytes proof, uint256 releaseTimestamp);
  event Deposit(uint256 indexed poolId, uint256 boughtgETH, uint256 mintedgETH);
  event StakeProposal(uint256 poolId, uint256 operatorId, bytes[] pubkeys);
  event Stake(bytes[] pubkeys);

  event Alienated(bytes pubkey);
  event VerificationIndexUpdated(uint256 validatorVerificationIndex);
  event FeeTheft(uint256 indexed id, bytes proofs);
  event YieldDistributed(uint256 indexed poolId, uint256 amount);
  event OracleReported(
    bytes32 priceMerkleRoot,
    bytes32 balanceMerkleRoot,
    uint256 monopolyThreshold
  );

  /**
   * @custom:section                           ** ABSTRACT FUNCTIONS **
   */
  function pause() external virtual override;

  function unpause() external virtual override;

  function setInfrastructureFee(uint256 _type, uint256 fee) external virtual override;

  function setBeaconDelays(uint256 _type, uint256 fee) external virtual override;

  function setInitiationDeposit(uint256 newInitiationDeposit) external virtual override;

  /**
   * @custom:section                           ** INITIALIZING **
   */
  function __StakeModule_init(address _gETH, address _oracle_position) internal onlyInitializing {
    __ReentrancyGuard_init();
    __Pausable_init();
    __ERC1155Holder_init();
    __DataStoreModule_init();
    __StakeModule_init_unchained(_gETH, _oracle_position);
  }

  function __StakeModule_init_unchained(
    address _gETH,
    address _oracle_position
  ) internal onlyInitializing {
    require(_gETH != address(0), "SM:gETH cannot be zero address");
    require(_oracle_position != address(0), "SM:oracle cannot be zero address");

    StakeModuleStorage storage $ = _getStakeModuleStorage();

    $.gETH = IgETH(_gETH);
    $.ORACLE_POSITION = _oracle_position;

    $.BEACON_DELAY_ENTRY = 14 days;
    $.BEACON_DELAY_EXIT = 14 days;

    $.INITIATION_DEPOSIT = 32 ether; // initially 32 eth

    $.DAILY_PRICE_INCREASE_LIMIT = (7 * PERCENTAGE_DENOMINATOR) / 100;
    $.DAILY_PRICE_DECREASE_LIMIT = (7 * PERCENTAGE_DENOMINATOR) / 100;
  }

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   *
   * @custom:visibility -> view-external
   */

  function StakeParams()
    external
    view
    virtual
    override
    returns (
      address gETH,
      address oraclePosition,
      uint256 validatorsIndex,
      uint256 verificationIndex,
      uint256 monopolyThreshold,
      uint256 beaconDelayEntry,
      uint256 beaconDelayExit,
      uint256 initiationDeposit,
      uint256 oracleUpdateTimestamp,
      uint256 dailyPriceIncreaseLimit,
      uint256 dailyPriceDecreaseLimit
    )
  {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    gETH = address($.gETH);
    oraclePosition = $.ORACLE_POSITION;
    validatorsIndex = $.VALIDATORS_INDEX;
    verificationIndex = $.VERIFICATION_INDEX;
    monopolyThreshold = $.MONOPOLY_THRESHOLD;
    beaconDelayEntry = $.BEACON_DELAY_ENTRY;
    beaconDelayExit = $.BEACON_DELAY_EXIT;
    initiationDeposit = $.INITIATION_DEPOSIT;
    oracleUpdateTimestamp = $.ORACLE_UPDATE_TIMESTAMP;
    dailyPriceIncreaseLimit = $.DAILY_PRICE_INCREASE_LIMIT;
    dailyPriceDecreaseLimit = $.DAILY_PRICE_DECREASE_LIMIT;
  }

  function getValidator(
    bytes calldata pubkey
  ) external view virtual override returns (Validator memory) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    return $.validators[pubkey];
  }

  function getBalancesMerkleRoot() external view virtual override returns (bytes32) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    return $.BALANCE_MERKLE_ROOT;
  }

  function getPriceMerkleRoot() external view virtual override returns (bytes32) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    return $.PRICE_MERKLE_ROOT;
  }

  function getPackageVersion(uint256 _type) external view virtual override returns (uint256) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    return $.packages[_type];
  }

  function isMiddleware(
    uint256 _type,
    uint256 _version
  ) external view virtual override returns (bool) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    return $.middlewares[_type][_version];
  }

  function getInfrastructureFee(uint256 _type) external view virtual override returns (uint256) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    return $.infrastructureFees[_type];
  }

  /**
   * @custom:section                           ** OPERATOR INITIATOR **
   *
   * @custom:visibility -> external
   */
  function initiateOperator(
    uint256 id,
    uint256 fee,
    uint256 validatorPeriod,
    address maintainer
  ) external payable virtual override nonReentrant whenNotPaused {
    IEL.initiateOperator(_getDataStoreModuleStorage(), id, fee, validatorPeriod, maintainer);
  }

  /**
   * @custom:section                           ** STAKING POOL INITIATOR **
   *
   * @custom:visibility -> external
   */

  function initiatePool(
    uint256 fee,
    uint256 middlewareVersion,
    address maintainer,
    bytes calldata NAME,
    bytes calldata middleware_data,
    bool[3] calldata config
  ) external payable virtual override whenNotPaused returns (uint256 poolId) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    poolId = $.initiatePool(
      _getDataStoreModuleStorage(),
      fee,
      middlewareVersion,
      maintainer,
      NAME,
      middleware_data,
      config
    );
  }

  /**
   * @custom:subsection                           ** POOL VISIBILITY **
   */

  function setPoolVisibility(uint256 poolId, bool makePrivate) external virtual override {
    SML.setPoolVisibility(_getDataStoreModuleStorage(), poolId, makePrivate);
  }

  function setWhitelist(uint256 poolId, address whitelist) external virtual override {
    SML.setWhitelist(_getDataStoreModuleStorage(), poolId, whitelist);
  }

  /**
   * @custom:visibility -> view
   */
  function isPrivatePool(uint256 poolId) external view virtual override returns (bool) {
    return SML.isPrivatePool(_getDataStoreModuleStorage(), poolId);
  }

  function isWhitelisted(
    uint256 poolId,
    address staker
  ) external view virtual override returns (bool) {
    return SML.isWhitelisted(_getDataStoreModuleStorage(), poolId, staker);
  }

  /**
   * @custom:subsection                           ** BOUND LIQUIDITY POOL **
   */

  function deployLiquidityPool(uint256 poolId) external virtual override whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.deployLiquidityPool(_getDataStoreModuleStorage(), poolId);
  }

  /**
   * @custom:subsection                           ** YIELD SEPARATION **
   */

  function setYieldReceiver(
    uint256 poolId,
    address yieldReceiver
  ) external virtual override whenNotPaused {
    SML.setYieldReceiver(_getDataStoreModuleStorage(), poolId, yieldReceiver);
  }

  /**
   * @custom:section                           ** ID MANAGEMENT **
   *
   * @custom:visibility -> external
   */

  /**
   * @custom:subsection                           ** MAINTAINER **
   */

  function changeMaintainer(
    uint256 id,
    address newMaintainer
  ) external virtual override whenNotPaused {
    SML.changeMaintainer(_getDataStoreModuleStorage(), id, newMaintainer);
  }

  /**
   * @custom:subsection                           ** FEE **
   */

  function switchMaintenanceFee(
    uint256 id,
    uint256 newFee
  ) external virtual override whenNotPaused {
    SML.switchMaintenanceFee(_getDataStoreModuleStorage(), id, newFee);
  }

  /**
   * @custom:visibility -> view
   */
  function getMaintenanceFee(uint256 id) external view virtual override returns (uint256) {
    return SML.getMaintenanceFee(_getDataStoreModuleStorage(), id);
  }

  /**
   * @custom:section                           ** INTERNAL WALLET **
   */

  function increaseWalletBalance(
    uint256 id
  ) external payable virtual override nonReentrant whenNotPaused returns (bool) {
    return SML.increaseWalletBalance(_getDataStoreModuleStorage(), id);
  }

  function decreaseWalletBalance(
    uint256 id,
    uint256 value
  ) external virtual override nonReentrant returns (bool) {
    return SML.decreaseWalletBalance(_getDataStoreModuleStorage(), id, value);
  }

  /**
   * @custom:section                           ** OPERATORS PERIOD **
   *
   * @custom:visibility -> external
   */

  function switchValidatorPeriod(
    uint256 operatorId,
    uint256 newPeriod
  ) external virtual override whenNotPaused {
    SML.switchValidatorPeriod(_getDataStoreModuleStorage(), operatorId, newPeriod);
  }

  /**
   * @custom:visibility -> view
   */
  function getValidatorPeriod(uint256 id) external view virtual override returns (uint256) {
    return SML.getValidatorPeriod(_getDataStoreModuleStorage(), id);
  }

  /**
   * @custom:section                           ** PRISON **
   *
   * @custom:visibility -> external
   */

  function blameProposal(bytes calldata pk) external virtual override whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.blameProposal(_getDataStoreModuleStorage(), pk);
  }

  function blameExit(
    bytes calldata pk,
    uint256 beaconBalance,
    uint256 withdrawnBalance,
    bytes32[] calldata balanceProof
  ) external virtual override whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.blameExit(_getDataStoreModuleStorage(), pk, beaconBalance, withdrawnBalance, balanceProof);
  }

  /**
   * @custom:visibility -> view
   */
  function isPrisoned(uint256 operatorId) external view virtual override returns (bool) {
    return SML.isPrisoned(_getDataStoreModuleStorage(), operatorId);
  }

  /**
   * @custom:section                           ** DELEGATION **
   *
   * @custom:visibility -> external
   */

  function delegate(
    uint256 poolId,
    uint256[] calldata operatorIds,
    uint256[] calldata allowances
  ) external virtual override whenNotPaused {
    SML.delegate(_getDataStoreModuleStorage(), poolId, operatorIds, allowances);
  }

  function setFallbackOperator(
    uint256 poolId,
    uint256 operatorId,
    uint256 fallbackThreshold
  ) external virtual override whenNotPaused {
    SML.setFallbackOperator(_getDataStoreModuleStorage(), poolId, operatorId, fallbackThreshold);
  }

  /**
   * @custom:visibility -> view
   */
  function operatorAllowance(
    uint256 poolId,
    uint256 operatorId
  ) external view virtual override returns (uint256) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    return $.operatorAllowance(_getDataStoreModuleStorage(), poolId, operatorId);
  }

  /**
   * @custom:section                           ** DEPOSIT GETTERS **
   *
   * @custom:visibility -> view-external
   */

  function isPriceValid(uint256 poolId) external view virtual override returns (bool) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    return $.isPriceValid(poolId);
  }

  function isMintingAllowed(uint256 poolId) external view virtual override returns (bool) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    return $.isMintingAllowed(_getDataStoreModuleStorage(), poolId);
  }

  /**
   * @custom:section                           ** POOLING OPERATIONS **
   *
   * @custom:visibility -> external
   */
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
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    DataStoreModuleStorage storage DSMStorage = _getDataStoreModuleStorage();
    if (!$.isPriceValid(poolId)) {
      $.priceSync(DSMStorage, poolId, price, priceProof);
    }

    (boughtgETH, mintedgETH) = $.deposit(
      _getDataStoreModuleStorage(),
      poolId,
      mingETH,
      deadline,
      receiver
    );
  }

  /**
   * @custom:section                           ** VALIDATOR CREATION **
   *
   * @custom:visibility -> external
   */
  function proposeStake(
    uint256 poolId,
    uint256 operatorId,
    bytes[] calldata pubkeys,
    bytes[] calldata signatures1,
    bytes[] calldata signatures31
  ) external virtual override whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.proposeStake(
      _getDataStoreModuleStorage(),
      poolId,
      operatorId,
      pubkeys,
      signatures1,
      signatures31
    );
  }

  function stake(
    uint256 operatorId,
    bytes[] calldata pubkeys
  ) external virtual override whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.stake(_getDataStoreModuleStorage(), operatorId, pubkeys);
  }

  /**
   * @custom:visibility -> view
   */
  function canStake(bytes calldata pubkey) external view virtual override returns (bool) {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    return $.canStake(pubkey);
  }

  /**
   * @custom:section                           ** VALIDATOR EXITS **
   *
   * @custom:visibility -> external
   */

  function requestExit(
    uint256 poolId,
    bytes calldata pk
  ) external virtual override nonReentrant whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.requestExit(_getDataStoreModuleStorage(), poolId, pk);
  }

  function finalizeExit(
    uint256 poolId,
    bytes calldata pk
  ) external virtual override nonReentrant whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.finalizeExit(_getDataStoreModuleStorage(), poolId, pk);
  }

  /**
   * @custom:section                           ** ORACLE OPERATIONS **
   *
   * @custom:visibility -> external
   */

  function updateVerificationIndex(
    uint256 validatorVerificationIndex,
    bytes[] calldata alienatedPubkeys
  ) external virtual override whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.updateVerificationIndex(
      _getDataStoreModuleStorage(),
      validatorVerificationIndex,
      alienatedPubkeys
    );
  }

  function regulateOperators(
    uint256[] calldata feeThefts,
    bytes[] calldata proofs
  ) external virtual override whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.regulateOperators(_getDataStoreModuleStorage(), feeThefts, proofs);
  }

  function reportBeacon(
    bytes32 priceMerkleRoot,
    bytes32 balanceMerkleRoot,
    uint256 allValidatorsCount
  ) external virtual override whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.reportBeacon(priceMerkleRoot, balanceMerkleRoot, allValidatorsCount);
  }

  function priceSync(
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProof
  ) external virtual override whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.priceSync(_getDataStoreModuleStorage(), poolId, price, priceProof);
  }

  function priceSyncBatch(
    uint256[] calldata poolIds,
    uint256[] calldata prices,
    bytes32[][] calldata priceProofs
  ) external virtual override whenNotPaused {
    StakeModuleStorage storage $ = _getStakeModuleStorage();
    $.priceSyncBatch(_getDataStoreModuleStorage(), poolIds, prices, priceProofs);
  }
}
