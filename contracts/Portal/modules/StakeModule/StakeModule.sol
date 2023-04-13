// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {PERCENTAGE_DENOMINATOR} from "../../globals/macros.sol";
// interfaces
import {IgETH} from "../../interfaces/IgETH.sol";
import {IStakeModule} from "../../interfaces/modules/IStakeModule.sol";
// libraries
import {StakeModuleLib as SML} from "./libs/StakeModuleLib.sol";
import {OracleExtensionLib as OEL} from "./libs/OracleExtensionLib.sol";
// contracts
import {DataStoreModule} from "../DataStoreModule/DataStoreModule.sol";
// external
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title Stake Module - SM
 *
 * @author Ice Bear & Crash Bandicoot
 */
contract StakeModule is
  IStakeModule,
  DataStoreModule,
  ERC1155HolderUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable
{
  using SML for SML.PooledStaking;
  using OEL for SML.PooledStaking;

  /**
   * @custom:section                           ** VARIABLES **
   *
   * @dev note do not add any other vairables, Modules do not have a gap.
   * Instead library main struct has a gap, providing up to 16 storage slot.
   * todo add this to internal docs
   */
  SML.PooledStaking internal STAKE;

  /**
   * @custom:section                           ** EVENTS **
   * following events are added from SML to help fellow devs with a better ABI
   */
  event IdInitiated(uint256 id, uint256 indexed TYPE);
  event VisibilitySet(uint256 id, bool isPrivate);
  event MaintainerChanged(uint256 indexed id, address newMaintainer);
  event FeeSwitched(uint256 indexed id, uint256 fee, uint256 effectiveAfter);
  event ValidatorPeriodSwitched(uint256 indexed operatorId, uint256 period, uint256 effectiveAfter);
  event OperatorApproval(uint256 poolId, uint256 indexed operatorId, uint256 allowance);
  event FallbackOperator(uint256 poolId, uint256 indexed operatorId);
  event Prisoned(uint256 indexed operatorId, bytes proof, uint256 releaseTimestamp);
  event Deposit(uint256 indexed poolId, uint256 boughtgETH, uint256 mintedgETH);
  event ProposalStaked(uint256 poolId, uint256 operatorId, bytes[] pubkeys);
  event BeaconStaked(bytes[] pubkeys);

  /**
   * @custom:section                           ** INITIALIZING **
   */
  function __StakeModule_init(address _gETH, address _oracle_position) internal onlyInitializing {
    __ERC1155Holder_init_unchained();
    __ReentrancyGuard_init_unchained();
    __Pausable_init_unchained();
    __DataStoreModule_init_unchained();
    __StakeModule_init_unchained(_gETH, _oracle_position);
  }

  function __StakeModule_init_unchained(
    address _gETH,
    address _oracle_position
  ) internal onlyInitializing {
    STAKE.gETH = IgETH(_gETH);
    STAKE.ORACLE_POSITION = _oracle_position;
    STAKE.DAILY_PRICE_INCREASE_LIMIT = (7 * PERCENTAGE_DENOMINATOR) / 100;
    STAKE.DAILY_PRICE_DECREASE_LIMIT = (7 * PERCENTAGE_DENOMINATOR) / 100;
  }

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   */

  /**
   * @dev -> external view -> all
   */

  function StakeParams()
    external
    view
    virtual
    override
    returns (
      uint256 validatorsIndex,
      uint256 verificationIndex,
      uint256 monopolyThreshold,
      uint256 oracleUpdateTimestamp,
      uint256 dailyPriceIncreaseLimit,
      uint256 dailyPriceDecreaseLimit,
      bytes32 priceMerkleRoot,
      bytes32 balanceMerkleRoot,
      address oraclePosition
    )
  {
    validatorsIndex = STAKE.VALIDATORS_INDEX;
    verificationIndex = STAKE.VERIFICATION_INDEX;
    monopolyThreshold = STAKE.MONOPOLY_THRESHOLD;
    oracleUpdateTimestamp = STAKE.ORACLE_UPDATE_TIMESTAMP;
    dailyPriceIncreaseLimit = STAKE.DAILY_PRICE_INCREASE_LIMIT;
    dailyPriceDecreaseLimit = STAKE.DAILY_PRICE_DECREASE_LIMIT;
    priceMerkleRoot = STAKE.PRICE_MERKLE_ROOT;
    balanceMerkleRoot = STAKE.BALANCE_MERKLE_ROOT;
    oraclePosition = STAKE.ORACLE_POSITION;
  }

  function getValidator(
    bytes calldata pubkey
  ) external view virtual override returns (SML.Validator memory) {
    return STAKE.validators[pubkey];
  }

  function getPackageVersion(uint256 _type) external view virtual override returns (uint256) {
    return STAKE.packages[_type];
  }

  function isMiddleware(
    uint256 _type,
    uint256 _version
  ) external view virtual override returns (bool) {
    return STAKE.middlewares[_type][_version];
  }

  /**
   * @custom:section                           ** OPERATOR INITIATOR **
   */
  /**
   * @dev -> external -> one
   */
  function initiateOperator(
    uint256 id,
    uint256 fee,
    uint256 validatorPeriod,
    address maintainer
  ) external payable virtual override whenNotPaused nonReentrant {
    SML.initiateOperator(DATASTORE, id, fee, validatorPeriod, maintainer);
  }

  /**
   * @custom:section                           ** STAKING POOL INITIATOR **
   */

  /**
   * @dev -> external
   */
  function deployLiquidityPool(uint256 poolId) external virtual override whenNotPaused {
    STAKE.deployLiquidityPool(DATASTORE, poolId);
  }

  function initiatePool(
    uint256 fee,
    uint256 middlewareVersion,
    address maintainer,
    bytes calldata NAME,
    bytes calldata middleware_data,
    bool[3] calldata config
  ) external payable virtual override whenNotPaused returns (uint256 poolId) {
    poolId = STAKE.initiatePool(
      DATASTORE,
      fee,
      middlewareVersion,
      maintainer,
      NAME,
      middleware_data,
      config
    );
  }

  /**
   * @custom:section                           ** POOL VISIBILITY **
   */
  /**
   * @dev -> external -> all
   */

  function setPoolVisibility(uint256 poolId, bool isPrivate) external virtual override {
    SML.setPoolVisibility(DATASTORE, poolId, isPrivate);
  }

  function setWhitelist(uint256 poolId, address whitelist) external virtual override {
    SML.setWhitelist(DATASTORE, poolId, whitelist);
  }

  /**
   * @custom:section                           ** MAINTAINERS **
   */
  /**
   * @dev -> external -> all
   */
  function changeMaintainer(
    uint256 poolId,
    address newMaintainer
  ) external virtual override whenNotPaused {
    SML.changeMaintainer(DATASTORE, poolId, newMaintainer);
  }

  /**
   * @custom:section                           ** FEE **
   */

  /**
   * @dev -> view
   */
  function getMaintenanceFee(uint256 id) external view virtual override returns (uint256) {
    return SML.getMaintenanceFee(DATASTORE, id);
  }

  /**
   * @dev -> external
   */
  function switchMaintenanceFee(
    uint256 id,
    address newMaintainer
  ) external virtual override whenNotPaused {
    SML.changeMaintainer(DATASTORE, id, newMaintainer);
  }

  /**
   * @custom:section                           ** INTERNAL WALLET **
   */
  /**
   * @dev -> external -> all
   */

  function increaseWalletBalance(
    uint256 id
  ) external payable virtual override whenNotPaused nonReentrant returns (bool) {
    return SML.increaseWalletBalance(DATASTORE, id);
  }

  function decreaseWalletBalance(
    uint256 id,
    uint256 value
  ) external virtual override whenNotPaused nonReentrant returns (bool) {
    return SML.decreaseWalletBalance(DATASTORE, id, value);
  }

  /**
   * @custom:section                           ** PRISON **
   */

  /**
   * @dev -> view
   */

  function isPrisoned(uint256 operatorId) external view virtual override returns (bool) {
    return SML.isPrisoned(DATASTORE, operatorId);
  }

  /**
   * @dev -> external
   */
  function blameOperator(bytes calldata pk) external virtual override whenNotPaused {
    STAKE.blameOperator(DATASTORE, pk);
  }

  /**
   * @custom:section                           ** OPERATOR FUNCTIONS **
   */
  /**
   * @dev -> external -> all
   */
  function switchValidatorPeriod(
    uint256 operatorId,
    uint256 newPeriod
  ) external virtual override whenNotPaused {
    SML.switchValidatorPeriod(DATASTORE, operatorId, newPeriod);
  }

  /**
   * @custom:section                           ** VALIDATOR DELEGATION **
   */

  /**
   * @dev -> view
   */

  function operatorAllowance(
    uint256 poolId,
    uint256 operatorId
  ) external view virtual override returns (uint256) {
    return STAKE.operatorAllowance(DATASTORE, poolId, operatorId);
  }

  /**
   * @dev -> external
   */

  function delegate(
    uint256 poolId,
    uint256[] calldata operatorIds,
    uint256[] calldata allowances,
    uint256 fallbackOperator
  ) external virtual override whenNotPaused {
    SML.delegate(DATASTORE, poolId, operatorIds, allowances, fallbackOperator);
  }

  /**
   * @custom:section                           ** POOL HELPERS **
   */
  /**
   * @dev -> view -> all
   */

  function isWhitelisted(
    uint256 poolId,
    address staker
  ) external view virtual override returns (bool) {
    return SML.isWhitelisted(DATASTORE, poolId, staker);
  }

  function isPrivatePool(uint256 poolId) external view virtual override returns (bool) {
    return SML.isPrivatePool(DATASTORE, poolId);
  }

  function isPriceValid(uint256 poolId) external view virtual override returns (bool) {
    return STAKE.isPriceValid(poolId);
  }

  function isMintingAllowed(uint256 poolId) external view virtual override returns (bool) {
    return STAKE.isMintingAllowed(DATASTORE, poolId);
  }

  /**
   * @custom:section                           ** POOLING OPERATIONS **
   */
  /**
   * @dev -> external -> one
   */
  function deposit(
    uint256 poolId,
    uint256 mingETH,
    uint256 deadline,
    address receiver
  )
    external
    payable
    virtual
    override
    whenNotPaused
    nonReentrant
    returns (uint256 boughtgETH, uint256 mintedgETH)
  {
    (boughtgETH, mintedgETH) = STAKE.deposit(DATASTORE, poolId, mingETH, deadline, receiver);
  }

  /**
   * @custom:section                           ** VALIDATOR CREATION **
   */

  /**
   * @dev -> view
   */

  function canStake(bytes calldata pubkey) external view virtual override returns (bool) {
    STAKE.canStake(pubkey);
  }

  /**
   * @dev -> external
   */

  function proposeStake(
    uint256 poolId,
    uint256 operatorId,
    bytes[] calldata pubkeys,
    bytes[] calldata signatures1,
    bytes[] calldata signatures31
  ) external virtual override whenNotPaused {
    STAKE.proposeStake(DATASTORE, poolId, operatorId, pubkeys, signatures1, signatures31);
  }

  function beaconStake(
    uint256 operatorId,
    bytes[] calldata pubkeys
  ) external virtual override whenNotPaused {
    STAKE.beaconStake(DATASTORE, operatorId, pubkeys);
  }
}
