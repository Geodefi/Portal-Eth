// SPDX-License-Identifier: MIT

//   ██████╗ ███████╗ ██████╗ ██████╗ ███████╗    ██████╗  ██████╗ ██████╗ ████████╗ █████╗ ██╗
//  ██╔════╝ ██╔════╝██╔═══██╗██╔══██╗██╔════╝    ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██║
//  ██║  ███╗█████╗  ██║   ██║██║  ██║█████╗      ██████╔╝██║   ██║██████╔╝   ██║   ███████║██║
//  ██║   ██║██╔══╝  ██║   ██║██║  ██║██╔══╝      ██╔═══╝ ██║   ██║██╔══██╗   ██║   ██╔══██║██║
//  ╚██████╔╝███████╗╚██████╔╝██████╔╝███████╗    ██║     ╚██████╔╝██║  ██║   ██║   ██║  ██║███████╗
//   ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
//

pragma solidity =0.8.7;
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IgETH.sol";
import "../interfaces/IPortal.sol";
import "../interfaces/IWithdrawalContract.sol";

import {ID_TYPE, PERCENTAGE_DENOMINATOR} from "./utils/globals.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title Geode Portal : Configurable Trustless Staking Pools
 * *
 * @dev Portal doesn't have any functionality other than hosting and combining the functionalities of some libraries:
 * Provides a first of its kind trustless implementation on Staking Derivatives: gETH
 * The Portal utilizes an isolated storage which allows storing infinitely many different
 * * types of dynamic structs, easily with ID and KEY pairs.
 * Portal is secured by The Dual Governance and Limited Upgradability.
 * Portal hosts The Staking Library allowing the creation and maintanence of configurable
 * * staking pools and validator creation process.
 * Underlying validator balances for each pool is secured with unique Withdrawal Contracts.
 *
 * @dev TYPE: seperates the proposals and related functionality between different ID types on the Isolated Storage.
 * * Currently RESERVED TYPES are written on globals.sol.
 *
 * @dev authentication:
 * * geodeUtils has OnlyGovernance, OnlySenate and OnlyController checks with modifiers.
 * * stakeUtils has "authenticate()" function which checks for Maintainer, Controllers, and TYPE.
 * * oracleutils has OnlyOracle checks with a modifier.
 * * Portal has an OnlyGovernance check on : pause, unpause, pausegETH, unpausegETH, setEarlyExitFee, releasePrisoned.
 *
 * @dev first review DataStoreUtils
 * @dev then review GeodeUtils
 * @dev then review StakeUtils
 * @dev then review OracleUtils
 *
 * note ctrl+k+2 and ctrl+k+1 then scroll while reading the function names and the comments.
 */

contract Portal is
  IPortal,
  ContextUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  ERC1155HolderUpgradeable,
  UUPSUpgradeable
{
  using DataStoreUtils for DataStoreUtils.IsolatedStorage;
  using GeodeUtils for GeodeUtils.DualGovernance;
  using StakeUtils for StakeUtils.PooledStaking;

  /**
   * @notice                                     ** EVENTS **
   *
   * @dev following events are added to help fellow devs with a better ABI
   */

  /**
   * @dev GeodeUtils events
   */
  event GovernanceFeeUpdated(uint256 newFee);
  event ControllerChanged(uint256 indexed id, address newCONTROLLER);
  event Proposed(
    uint256 id,
    address CONTROLLER,
    uint256 indexed TYPE,
    uint256 deadline
  );
  event ProposalApproved(uint256 id);
  event ElectorTypeSet(uint256 TYPE, bool isElector);
  event Vote(uint256 indexed proposalId, uint256 indexed voterId);
  event NewSenate(address senate, uint256 senateExpiry);

  /**
   * @dev StakeUtils events
   */
  event IdInitiated(uint256 indexed id, uint256 indexed TYPE);
  event MaintainerChanged(uint256 indexed id, address newMaintainer);
  event FeeSwitched(uint256 indexed id, uint256 fee, uint256 effectiveAfter);
  event ValidatorPeriodSwitched(
    uint256 indexed id,
    uint256 period,
    uint256 effectiveAfter
  );
  event OperatorApproval(
    uint256 indexed poolId,
    uint256 indexed operatorId,
    uint256 allowance
  );
  event Prisoned(uint256 indexed id, bytes proof, uint256 releaseTimestamp);
  event Released(uint256 indexed id);
  event Deposit(uint256 indexed poolId, uint256 boughtgETH, uint256 mintedgETH);
  event ProposalStaked(
    uint256 indexed poolId,
    uint256 operatorId,
    bytes[] pubkeys
  );
  event BeaconStaked(bytes[] pubkeys);

  /**
   * @dev OracleUtils events
   */
  event Alienated(bytes indexed pubkey);
  event VerificationIndexUpdated(uint256 validatorVerificationIndex);
  event FeeTheft(uint256 indexed id, bytes proofs);
  event OracleReported(bytes32 merkleRoot, uint256 monopolyThreshold);

  /**
   * @dev Portal Native events
   */
  event ContractVersionSet(uint256 version);

  /**
   * @notice                                     ** VARIABLES **
   */
  DataStoreUtils.IsolatedStorage private DATASTORE;
  GeodeUtils.DualGovernance private GEODE;
  StakeUtils.PooledStaking private STAKER;

  /**
   * @notice CONTRACT_VERSION always refers to the upgrade proposal' (TYPE2) ID.
   * @dev Does NOT increase uniformly like one might expect.
   */
  uint256 private CONTRACT_VERSION;

  /**
   * @notice                                     ** PORTAL SPECIFIC **
   */

  ///@custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice initializer function that sets initial parameters like,
   * Oracle Address, Governance, fee etc.
   * Then, creates proposals for the Withdrawal Contract, Liquidity Pools and gETHInterfaces.
   * Finally, it creates an Upgrade Proposal for itself and approves it, setting its version.
   */
  function initialize(
    address _GOVERNANCE,
    address _SENATE,
    address _gETH,
    address _ORACLE_POSITION,
    address _DEFAULT_WITHDRAWAL_CONTRACT_MODULE,
    address _DEFAULT_LP_MODULE,
    address _DEFAULT_LP_TOKEN_MODULE,
    address[] calldata _ALLOWED_GETH_INTERFACE_MODULES,
    bytes[] calldata _ALLOWED_GETH_INTERFACE_MODULE_NAMES,
    uint256 _GOVERNANCE_FEE
  ) public virtual override initializer {
    __ReentrancyGuard_init();
    __Pausable_init();
    __ERC1155Holder_init();
    __UUPSUpgradeable_init();

    require(_GOVERNANCE != address(0), "PORTAL: GOVERNANCE can NOT be ZERO");
    require(_SENATE != address(0), "PORTAL: SENATE can NOT be ZERO");
    require(_gETH != address(0), "PORTAL: gETH can NOT be ZERO");
    require(
      _ORACLE_POSITION != address(0),
      "PORTAL: ORACLE_POSITION can NOT be ZERO"
    );
    require(
      _DEFAULT_LP_MODULE != address(0),
      "PORTAL: DEFAULT_LP can NOT be ZERO"
    );
    require(
      _DEFAULT_LP_TOKEN_MODULE != address(0),
      "PORTAL: DEFAULT_LP_TOKEN can NOT be ZERO"
    );
    require(
      _DEFAULT_WITHDRAWAL_CONTRACT_MODULE != address(0),
      "PORTAL: WITHDRAWAL_CONTRACT_POSITION can NOT be ZERO"
    );
    require(
      _ALLOWED_GETH_INTERFACE_MODULES.length ==
        _ALLOWED_GETH_INTERFACE_MODULE_NAMES.length,
      "PORTAL: wrong _ALLOWED_GETH_INTERFACE_MODULES"
    );
    GEODE.GOVERNANCE = msg.sender;
    GEODE.SENATE = msg.sender;
    GEODE.SENATE_EXPIRY = type(uint256).max;

    GEODE.setGovernanceFee(_GOVERNANCE_FEE);
    GEODE.setElectorType(DATASTORE, ID_TYPE.POOL, true);

    STAKER.gETH = IgETH(_gETH);
    STAKER.MONOPOLY_THRESHOLD = type(uint256).max;

    STAKER.ORACLE_POSITION = _ORACLE_POSITION;
    STAKER.DAILY_PRICE_INCREASE_LIMIT = (5 * PERCENTAGE_DENOMINATOR) / 100;
    STAKER.DAILY_PRICE_DECREASE_LIMIT = (5 * PERCENTAGE_DENOMINATOR) / 100;

    {
      uint256 liqPoolVersion = GEODE.newProposal(
        DATASTORE,
        _DEFAULT_LP_MODULE,
        ID_TYPE.MODULE_LIQUDITY_POOL,
        "v1",
        1 days
      );
      approveProposal(liqPoolVersion);
    }

    {
      uint256 lpTokenVersion = GEODE.newProposal(
        DATASTORE,
        _DEFAULT_LP_TOKEN_MODULE,
        ID_TYPE.MODULE_LIQUDITY_POOL_TOKEN,
        "v1",
        1 days
      );
      approveProposal(lpTokenVersion);
    }

    {
      uint256 withdrawalContractVersion = GEODE.newProposal(
        DATASTORE,
        _DEFAULT_WITHDRAWAL_CONTRACT_MODULE,
        ID_TYPE.MODULE_WITHDRAWAL_CONTRACT,
        "v1",
        1 days
      );
      approveProposal(withdrawalContractVersion);
    }

    {
      uint256 gETHInterfaceVersion;
      for (uint256 i = 0; i < _ALLOWED_GETH_INTERFACE_MODULES.length; ) {
        require(
          _ALLOWED_GETH_INTERFACE_MODULES[i] != address(0),
          "PORTAL: GETH_INTERFACE_MODULE can NOT be ZERO"
        );

        gETHInterfaceVersion = GEODE.newProposal(
          DATASTORE,
          _ALLOWED_GETH_INTERFACE_MODULES[i],
          ID_TYPE.MODULE_GETH_INTERFACE,
          _ALLOWED_GETH_INTERFACE_MODULE_NAMES[i],
          1 days
        );

        approveProposal(gETHInterfaceVersion);
        unchecked {
          i += 1;
        }
      }
    }

    {
      uint256 portalVersion = GEODE.newProposal(
        DATASTORE,
        address(this),
        ID_TYPE.CONTRACT_UPGRADE,
        "v1",
        1 days
      );
      approveProposal(portalVersion);
      _setContractVersion(portalVersion);
    }

    GEODE.GOVERNANCE = _GOVERNANCE;
    GEODE.SENATE = _SENATE;
  }

  /**
   * @dev  ->  modifier
   */

  modifier onlyGovernance() {
    require(msg.sender == GEODE.getGovernance(), "Portal: ONLY GOVERNANCE");
    _;
  }

  /**
   * @dev  ->  internal
   */

  /**
   * @dev required by the OZ UUPS module
   * note that there is no Governance check, as upgrades are effective
   * * right after the Senate approval
   */
  function _authorizeUpgrade(
    address proposed_implementation
  ) internal virtual override {
    require(proposed_implementation != address(0));
    require(
      GEODE.isUpgradeAllowed(proposed_implementation),
      "Portal: is not allowed to upgrade"
    );
  }

  function _setContractVersion(uint256 versionId) internal virtual {
    CONTRACT_VERSION = versionId;
    GEODE.approvedVersion = address(0);
    emit ContractVersionSet(getContractVersion());
  }

  /**
   * @dev  ->  view
   */

  function getContractVersion() public view virtual override returns (uint256) {
    return CONTRACT_VERSION;
  }

  /**
   * @dev  ->  external
   */

  function pause() external virtual override onlyGovernance {
    _pause();
  }

  function unpause() external virtual override onlyGovernance {
    _unpause();
  }

  /**
   * @notice                                     ** gETH  **
   */

  /**
   * @dev  ->  view
   */

  /**
   * @notice get the position of ERC1155
   */
  function gETH() external view virtual override returns (address) {
    return address(STAKER.gETH);
  }

  /**
   * @notice read the list of interfaces for a gETH ID
   */
  function gETHInterfaces(
    uint256 id,
    uint256 index
  ) external view virtual override returns (address) {
    return StakeUtils.gETHInterfaces(DATASTORE, id, index);
  }

  /**
   * @dev  ->  external
   */

  function pausegETH() external virtual override onlyGovernance {
    STAKER.gETH.pause();
  }

  function unpausegETH() external virtual override onlyGovernance {
    STAKER.gETH.unpause();
  }

  /**
   * @notice                                     ** DATASTORE **
   */

  /**
   * @dev  ->  view
   */

  /**
   * @dev useful for outside reach, shouldn't be used within contracts as a referance
   * @return allIdsByType is an array of IDs of the given TYPE from Datastore,
   * returns a specific index
   */
  function allIdsByType(
    uint256 _type,
    uint256 _index
  ) external view virtual override returns (uint256) {
    return DATASTORE.allIdsByType[_type][_index];
  }

  /**
   * @notice useful view function for string inputs - returns same with the DATASTOREUTILS.generateId
   * @dev id is keccak(name, type)
   */
  function generateId(
    string calldata _name,
    uint256 _type
  ) external pure virtual override returns (uint256 id) {
    id = uint256(keccak256(abi.encodePacked(_name, _type)));
  }

  /**
   * @notice useful view function for string inputs - returns same with the DATASTOREUTILS.generateId
   */
  function getKey(
    uint256 _id,
    bytes32 _param
  ) external pure virtual override returns (bytes32 key) {
    return DataStoreUtils.getKey(_id, _param);
  }

  function readUintForId(
    uint256 id,
    bytes32 key
  ) external view virtual override returns (uint256 data) {
    data = DATASTORE.readUintForId(id, key);
  }

  function readAddressForId(
    uint256 id,
    bytes32 key
  ) external view virtual override returns (address data) {
    data = DATASTORE.readAddressForId(id, key);
  }

  function readBytesForId(
    uint256 id,
    bytes32 key
  ) external view virtual override returns (bytes memory data) {
    data = DATASTORE.readBytesForId(id, key);
  }

  function readUintArrayForId(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view virtual override returns (uint256 data) {
    data = DATASTORE.readUintArrayForId(id, key, index);
  }

  function readBytesArrayForId(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view virtual override returns (bytes memory data) {
    data = DATASTORE.readBytesArrayForId(id, key, index);
  }

  function readAddressArrayForId(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view virtual override returns (address data) {
    data = DATASTORE.readAddressArrayForId(id, key, index);
  }

  /**
   * @notice                                     ** GEODE **
   */

  /**
   * @dev  ->  view
   */

  function GeodeParams()
    external
    view
    virtual
    override
    returns (
      address SENATE,
      address GOVERNANCE,
      uint256 SENATE_EXPIRY,
      uint256 GOVERNANCE_FEE
    )
  {
    SENATE = GEODE.getSenate();
    GOVERNANCE = GEODE.getGovernance();
    SENATE_EXPIRY = GEODE.getSenateExpiry();
    GOVERNANCE_FEE = GEODE.getGovernanceFee();
  }

  function getProposal(
    uint256 id
  )
    external
    view
    virtual
    override
    returns (GeodeUtils.Proposal memory proposal)
  {
    proposal = GEODE.getProposal(id);
  }

  function isElector(
    uint256 _TYPE
  ) external view virtual override returns (bool) {
    return GEODE._electorTypes[_TYPE];
  }

  function isUpgradeAllowed(
    address proposedImplementation
  ) external view virtual override returns (bool) {
    return GEODE.isUpgradeAllowed(proposedImplementation);
  }

  /**
   * @dev  ->  external
   */

  /**
   * @dev Governance Functions
   */

  /**
   * @notice only parameter of GeodeUtils that can be mutated is the fee
   */
  function setGovernanceFee(uint256 newFee) external virtual override {
    GEODE.setGovernanceFee(newFee);
  }

  function setElectorType(
    uint256 _TYPE,
    bool _isElector
  ) external virtual override {
    GEODE.setElectorType(DATASTORE, _TYPE, _isElector);
  }

  function newProposal(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external virtual override {
    GEODE.newProposal(DATASTORE, _CONTROLLER, _TYPE, _NAME, duration);
  }

  /**
   * @dev Senate Functions
   */

  /**
   * @notice approves a specific proposal
   * @dev OnlySenate is checked inside the GeodeUtils
   */
  function approveProposal(uint256 id) public virtual override {
    (uint256 _type, ) = GEODE.approveProposal(DATASTORE, id);
    if (
      _type == ID_TYPE.MODULE_WITHDRAWAL_CONTRACT ||
      _type == ID_TYPE.MODULE_LIQUDITY_POOL ||
      _type == ID_TYPE.MODULE_LIQUDITY_POOL_TOKEN
    ) {
      STAKER._defaultModules[_type] = id;
    } else if (_type == ID_TYPE.MODULE_GETH_INTERFACE) {
      STAKER._allowedModules[_type][id] = true;
    }
  }

  /**
   * @notice changes the Senate's address without extending the expiry
   * @dev OnlySenate is checked inside the GeodeUtils
   */
  function changeSenate(address _newSenate) external virtual override {
    GEODE.changeSenate(_newSenate);
  }

  /**
   * @dev CONTROLLER Functions
   */

  function changeIdCONTROLLER(
    uint256 id,
    address newCONTROLLER
  ) external virtual override whenNotPaused {
    GeodeUtils.changeIdCONTROLLER(DATASTORE, id, newCONTROLLER);
  }

  function approveSenate(
    uint256 proposalId,
    uint256 electorId
  ) external virtual override {
    GEODE.approveSenate(DATASTORE, proposalId, electorId);
  }

  /**
   * @notice                                     ** THE STAKING LIBRARY **
   */

  /**
   * @dev  ->  view
   */

  function StakingParams()
    external
    view
    virtual
    override
    returns (
      uint256 VALIDATORS_INDEX,
      uint256 VERIFICATION_INDEX,
      uint256 MONOPOLY_THRESHOLD,
      uint256 EARLY_EXIT_FEE,
      uint256 ORACLE_UPDATE_TIMESTAMP,
      uint256 DAILY_PRICE_INCREASE_LIMIT,
      uint256 DAILY_PRICE_DECREASE_LIMIT,
      bytes32 PRICE_MERKLE_ROOT,
      address ORACLE_POSITION
    )
  {
    VALIDATORS_INDEX = STAKER.VALIDATORS_INDEX;
    VERIFICATION_INDEX = STAKER.VERIFICATION_INDEX;
    MONOPOLY_THRESHOLD = STAKER.MONOPOLY_THRESHOLD;
    EARLY_EXIT_FEE = STAKER.EARLY_EXIT_FEE;
    ORACLE_UPDATE_TIMESTAMP = STAKER.ORACLE_UPDATE_TIMESTAMP;
    DAILY_PRICE_INCREASE_LIMIT = STAKER.DAILY_PRICE_INCREASE_LIMIT;
    DAILY_PRICE_DECREASE_LIMIT = STAKER.DAILY_PRICE_DECREASE_LIMIT;
    PRICE_MERKLE_ROOT = STAKER.PRICE_MERKLE_ROOT;
    ORACLE_POSITION = STAKER.ORACLE_POSITION;
  }

  function getValidator(
    bytes calldata pubkey
  ) external view virtual override returns (StakeUtils.Validator memory) {
    return STAKER._validators[pubkey];
  }

  function getValidatorByPool(
    uint256 poolId,
    uint256 index
  ) external view virtual override returns (bytes memory) {
    return DATASTORE.readBytesArrayForId(poolId, "validators", index);
  }

  function getMaintenanceFee(
    uint256 id
  ) external view virtual override returns (uint256 fee) {
    fee = StakeUtils.getMaintenanceFee(DATASTORE, id);
  }

  function isPrisoned(
    uint256 operatorId
  ) external view virtual override returns (bool) {
    return StakeUtils.isPrisoned(DATASTORE, operatorId);
  }

  function isPrivatePool(
    uint256 poolId
  ) external view virtual override returns (bool) {
    return StakeUtils.isPrivatePool(DATASTORE, poolId);
  }

  function isPriceValid(
    uint256 poolId
  ) external view virtual override returns (bool) {
    return STAKER.isPriceValid(poolId);
  }

  function isMintingAllowed(
    uint256 poolId
  ) external view virtual override returns (bool) {
    return STAKER.isMintingAllowed(DATASTORE, poolId);
  }

  function canStake(
    bytes calldata pubkey
  ) external view virtual override returns (bool) {
    return STAKER.canStake(DATASTORE, pubkey);
  }

  function getDefaultModule(
    uint256 _type
  ) external view virtual override returns (uint256 _version) {
    _version = STAKER._defaultModules[_type];
  }

  function isAllowedModule(
    uint256 _type,
    uint256 _id
  ) external view virtual override returns (bool) {
    return STAKER._allowedModules[_type][_id];
  }

  /**
   * @dev  ->  external
   */

  /**
   * @dev MODULES
   */

  function fetchWithdrawalContractUpgradeProposal(
    uint256 id
  ) external virtual override returns (uint256 withdrawalContractVersion) {
    withdrawalContractVersion = STAKER._defaultModules[
      ID_TYPE.MODULE_WITHDRAWAL_CONTRACT
    ];

    StakeUtils.withdrawalContractById(DATASTORE, id).newProposal(
      DATASTORE.readAddressForId(withdrawalContractVersion, "CONTROLLER"),
      ID_TYPE.CONTRACT_UPGRADE,
      DATASTORE.readBytesForId(withdrawalContractVersion, "NAME"),
      4 weeks
    );
  }

  function deployLiquidityPool(
    uint256 poolId
  ) external virtual override whenNotPaused {
    STAKER.deployLiquidityPool(DATASTORE, poolId, GEODE.getGovernance());
  }

  function setPoolVisibility(
    uint256 poolId,
    bool isPrivate
  ) external virtual override whenNotPaused {
    StakeUtils.setPoolVisibility(DATASTORE, poolId, isPrivate);
  }

  function setWhitelist(
    uint256 poolId,
    address whitelist
  ) external virtual override whenNotPaused {
    StakeUtils.setWhitelist(DATASTORE, poolId, whitelist);
  }

  /**
   * @dev INITIATORS
   */

  function initiateOperator(
    uint256 id,
    uint256 fee,
    uint256 validatorPeriod,
    address maintainer
  ) external payable virtual override whenNotPaused {
    StakeUtils.initiateOperator(
      DATASTORE,
      id,
      fee,
      validatorPeriod,
      maintainer
    );
  }

  function initiatePool(
    uint256 fee,
    uint256 interfaceVersion,
    address maintainer,
    bytes calldata NAME,
    bytes calldata interface_data,
    bool[3] calldata config
  ) external payable virtual override whenNotPaused {
    STAKER.initiatePool(
      DATASTORE,
      fee,
      interfaceVersion,
      maintainer,
      GEODE.getGovernance(),
      NAME,
      interface_data,
      config
    );
  }

  /**
   * @dev MAINTAINERS
   */

  function changeMaintainer(
    uint256 id,
    address newMaintainer
  ) external virtual override whenNotPaused {
    StakeUtils.changeMaintainer(DATASTORE, id, newMaintainer);
  }

  /**
   * @dev MAINTENANCE FEE
   */
  function switchMaintenanceFee(
    uint256 id,
    uint256 newFee
  ) external virtual override whenNotPaused {
    StakeUtils.switchMaintenanceFee(DATASTORE, id, newFee);
  }

  /**
   * @dev INTERNAL WALLET
   */

  function increaseWalletBalance(
    uint256 id
  ) external payable virtual override returns (bool success) {
    success = StakeUtils.increaseWalletBalance(DATASTORE, id);
  }

  function decreaseWalletBalance(
    uint256 id,
    uint256 value
  )
    external
    virtual
    override
    whenNotPaused
    nonReentrant
    returns (bool success)
  {
    success = StakeUtils.decreaseWalletBalance(DATASTORE, id, value);
  }

  /**
   * @dev OPERATORS
   */

  function switchValidatorPeriod(
    uint256 id,
    uint256 newPeriod
  ) external virtual override whenNotPaused {
    StakeUtils.switchValidatorPeriod(DATASTORE, id, newPeriod);
  }

  function blameOperator(
    bytes calldata pk
  ) external virtual override whenNotPaused {
    STAKER.blameOperator(DATASTORE, pk);
  }

  function setEarlyExitFee(
    uint256 fee
  ) external virtual override whenNotPaused onlyGovernance {
    require(fee < StakeUtils.MAX_EARLY_EXIT_FEE);
    STAKER.EARLY_EXIT_FEE = fee;
  }

  /**
   * @dev PRISON
   */

  /**
   * @notice releases an imprisoned operator immidately
   * @dev in different situations such as a faulty imprisonment or coordinated testing periods
   * * Governance can release the prisoners
   * @dev onlyGovernance SHOULD be checked in Portal
   */
  function releasePrisoned(
    uint256 operatorId
  ) external virtual override whenNotPaused onlyGovernance {
    DATASTORE.writeUintForId(operatorId, "released", block.timestamp);

    emit Released(operatorId);
  }

  /**
   * @dev OPERATOR APPROVALS
   */

  function approveOperators(
    uint256 poolId,
    uint256[] calldata operatorIds,
    uint256[] calldata allowances
  ) external virtual override whenNotPaused {
    StakeUtils.batchApproveOperators(
      DATASTORE,
      poolId,
      operatorIds,
      allowances
    );
  }

  /**
   * @dev STAKING
   */

  function deposit(
    uint256 poolId,
    uint256 mingETH,
    uint256 deadline,
    uint256 price,
    bytes32[] calldata priceProof,
    address receiver
  ) external payable virtual override whenNotPaused nonReentrant {
    if (!STAKER.isPriceValid(poolId)) {
      OracleUtils.priceSync(DATASTORE, STAKER, poolId, price, priceProof);
    }
    STAKER.deposit(DATASTORE, poolId, mingETH, deadline, receiver);
  }

  function proposeStake(
    uint256 poolId,
    uint256 operatorId,
    bytes[] calldata pubkeys,
    bytes[] calldata signatures1,
    bytes[] calldata signatures31
  ) external virtual override whenNotPaused nonReentrant {
    STAKER.proposeStake(
      DATASTORE,
      poolId,
      operatorId,
      pubkeys,
      signatures1,
      signatures31
    );
  }

  function beaconStake(
    uint256 operatorId,
    bytes[] calldata pubkeys
  ) external virtual override whenNotPaused nonReentrant {
    STAKER.beaconStake(DATASTORE, operatorId, pubkeys);
  }

  /**
   * @notice                                     ** ORACLE **
   */

  /**
   * @dev  ->  external
   */

  function updateVerificationIndex(
    uint256 validatorVerificationIndex,
    bytes[] calldata alienatedPubkeys
  ) external virtual override whenNotPaused {
    OracleUtils.updateVerificationIndex(
      DATASTORE,
      STAKER,
      validatorVerificationIndex,
      alienatedPubkeys
    );
  }

  function regulateOperators(
    uint256[] calldata feeThefts,
    bytes[] calldata stolenBlocks
  ) external virtual override whenNotPaused {
    OracleUtils.regulateOperators(DATASTORE, STAKER, feeThefts, stolenBlocks);
  }

  function reportOracle(
    bytes32 priceMerkleRoot,
    uint256 allValidatorsCount
  ) external virtual override whenNotPaused {
    OracleUtils.reportOracle(STAKER, priceMerkleRoot, allValidatorsCount);
  }

  function priceSync(
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProofs
  ) external virtual override whenNotPaused {
    OracleUtils.priceSync(DATASTORE, STAKER, poolId, price, priceProofs);
  }

  function priceSyncBatch(
    uint256[] calldata poolIds,
    uint256[] calldata prices,
    bytes32[][] calldata priceProofs
  ) external virtual override whenNotPaused {
    OracleUtils.priceSyncBatch(DATASTORE, STAKER, poolIds, prices, priceProofs);
  }

  /**
   * @notice fallback functions
   */
  function Do_we_care() external pure returns (bool) {
    return true;
  }

  fallback() external payable {}

  receive() external payable {}

  /**
   * @notice keep the contract size at 50
   */
  uint256[46] private __gap;
}
