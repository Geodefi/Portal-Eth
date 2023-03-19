// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ID_TYPE, VALIDATOR_STATE, PERCENTAGE_DENOMINATOR} from "./globals.sol";

import {DataStoreUtils as DSU} from "./DataStoreUtilsLib.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";

import {IgETH} from "../../interfaces/IgETH.sol";
import {IWithdrawalContract} from "../../interfaces/IWithdrawalContract.sol";
import {ISwap} from "../../interfaces/ISwap.sol";
import {ILPToken} from "../../interfaces/ILPToken.sol";
import {IWhitelist} from "../../interfaces/IWhitelist.sol";
import {IgETHInterface} from "../../interfaces/IgETHInterface.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title The Staking Library
 * @notice Creating a global standard for Staking, allowing anyone to create a trustless staking pool,
 * improving the user experience for stakers and removing the need for intermediaries.
 * * Exclusively contains functions related to:
 * * 1. Modular Architecture of Configurable Staking Pools
 * * 2. Operator Marketplace and Staking Operations.
 * @dev It is important to keep every pool isolated and remember that every validator is unique.
 *
 * @dev Controllers and Maintainers:
 * * CONTROLLER is the owner of an ID, it manages the pool or the operator and its security is exteremely important.
 * * maintainer is the worker, can be used to automate some daily tasks
 * * * like distributing validators for Staking Pools or creating validators for Operators,
 * * * not so crucial in terms of security.
 *
 * @dev Reserved ID_TYPE:
 *
 * USERS:
 *
 * * Type 4 : Permissioned Operators
 * * * Needs to be onboarded by the Dual Governance (Senate + Governance).
 * * * Maintains Beacon Chain Validators on behalf of the Staking Pools.
 * * * Can participate in the Operator Marketplace after initiation.
 * * * Can utilize maintainers for staking operations.
 *
 * * Type 5 : Configurable Staking Pools
 * * * Permissionless to create.
 * * * Can utilize powers of modules such as Bound Liquidity Pools, Interfaces etc.
 * * * Can be public or private, can use a whitelist if private.
 * * * Can utilize maintainers for validator distribution on Operator Marketplace.
 * * * Uses a Withdrawal Contract to be given as withdrawalCredential on validator creation,
 * * * accruing rewards and keeping Staked Ether safe and isolated.
 *
 * DEFAULT MODULES:
 * * Some Modules has only 1 version that can be used by the Pool Owners.
 *
 * * Type 10011 : Withdrawal Contract implementation version
 * * * Mandatory.
 * * * CONTROLLER is the implementation contract position (like always)
 * * * Requires the approval of Senate
 * * * Pools are in "Recovery Mode" until their Withdrawal Contract is upgraded.
 * * * * Meaning, no more Depositing or Staking can happen.
 *
 * * Type 10021 : Liquidity Pool version
 * * * Optional.
 * * * CONTROLLER is the implementation contract position (like always)
 * * * Requires the approval of Senate.
 * * * Pools can simply deploy the new version of this Module and start using it, if ever changed.
 * * * Liquidity Providers however, need to migrate.
 *
 * * Type 10022 : Liquidity Pool Token version
 * * * Optional, dependant to Liquidity Pool Module.
 * * * CONTROLLER is the implementation contract position (like always)
 * * * Requires the approval of Senate
 * * * Crucial to have the same name with the LP version
 *
 * ALLOWED MODULES:
 * * Some Modules can support many different versions that can be used by the Pool Owners.
 *
 * * Type 20031 : gETH interface version
 * * * Optional.
 * * * CONTROLLER is the implementation contract position (like always)
 * * * Requires the approval of Senate
 * * * Currently should be utilized on initiation.
 *
 * @dev Contracts relying on this library must initialize StakeUtils.PooledStaking
 * @dev Functions are already protected with authentication
 *
 * @dev first review DataStoreUtils
 * @dev then review GeodeUtils
 */

library StakeUtils {
  /// @notice Using DataStoreUtils for IsolatedStorage struct
  using DSU for DSU.IsolatedStorage;

  /// @notice EVENTS
  event IdInitiated(uint256 indexed id, uint256 indexed TYPE);
  event VisibilitySet(uint256 id, bool indexed isPrivate);
  event MaintainerChanged(uint256 indexed id, address newMaintainer);
  event FeeSwitched(uint256 indexed id, uint256 fee, uint256 effectiveAfter);
  event ValidatorPeriodSwitched(uint256 indexed id, uint256 period, uint256 effectiveAfter);
  event OperatorApproval(uint256 indexed poolId, uint256 indexed operatorId, uint256 allowance);
  event Prisoned(uint256 indexed id, bytes proof, uint256 releaseTimestamp);
  event Deposit(uint256 indexed poolId, uint256 boughtgETH, uint256 mintedgETH);
  event ProposalStaked(uint256 indexed poolId, uint256 operatorId, bytes[] pubkeys);
  event BeaconStaked(bytes[] pubkeys);

  /**
   * @param state state of the validator, refer to globals.sol
   * @param index representing this validator's placement on the chronological order of the validators proposals
   * @param poolId needed for withdrawal_credential
   * @param operatorId needed for staking after allowance
   * @param poolFee percentage of the rewards that will go to pool's maintainer, locked when the validator is proposed
   * @param operatorFee percentage of the rewards that will go to operator's maintainer, locked when the validator is proposed
   * @param createdAt the timestamp pointing the proposal to create a validator with given pubkey.
   * @param expectedExit the latest point in time the operator is allowed to maintain this validator (createdAt + validatorPeriod).
   * @param signature BLS12-381 signature for the validator, used when sending the remaining 31 ETH on validator activation.
   **/
  struct Validator {
    uint8 state;
    uint256 index;
    uint256 poolId;
    uint256 operatorId;
    uint256 poolFee;
    uint256 operatorFee;
    uint256 earlyExitFee;
    uint256 createdAt;
    uint256 expectedExit;
    bytes signature31;
  }

  /**
   * @param gETH ERC1155, Staking Derivatives Token, should NOT be changed.
   * @param VALIDATORS_INDEX total number of validators that are proposed at any given point.
   * * Includes all validators: proposed, active, alienated, exited.
   * @param VERIFICATION_INDEX the highest index of the validators that are verified (as not alien) by the Holy Oracle.
   * @param MONOPOLY_THRESHOLD max number of validators 1 operator is allowed to operate, updated by the Holy Oracle.
   * @param EARLY_EXIT_FEE a parameter to be used while handling the validator exits, currently 0 and logic around it is ambigious.
   * @param ORACLE_UPDATE_TIMESTAMP timestamp of the latest oracle update
   * @param DAILY_PRICE_DECREASE_LIMIT limiting the price decreases for one oracle period, 24h. Effective for any time interval.
   * @param DAILY_PRICE_INCREASE_LIMIT limiting the price increases for one oracle period, 24h. Effective for any time interval.
   * @param PRICE_MERKLE_ROOT merkle root of the prices of every pool
   * @param ORACLE_POSITION address of the Oracle multisig https://github.com/Geodefi/Telescope-Eth
   * @param _defaultModules TYPE => version, pointing to the latest versions of the given TYPE.
   * * Like default Withdrawal Contract version.
   * @param _allowedModules TYPE => version => isAllowed, useful to check if any version of the module can be used.
   * * Like all the whitelisted gETH interfaces.
   * @param _validators pubkey => Validator, contains all the data about proposed, alienated, active, exited validators
   * @param __gap keep the struct size at 16
   **/
  struct PooledStaking {
    IgETH gETH;
    uint256 VALIDATORS_INDEX;
    uint256 VERIFICATION_INDEX;
    uint256 MONOPOLY_THRESHOLD;
    uint256 EARLY_EXIT_FEE;
    uint256 ORACLE_UPDATE_TIMESTAMP;
    uint256 DAILY_PRICE_INCREASE_LIMIT;
    uint256 DAILY_PRICE_DECREASE_LIMIT;
    bytes32 PRICE_MERKLE_ROOT;
    address ORACLE_POSITION;
    mapping(uint256 => uint256) _defaultModules;
    mapping(uint256 => mapping(uint256 => bool)) _allowedModules;
    mapping(bytes => Validator) _validators;
    uint256[3] __gap;
  }
  /**
   * @notice                                     ** Constants **
   */

  /// @notice limiting the pool and operator maintenance fee, 10%
  uint256 public constant MAX_MAINTENANCE_FEE = (PERCENTAGE_DENOMINATOR * 10) / 100;

  /// @notice limiting EARLY_EXIT_FEE, 5%
  uint256 public constant MAX_EARLY_EXIT_FEE = (PERCENTAGE_DENOMINATOR * 5) / 100;

  /// @notice price of gETH is only valid for 24H, after that minting is not allowed.
  uint256 public constant PRICE_EXPIRY = 24 hours;

  /// @notice ignoring any buybacks if the Liquidity Pools has a low debt
  uint256 public constant IGNORABLE_DEBT = 1 ether;

  /// @notice limiting the operator.validatorPeriod, between 3 months to 5 years
  uint256 public constant MIN_VALIDATOR_PERIOD = 90 days;
  uint256 public constant MAX_VALIDATOR_PERIOD = 1825 days;

  /// @notice some parameter changes are effective after a delay
  uint256 public constant SWITCH_LATENCY = 3 days;

  /// @notice limiting the access for Operators in case of bad/malicious/faulty behaviour
  uint256 public constant PRISON_SENTENCE = 14 days;

  /**
   * @notice                                     ** AUTHENTICATION **
   */

  /**
   * @dev  ->  internal
   */

  /**
   * @notice restricts the access to given function based on TYPE and msg.sender
   * @param expectCONTROLLER restricts the access to only CONTROLLER.
   * @param expectMaintainer restricts the access to only maintainer.
   * @param restrictionMap Restricts which TYPEs can pass the authentication.
   * * 0: Operator = TYPE(4), 1: Pool = TYPE(5)
   * @dev authenticate can only be used after an ID is initiated
   * @dev CONTROLLERS and maintainers of the Prisoned Operators can not access.
   * @dev In principal, CONTROLLER should be able to do anything a maintainer is authenticated to do.
   */
  function authenticate(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id,
    bool expectCONTROLLER,
    bool expectMaintainer,
    bool[2] memory restrictionMap
  ) internal view {
    require(DATASTORE.readUintForId(id, "initiated") != 0, "SU: ID is not initiated");

    uint256 typeOfId = DATASTORE.readUintForId(id, "TYPE");

    if (typeOfId == ID_TYPE.OPERATOR) {
      require(restrictionMap[0], "SU: TYPE NOT allowed");

      if (expectCONTROLLER || expectMaintainer) {
        require(
          !isPrisoned(DATASTORE, id),
          "SU: operator is in prison, get in touch with governance"
        );
      }
    } else if (typeOfId == ID_TYPE.POOL) {
      require(restrictionMap[1], "SU: TYPE NOT allowed");
    } else revert("SU: invalid TYPE");

    if (expectMaintainer) {
      require(
        msg.sender == DATASTORE.readAddressForId(id, "maintainer"),
        "SU: sender NOT maintainer"
      );
      return;
    }

    if (expectCONTROLLER) {
      require(
        msg.sender == DATASTORE.readAddressForId(id, "CONTROLLER"),
        "SU: sender NOT CONTROLLER"
      );
      return;
    }
  }

  /**
   * @notice                                     ** CONFIGURABLE STAKING POOL MODULES **
   *
   * - WithdrawalContracts
   * - gETHInterfaces
   * - Bound Liquidity Pools
   * - Pool visibility (public/private) and using whitelists
   */

  /**
   * @dev  ->  view
   */

  /**
   * @notice returns true if the pool is private
   */
  function isPrivatePool(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId
  ) public view returns (bool) {
    return (DATASTORE.readUintForId(poolId, "private") == 1);
  }

  /**
   * @dev  ->  internal
   */

  /**
   * @notice internal function to set a gETHInterface
   * @param _interface address of the new gETHInterface for given ID
   * @dev every interface has a unique index within the "interfaces" dynamic array.
   * @dev on unset, SHOULD replace the implementation with address(0) for obvious security reasons.
   */
  function _setInterface(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id,
    address _interface
  ) internal {
    require(!self.gETH.isInterface(_interface, id), "SU: already interface");
    DATASTORE.appendAddressArrayForId(id, "interfaces", _interface);
    self.gETH.setInterface(_interface, id, true);
  }

  /**
   * @notice deploys a new gETHInterface by cloning the DEFAULT_gETH_INTERFACE
   * @param _version id, can use any version as an interface that is allowed for TYPE = MODULE_GETH_INTERFACE
   * @param interface_data interfaces might require additional data on initialization; like name, symbol, etc.
   * @dev currrently, can NOT deploy an interface after initiation, thus only used by the initiator.
   * @dev currrently, can NOT unset an interface.
   */
  function _deployInterface(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    uint256 _id,
    uint256 _version,
    bytes memory interface_data
  ) internal {
    require(self._allowedModules[ID_TYPE.MODULE_GETH_INTERFACE][_version], "SU: not an interface");

    address gInterface = Clones.clone(DATASTORE.readAddressForId(_version, "CONTROLLER"));

    require(
      IgETHInterface(gInterface).initialize(_id, address(self.gETH), interface_data),
      "SU: could not init interface"
    );

    _setInterface(self, DATASTORE, _id, gInterface);
  }

  /**
   * @notice Deploys a Withdrawal Contract that will be used as a withdrawal credential on validator creation
   * @dev using the latest version of the MODULE_WITHDRAWAL_CONTRACT
   * @dev every pool requires a withdrawal Contract, thus this function is only used by the initiator
   */
  function _deployWithdrawalContract(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    uint256 _id
  ) internal {
    require(
      DATASTORE.readAddressForId(_id, "withdrawalContract") == address(0),
      "SU: has a withdrawal contract"
    );

    uint256 version = self._defaultModules[ID_TYPE.MODULE_WITHDRAWAL_CONTRACT];

    address withdrawalContract = address(
      new ERC1967Proxy(
        DATASTORE.readAddressForId(version, "CONTROLLER"),
        abi.encodeWithSelector(
          IWithdrawalContract(address(0)).initialize.selector,
          version,
          _id,
          self.gETH,
          address(this),
          DATASTORE.readAddressForId(_id, "CONTROLLER")
        )
      )
    );

    DATASTORE.writeAddressForId(_id, "withdrawalContract", withdrawalContract);
    DATASTORE.writeBytesForId(_id, "withdrawalCredential", DCU.addressToWC(withdrawalContract));
  }

  /**
   * @dev  ->  public
   */

  /**
   * @notice deploys a new liquidity pool using the latest version of MODULE_LIQUDITY_POOL
   * @dev sets the liquidity pool, LP token and liquidityPoolVersion
   * @dev gives full allowance to the pool, should not be a problem as portal does not hold any tokens
   * @param _GOVERNANCE governance address will be the owner of the created pool.
   * @dev a controller can deploy a liquidity pool after initiation
   * @dev a controller can deploy a new version of this module, but LPs would need to migrate
   */
  function deployLiquidityPool(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    address _GOVERNANCE
  ) public {
    authenticate(DATASTORE, poolId, true, false, [false, true]);
    uint256 lpVersion = self._defaultModules[ID_TYPE.MODULE_LIQUDITY_POOL];

    require(
      DATASTORE.readUintForId(poolId, "liquidityPoolVersion") != lpVersion,
      "SU: already latest version"
    );

    address lp = Clones.clone(DATASTORE.readAddressForId(lpVersion, "CONTROLLER"));
    bytes memory NAME = DATASTORE.readBytesForId(poolId, "NAME");

    require(
      ISwap(lp).initialize(
        IgETH(self.gETH),
        poolId,
        string(abi.encodePacked(NAME, "-Geode LP Token")),
        string(abi.encodePacked(NAME, "-LP")),
        DATASTORE.readAddressForId(
          self._defaultModules[ID_TYPE.MODULE_LIQUDITY_POOL_TOKEN],
          "CONTROLLER"
        ),
        _GOVERNANCE
      ) != address(0),
      "SU: could not init liquidity pool"
    );

    // approve token so we can use it in buybacks
    self.gETH.setApprovalForAll(lp, true);

    DATASTORE.writeUintForId(poolId, "liquidityPoolVersion", lpVersion);
    DATASTORE.writeAddressForId(poolId, "liquidityPool", lp);
  }

  /**
   * @notice changes the visibility of the pool
   * @param isPrivate true if pool should be private, false for public pools
   * Note private pools can whitelist addresses with the help of a third party contract.
   */
  function setPoolVisibility(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    bool isPrivate
  ) public {
    authenticate(DATASTORE, poolId, true, false, [false, true]);

    require(isPrivate != isPrivatePool(DATASTORE, poolId), "SU: already set");

    DATASTORE.writeUintForId(poolId, "private", isPrivate ? 1 : 0);
    if (!isPrivate) {
      DATASTORE.writeAddressForId(poolId, "whitelist", address(0));
    }
    emit VisibilitySet(poolId, isPrivate);
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice private pools can whitelist addresses with the help of a third party contract
   * @dev Whitelisting contracts should implement IWhitelist interface.
   */
  function setWhitelist(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    address whitelist
  ) external {
    authenticate(DATASTORE, poolId, true, false, [false, true]);
    require(isPrivatePool(DATASTORE, poolId), "SU: must be private pool");

    DATASTORE.writeAddressForId(poolId, "whitelist", whitelist);
  }

  /**
   * @notice                                     ** INITIATORS **
   *
   * IDs that are occupied by a user should be initiated to be activated
   * - Operators need to onboarded by the Dual Governance to be able to initiate an ID.
   * - Pools are permissionless, calling the initiator will immediately activate the pool.
   */

  /**
   * @dev  ->  external
   */

  /**
   * @notice initiates ID as a Permissionned Node Operator
   * @notice requires ID to be approved as a node operator with a specific CONTROLLER
   * @param fee as a percentage limited by MAX_MAINTENANCE_FEE, PERCENTAGE_DENOMINATOR is 100%
   * @param validatorPeriod the expected maximum staking interval. This value should between
   * * MIN_VALIDATOR_PERIOD and MAX_VALIDATOR_PERIOD values defined as constants above.
   * Operator can unstake at any given point before this period ends.
   * If operator disobeys this rule, it can be prisoned with blameOperator()
   * @param maintainer an address that automates daily operations, a script, a contract...
   * @dev operators can fund their internal wallet on initiation by simply sending some ether.
   */
  function initiateOperator(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id,
    uint256 fee,
    uint256 validatorPeriod,
    address maintainer
  ) external {
    require(DATASTORE.readUintForId(id, "initiated") == 0, "SU: already initiated");
    require(DATASTORE.readUintForId(id, "TYPE") == ID_TYPE.OPERATOR, "SU: TYPE NOT allowed");
    require(
      msg.sender == DATASTORE.readAddressForId(id, "CONTROLLER"),
      "SU: sender NOT CONTROLLER"
    );

    DATASTORE.writeUintForId(id, "initiated", block.timestamp);

    _setMaintainer(DATASTORE, id, maintainer);
    _setMaintenanceFee(DATASTORE, id, fee);
    _setValidatorPeriod(DATASTORE, id, validatorPeriod);
    _increaseWalletBalance(DATASTORE, id, msg.value);

    emit IdInitiated(id, ID_TYPE.OPERATOR);
  }

  /**
   * @notice Creates a Configurable Trustless Staking Pool!
   * @param fee as a percentage limited by MAX_MAINTENANCE_FEE, PERCENTAGE_DENOMINATOR is 100%
   * @param interfaceVersion Pool creators can choose any allowed version as their gETHInterface
   * @param maintainer an address that automates daily operations, a script, a contract... not really powerful.
   * @param _GOVERNANCE needed in case the Pool is configured with a Bound Liquidity Pool
   * @param NAME used to generate an ID for the Pool
   * @param interface_data interfaces might require additional data on initialization; like name, symbol, etc.
   * @param config [private(true) or public(false), deploying an interface with given version, deploying liquidity pool with latest version]
   * @dev checking only initiated is enough to validate that ID is not used. no need to check TYPE, CONTROLLER etc.
   * @dev requires exactly 1 validator worth of funds to be deposited on initiation - to prevent sybil attacks
   */
  function initiatePool(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    uint256 fee,
    uint256 interfaceVersion,
    address maintainer,
    address _GOVERNANCE,
    bytes calldata NAME,
    bytes calldata interface_data,
    bool[3] calldata config
  ) external {
    require(msg.value == DCU.DEPOSIT_AMOUNT, "SU: need 1 validator worth of funds");

    uint256 id = DSU.generateId(NAME, ID_TYPE.POOL);

    require(id > 10 ** 9, "SU: Wow! low id");
    require(DATASTORE.readUintForId(id, "initiated") == 0, "SU: already initiated");

    DATASTORE.writeUintForId(id, "initiated", block.timestamp);

    DATASTORE.writeUintForId(id, "TYPE", ID_TYPE.POOL);
    DATASTORE.writeAddressForId(id, "CONTROLLER", msg.sender);
    DATASTORE.writeBytesForId(id, "NAME", NAME);
    DATASTORE.allIdsByType[ID_TYPE.POOL].push(id);

    _setMaintainer(DATASTORE, id, maintainer);
    _setMaintenanceFee(DATASTORE, id, fee);

    _deployWithdrawalContract(self, DATASTORE, id);
    if (config[0]) {
      setPoolVisibility(DATASTORE, id, true);
    }
    if (config[1]) {
      _deployInterface(self, DATASTORE, id, interfaceVersion, interface_data);
    }
    if (config[2]) {
      deployLiquidityPool(self, DATASTORE, id, _GOVERNANCE);
    }

    // initially 1 ETHER = 1 ETHER
    self.gETH.setPricePerShare(1 ether, id);

    // isolate the contract from interface risk for ID
    self.gETH.avoidInterfaces(id, true);

    // mint gETH and send back to the caller
    uint256 mintedgETH = _mintgETH(self, DATASTORE, id, DCU.DEPOSIT_AMOUNT);
    self.gETH.safeTransferFrom(address(this), msg.sender, id, mintedgETH, "");

    emit IdInitiated(id, ID_TYPE.POOL);
  }

  /**
   * @notice                                     ** MAINTAINERS **
   */

  /**
   * @dev  ->  internal
   */

  /**
   * @notice Set the maintainer address on initiation or later
   * @param newMaintainer address of the new maintainer
   */
  function _setMaintainer(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id,
    address newMaintainer
  ) internal {
    require(newMaintainer != address(0), "SU: maintainer can NOT be zero");
    require(
      DATASTORE.readAddressForId(id, "maintainer") != newMaintainer,
      "SU: provided the current maintainer"
    );

    DATASTORE.writeAddressForId(id, "maintainer", newMaintainer);
    emit MaintainerChanged(id, newMaintainer);
  }

  /**
   * @dev  ->  external
   */
  /**
   * @notice CONTROLLER of the ID can change the maintainer to any address other than ZERO_ADDRESS
   * @dev there can only be 1 maintainer per ID.
   * @dev it is wise to change the maintainer before the CONTROLLER, in case of any migration
   * @dev we don't use authenticate here because malicious authenticators can imprison operators
   * * and prevent them entering here.
   */
  function changeMaintainer(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id,
    address newMaintainer
  ) external {
    require(
      msg.sender == DATASTORE.readAddressForId(id, "CONTROLLER"),
      "SU: sender NOT CONTROLLER"
    );
    uint256 typeOfId = DATASTORE.readUintForId(id, "TYPE");
    require(typeOfId == ID_TYPE.OPERATOR || typeOfId == ID_TYPE.POOL, "SU: invalid TYPE");

    _setMaintainer(DATASTORE, id, newMaintainer);
  }

  /**
   * @notice                                     ** MAINTENANCE FEE **
   */

  /**
   * @dev  ->  view
   */

  /**
   * @notice Gets fee as a percentage, PERCENTAGE_DENOMINATOR = 100%
   * @return fee = percentage * PERCENTAGE_DENOMINATOR / 100
   */
  function getMaintenanceFee(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id
  ) public view returns (uint256 fee) {
    if (DATASTORE.readUintForId(id, "feeSwitch") > block.timestamp) {
      return DATASTORE.readUintForId(id, "priorFee");
    }
    return DATASTORE.readUintForId(id, "fee");
  }

  /**
   * @dev  ->  internal
   */

  /**
   * @notice  internal function to set fee with NO DELAY
   */
  function _setMaintenanceFee(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 _id,
    uint256 _newFee
  ) internal {
    require(_newFee <= MAX_MAINTENANCE_FEE, "SU: > MAX_MAINTENANCE_FEE ");
    DATASTORE.writeUintForId(_id, "fee", _newFee);
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice Changes the fee that is applied to the newly created validators, with A DELAY OF SWITCH_LATENCY.
   * Note Can NOT be called again while its currently switching.
   * @dev advise that 100% == PERCENTAGE_DENOMINATOR
   */
  function switchMaintenanceFee(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id,
    uint256 newFee
  ) external {
    authenticate(DATASTORE, id, true, false, [true, true]);

    require(
      block.timestamp > DATASTORE.readUintForId(id, "feeSwitch"),
      "SU: fee is currently switching"
    );

    DATASTORE.writeUintForId(id, "priorFee", DATASTORE.readUintForId(id, "fee"));
    DATASTORE.writeUintForId(id, "feeSwitch", block.timestamp + SWITCH_LATENCY);

    _setMaintenanceFee(DATASTORE, id, newFee);

    emit FeeSwitched(id, newFee, block.timestamp + SWITCH_LATENCY);
  }

  /**
   * @notice                                     ** INTERNAL WALLET **
   *
   * Internal wallet of an ID accrues fees over time.
   * It is also used by Node Operators to fund 1 ETH per validator proposal, which is reimbursed if/when activated.
   */

  /**
   * @dev  ->  internal
   */

  /**
   * @notice Simply increases the balance of an IDs Maintainer wallet
   * @param _value Ether (in Wei) amount to increase the wallet balance.
   * @return success if the amount was deducted
   */
  function _increaseWalletBalance(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 _id,
    uint256 _value
  ) internal returns (bool success) {
    DATASTORE.addUintForId(_id, "wallet", _value);
    return true;
  }

  /**
   * @notice To decrease the balance of an Operator's wallet internally
   * @param _value Ether (in Wei) amount to decrease the wallet balance and send back to Maintainer.
   */
  function _decreaseWalletBalance(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 _id,
    uint256 _value
  ) internal returns (bool success) {
    require(DATASTORE.readUintForId(_id, "wallet") >= _value, "SU: NOT enough funds in wallet");
    DATASTORE.subUintForId(_id, "wallet", _value);
    return true;
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice external function to increase the internal wallet balance
   * @dev anyone can increase the balance directly, useful for withdrawalContracts and fees etc.
   */
  function increaseWalletBalance(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id
  ) external returns (bool success) {
    authenticate(DATASTORE, id, false, false, [true, true]);
    return _increaseWalletBalance(DATASTORE, id, msg.value);
  }

  /**
   * @notice external function to decrease the internal wallet balance
   * @dev only CONTROLLER can decrease the balance externally,
   * @return success if the amount was sent and deducted
   */
  function decreaseWalletBalance(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id,
    uint256 value
  ) external returns (bool success) {
    authenticate(DATASTORE, id, true, false, [true, true]);

    require(address(this).balance >= value, "SU: not enough funds in Portal ?");

    bool decreased = _decreaseWalletBalance(DATASTORE, id, value);
    address controller = DATASTORE.readAddressForId(id, "CONTROLLER");

    (bool sent, ) = payable(controller).call{value: value}("");
    require(decreased && sent, "SU: Failed to send ETH");
    return sent;
  }

  /**
   * @notice                                     ** PRISON **
   *
   * When node operators act in a malicious way, which can also be interpereted as
   * an honest mistake like using a faulty signature, Oracle imprisons the operator.
   * These conditions are:
   * * 1. Created a malicious validator(alien): faulty withdrawal credential, faulty signatures etc.
   * * 2. Have not respect the validatorPeriod
   * * 3. Stole block fees or MEV boost rewards from the pool
   */

  /**
   * @dev  ->  view
   */

  /**
   * @notice Checks if the given operator is Prisoned
   * @dev "released" key refers to the end of the last imprisonment, when the limitations of operator is lifted
   */
  function isPrisoned(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 _operatorId
  ) public view returns (bool) {
    return (block.timestamp < DATASTORE.readUintForId(_operatorId, "released"));
  }

  /**
   * @dev  ->  internal
   */

  /**
   * @notice Put an operator in prison
   * @dev "released" key refers to the end of the last imprisonment, when the limitations of operator is lifted
   */
  function _imprison(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 _operatorId,
    bytes calldata proof
  ) internal {
    authenticate(DATASTORE, _operatorId, false, false, [true, false]);

    DATASTORE.writeUintForId(_operatorId, "released", block.timestamp + PRISON_SENTENCE);

    emit Prisoned(_operatorId, proof, block.timestamp + PRISON_SENTENCE);
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice allows imprisoning an Operator if the validator have not been exited until expectedExit
   * @dev anyone can call this function
   * @dev if operator has given enough allowance, they SHOULD rotate the validators to avoid being prisoned
   */
  function blameOperator(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    bytes calldata pk
  ) external {
    require(
      self._validators[pk].state == VALIDATOR_STATE.ACTIVE,
      "SU: validator is never activated"
    );
    require(block.timestamp > self._validators[pk].expectedExit, "SU: validator is active");

    _imprison(DATASTORE, self._validators[pk].operatorId, pk);
  }

  /**
   * @notice                                     ** OPERATOR FUNCTIONS **
   */

  /**
   * @dev  ->  internal
   */

  /**
   * @notice internal function to set validator period with NO DELAY
   */
  function _setValidatorPeriod(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 _operatorId,
    uint256 _newPeriod
  ) internal {
    require(_newPeriod >= MIN_VALIDATOR_PERIOD, "SU: < MIN_VALIDATOR_PERIOD");
    require(_newPeriod <= MAX_VALIDATOR_PERIOD, "SU: > MAX_VALIDATOR_PERIOD");

    DATASTORE.writeUintForId(_operatorId, "validatorPeriod", _newPeriod);
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice updates validatorPeriod for given operator, with A DELAY OF SWITCH_LATENCY.
   * @dev limited by MIN_VALIDATOR_PERIOD and MAX_VALIDATOR_PERIOD
   */
  function switchValidatorPeriod(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 operatorId,
    uint256 newPeriod
  ) external {
    authenticate(DATASTORE, operatorId, false, true, [true, false]);

    require(
      block.timestamp > DATASTORE.readUintForId(operatorId, "periodSwitch"),
      "SU: period is currently switching"
    );

    DATASTORE.writeUintForId(
      operatorId,
      "priorPeriod",
      DATASTORE.readUintForId(operatorId, "validatorPeriod")
    );
    DATASTORE.writeUintForId(operatorId, "periodSwitch", block.timestamp + SWITCH_LATENCY);

    _setValidatorPeriod(DATASTORE, operatorId, newPeriod);

    emit ValidatorPeriodSwitched(operatorId, newPeriod, block.timestamp + SWITCH_LATENCY);
  }

  /**
   * @notice                                     ** OPERATOR MARKETPLACE **
   */

  /**
   * @dev  ->  view
   */

  /** *
   * @notice operatorAllowance is the maximum number of validators that the given Operator is allowed to create on behalf of the Pool
   * @dev an operator can not create new validators if:
   * * 1. allowance is 0 (zero)
   * * 2. lower than the current (proposed + active) number of validators
   * * But if operator withdraws a validator, then able to create a new one.
   * @dev prestake checks the approved validator count to make sure the number of validators are not bigger than allowance
   * @dev allowance doesn't change when new validators created or old ones are unstaked.
   */
  function operatorAllowance(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 operatorId
  ) internal view returns (uint256 allowance) {
    allowance = DATASTORE.readUintForId(poolId, DSU.getKey(operatorId, "allowance"));
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice To allow a Node Operator run validators for your Pool with a given number of validators.
   * * This number can be set again at any given point in the future.
   * @param poolId the gETH id of the Pool
   * @param operatorIds array of Operator IDs to allow them create validators
   * @param allowances the MAX number of validators that can be created by the Operator, for given Pool
   * @dev When decreased the approved validator count below current active+proposed validators,
   * operator can NOT create new validators.
   */
  function batchApproveOperators(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256[] calldata operatorIds,
    uint256[] calldata allowances
  ) external returns (bool) {
    authenticate(DATASTORE, poolId, true, true, [false, true]);

    require(operatorIds.length == allowances.length, "SU: allowances should match");

    for (uint256 i = 0; i < operatorIds.length; ) {
      authenticate(DATASTORE, operatorIds[i], false, false, [true, false]);

      DATASTORE.writeUintForId(poolId, DSU.getKey(operatorIds[i], "allowance"), allowances[i]);

      emit OperatorApproval(poolId, operatorIds[i], allowances[i]);

      unchecked {
        i += 1;
      }
    }
    return true;
  }

  /**
   * @notice                                     ** POOL HELPERS **
   */

  /**
   * @dev  ->  view
   */

  /**
   * @notice returns WithdrawalContract as a contract
   */
  function withdrawalContractById(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId
  ) public view returns (IWithdrawalContract) {
    return IWithdrawalContract(DATASTORE.readAddressForId(poolId, "withdrawalContract"));
  }

  /**
   * @notice returns liquidityPool as a contract
   */
  function liquidityPoolById(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 _poolId
  ) public view returns (ISwap) {
    return ISwap(DATASTORE.readAddressForId(_poolId, "liquidityPool"));
  }

  /**
   * @notice checks if the Whitelist allows staker to use given private pool
   * @dev Owner of the pool doesn't need whitelisting
   * @dev Otherwise requires a whitelisting address to be set
   */
  function isWhitelisted(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    address staker
  ) internal view returns (bool) {
    if (DATASTORE.readAddressForId(poolId, "CONTROLLER") == msg.sender) {
      return true;
    }

    address whitelist = DATASTORE.readAddressForId(poolId, "whitelist");
    require(whitelist != address(0), "SU: no whitelist");

    return IWhitelist(whitelist).isAllowed(staker);
  }

  /**
   * @notice returns true if the price is valid:
   * - last price syncinc happened less than 24h
   * - there has been no oracle reports since the last update
   *
   * @dev known bug / feature: if there have been no oracle updates,
   * * this function will return true.
   *
   * lastupdate + PRICE_EXPIRY >= block.timestamp ? true
   *    : lastupdate >= self.ORACLE_UPDATE_TIMESTAMP ? true
   *    : false
   */
  function isPriceValid(
    PooledStaking storage self,
    uint256 poolId
  ) public view returns (bool isValid) {
    uint256 lastupdate = self.gETH.priceUpdateTimestamp(poolId);
    unchecked {
      isValid =
        lastupdate + PRICE_EXPIRY >= block.timestamp ||
        lastupdate >= self.ORACLE_UPDATE_TIMESTAMP;
    }
  }

  /**
   * @notice checks if staking is allowed in given staking pool
   * @notice staking is not allowed if:
   * 1. Price is not valid
   * 2. WithdrawalContract is in Recovery Mode, can have many reasons
   */
  function isMintingAllowed(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId
  ) public view returns (bool) {
    return
      (isPriceValid(self, poolId)) && !(withdrawalContractById(DATASTORE, poolId).recoveryMode());
  }

  /**
   * @notice                                     ** POOLING OPERATIONS **
   */

  /**
   * @dev  ->  internal
   */

  /**
   * @notice mints gETH for a given ETH amount, keeps the tokens in Portal.
   * @dev fails if the price if minting is not allowed
   */
  function _mintgETH(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 ethAmount
  ) internal returns (uint256 mintedgETH) {
    require(isMintingAllowed(self, DATASTORE, poolId), "SU: minting is not allowed");

    mintedgETH = (((ethAmount * self.gETH.denominator()) / self.gETH.pricePerShare(poolId)));
    self.gETH.mint(address(this), poolId, mintedgETH, "");
    DATASTORE.addUintForId(poolId, "surplus", ethAmount);
  }

  /**
   * @notice conducts a buyback using the given liquidity pool
   * @param poolId id of the gETH that will be bought
   * @param sellEth ETH amount to sell
   * @param minToBuy TX is expected to revert by Swap.sol if not meet
   * @param deadline TX is expected to revert by Swap.sol if not meet
   * @dev this function assumes that pool is deployed by deployLiquidityPool
   * as index 0 is ETH and index 1 is gETH!
   */
  function _buyback(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 sellEth,
    uint256 minToBuy,
    uint256 deadline
  ) internal returns (uint256 outAmount) {
    // SWAP in LP
    outAmount = liquidityPoolById(DATASTORE, poolId).swap{value: sellEth}(
      0,
      1,
      sellEth,
      minToBuy,
      deadline
    );
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice Allowing users to deposit into a staking pool.
   * @notice If a pool is not public only the maintainer can deposit.
   * @param poolId id of the staking pool, liquidity pool and gETH to be used.
   * @param mingETH liquidity pool parameter
   * @param deadline liquidity pool parameter
   * @dev an example for minting + buybacks
   * * Buys from DWP if price is low -debt-, mints new tokens if surplus is sent -more than debt-
   * // debt  msgValue
   * // 100   10  => buyback
   * // 100   100 => buyback
   * // 10    100 => buyback + mint
   * // 1     x   => mint
   * // 0.5   x   => mint
   * // 0     x   => mint
   */
  function deposit(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 mingETH,
    uint256 deadline,
    address receiver
  ) external returns (uint256 boughtgETH, uint256 mintedgETH) {
    authenticate(DATASTORE, poolId, false, false, [false, true]);
    require(deadline > block.timestamp, "SU: deadline not met");
    require(receiver != address(0), "SU: receiver is zero address");

    if (isPrivatePool(DATASTORE, poolId)) {
      require(isWhitelisted(DATASTORE, poolId, msg.sender), "SU: sender NOT whitelisted");
    }

    uint256 remEth = msg.value;

    if (DATASTORE.readAddressForId(poolId, "liquidityPool") != address(0)) {
      uint256 debt = liquidityPoolById(DATASTORE, poolId).getDebt();
      if (debt > IGNORABLE_DEBT) {
        if (debt < remEth) {
          boughtgETH = _buyback(DATASTORE, poolId, debt, 0, deadline);
          remEth -= debt;
        } else {
          boughtgETH = _buyback(DATASTORE, poolId, remEth, 0, deadline);
          remEth = 0;
        }
      }
    }

    if (remEth > 0) {
      mintedgETH = _mintgETH(self, DATASTORE, poolId, remEth);
    }
    require(boughtgETH + mintedgETH >= mingETH, "SU: less than minimum");

    // send back to user
    self.gETH.safeTransferFrom(address(this), receiver, poolId, boughtgETH + mintedgETH, "");

    emit Deposit(poolId, boughtgETH, mintedgETH);
  }

  /**
   * @notice                                     ** VALIDATOR OPERATIONS **
   *
   * Creation of a Validator takes 2 steps: propose and beacon stake.
   * Before entering beaconStake function, _canStake verifies the eligibility of
   * given pubKey that is proposed by an operator with proposeStake function.
   * Eligibility is defined by an optimistic alienation, check alienate() for info.
   */

  /**
   * @dev  ->  view
   */

  /**
   * @notice internal function to check if a validator can use the pool funds
   *
   *  @param pubkey BLS12-381 public key of the validator
   *  @return true if:
   *   - pubkey should be proposed
   *   - pubkey should not be alienated (https://bit.ly/3Tkc6UC)
   *   - validator's index should be lower than VERIFICATION_INDEX. Updated by Telescope.
   * Note: while distributing the rewards, if a validator has 1 Eth, it is safe to assume that the balance belongs to Operator
   */
  function _canStake(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    bytes calldata pubkey,
    uint256 verificationIndex
  ) internal view returns (bool) {
    return
      (self._validators[pubkey].state == VALIDATOR_STATE.PROPOSED) &&
      (self._validators[pubkey].index <= verificationIndex) &&
      !(withdrawalContractById(DATASTORE, self._validators[pubkey].poolId).recoveryMode());
  }

  /**
   * @notice external function to check if a validator can use the pool funds
   */
  function canStake(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    bytes calldata pubkey
  ) external view returns (bool) {
    return _canStake(self, DATASTORE, pubkey, self.VERIFICATION_INDEX);
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice Helper Struct to pack constant data that does not change per validator.
   * * needed for that famous Solidity feature.
   */
  struct constantValidatorData {
    uint256 index;
    uint256 poolFee;
    uint256 operatorFee;
    uint256 earlyExitFee;
    uint256 expectedExit;
    bytes withdrawalCredential;
  }

  /**
   * @notice Validator Credentials Proposal function, first step of crating validators.
   * * Once a pubKey is proposed and not alienated after verificationIndex updated,
   * * it is optimistically allowed to take funds from staking pools.
   *
   * @param poolId the id of the staking pool
   * @param operatorId the id of the Operator whose maintainer calling this function
   * @param pubkeys  Array of BLS12-381 public keys of the validators that will be proposed
   * @param signatures1 Array of BLS12-381 signatures that will be used to send 1 ETH from the Operator's
   * maintainer balance
   * @param signatures31 Array of BLS12-381 signatures that will be used to send 31 ETH from pool on beaconStake
   *
   * @dev DCU.DEPOSIT_AMOUNT_PRESTAKE = 1 ether, DCU.DEPOSIT_AMOUNT = 32 ether which is the minimum amount to create a validator.
   * 31 Ether will be staked after verification of oracles. 32 in total.
   * 1 ether will be sent back to Node Operator when the finalized deposit is successful.
   * @dev ProposeStake requires enough allowance from Staking Pools to Operators.
   * @dev ProposeStake requires enough funds within Wallet.
   * @dev Max number of validators to propose is per call is MAX_DEPOSITS_PER_CALL (currently 64)
   */
  function proposeStake(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 operatorId,
    bytes[] calldata pubkeys,
    bytes[] calldata signatures1,
    bytes[] calldata signatures31
  ) external {
    // checks and effects
    authenticate(DATASTORE, operatorId, true, true, [true, false]);
    authenticate(DATASTORE, poolId, false, false, [false, true]);
    {
      uint256 pkLen = pubkeys.length;

      require((pkLen > 0) && (pkLen <= DCU.MAX_DEPOSITS_PER_CALL), "SU: 0 - 50 validators");
      require(pkLen == signatures1.length, "SU: invalid signatures1 length");
      require(pkLen == signatures31.length, "SU: invalid signatures31 length");

      unchecked {
        require(
          (DATASTORE.readUintForId(operatorId, "totalActiveValidators") +
            DATASTORE.readUintForId(operatorId, "totalProposedValidators") +
            pkLen) <= self.MONOPOLY_THRESHOLD,
          "SU: IceBear does NOT like monopolies"
        );

        require(
          (DATASTORE.readUintForId(poolId, DSU.getKey(operatorId, "proposedValidators")) +
            DATASTORE.readUintForId(poolId, DSU.getKey(operatorId, "activeValidators")) +
            pkLen) <= operatorAllowance(DATASTORE, poolId, operatorId),
          "SU: NOT enough allowance"
        );

        require(
          DATASTORE.readUintForId(poolId, "surplus") >= DCU.DEPOSIT_AMOUNT * pkLen,
          "SU: NOT enough surplus"
        );
      }

      _decreaseWalletBalance(DATASTORE, operatorId, (pkLen * DCU.DEPOSIT_AMOUNT_PRESTAKE));

      DATASTORE.subUintForId(poolId, "surplus", (pkLen * DCU.DEPOSIT_AMOUNT));
      DATASTORE.addUintForId(poolId, "secured", (pkLen * DCU.DEPOSIT_AMOUNT));
      DATASTORE.addUintForId(poolId, DSU.getKey(operatorId, "proposedValidators"), pkLen);
      DATASTORE.addUintForId(operatorId, "totalProposedValidators", pkLen);
    }

    constantValidatorData memory valData = constantValidatorData({
      index: self.VALIDATORS_INDEX + 1,
      poolFee: getMaintenanceFee(DATASTORE, poolId),
      operatorFee: getMaintenanceFee(DATASTORE, operatorId),
      earlyExitFee: self.EARLY_EXIT_FEE,
      expectedExit: block.timestamp + DATASTORE.readUintForId(operatorId, "validatorPeriod"),
      withdrawalCredential: DATASTORE.readBytesForId(poolId, "withdrawalCredential")
    });

    for (uint256 i; i < pubkeys.length; ) {
      require(pubkeys[i].length == DCU.PUBKEY_LENGTH, "SU: PUBKEY_LENGTH ERROR");
      require(signatures1[i].length == DCU.SIGNATURE_LENGTH, "SU: SIGNATURE_LENGTH ERROR");
      require(signatures31[i].length == DCU.SIGNATURE_LENGTH, "SU: SIGNATURE_LENGTH ERROR");
      require(
        self._validators[pubkeys[i]].state == VALIDATOR_STATE.NONE,
        "SU: Pubkey already used or alienated"
      );

      self._validators[pubkeys[i]] = Validator(
        1,
        valData.index + i,
        poolId,
        operatorId,
        valData.poolFee,
        valData.operatorFee,
        valData.earlyExitFee,
        block.timestamp,
        valData.expectedExit,
        signatures31[i]
      );

      DCU.depositValidator(
        pubkeys[i],
        valData.withdrawalCredential,
        signatures1[i],
        DCU.DEPOSIT_AMOUNT_PRESTAKE
      );

      unchecked {
        i += 1;
      }
    }

    self.VALIDATORS_INDEX += pubkeys.length;

    emit ProposalStaked(poolId, operatorId, pubkeys);
  }

  /**
   *  @notice Sends 31 Eth from staking pool to validators that are previously created with ProposeStake.
   *  1 Eth per successful validator boostraping is returned back to Wallet.
   *
   *  @param operatorId the id of the Operator whose maintainer calling this function
   *  @param pubkeys  Array of BLS12-381 public keys of the validators that are already proposed with ProposeStake.
   *
   *  @dev To save gas cost, pubkeys should be arranged by poolIds.
   *  ex: [pk1, pk2, pk3, pk4, pk5, pk6, pk7]
   *  pk1, pk2, pk3 from pool1
   *  pk4, pk5 from pool2
   *  pk6 from pool3
   *  seperate them in similar groups as much as possible.
   *  @dev Max number of validators to boostrap is MAX_DEPOSITS_PER_CALL (currently 64)
   *  @dev A pubkey that is alienated will not get through. Do not frontrun during ProposeStake.
   */
  function beaconStake(
    PooledStaking storage self,
    DSU.IsolatedStorage storage DATASTORE,
    uint256 operatorId,
    bytes[] calldata pubkeys
  ) external {
    authenticate(DATASTORE, operatorId, true, true, [true, false]);

    require(
      (pubkeys.length > 0) && (pubkeys.length <= DCU.MAX_DEPOSITS_PER_CALL),
      "SU: 0 - 50 validators"
    );

    {
      uint256 verificationIndex = self.VERIFICATION_INDEX;
      for (uint256 j; j < pubkeys.length; ) {
        require(
          _canStake(self, DATASTORE, pubkeys[j], verificationIndex),
          "SU: NOT all pubkeys are stakeable"
        );
        unchecked {
          j += 1;
        }
      }
    }

    {
      bytes32 activeValKey = DSU.getKey(operatorId, "activeValidators");
      bytes32 proposedValKey = DSU.getKey(operatorId, "proposedValidators");
      uint256 poolId = self._validators[pubkeys[0]].poolId;
      bytes memory withdrawalCredential = DATASTORE.readBytesForId(poolId, "withdrawalCredential");

      uint256 lastIdChange;
      for (uint256 i; i < pubkeys.length; ) {
        if (poolId != self._validators[pubkeys[i]].poolId) {
          uint256 sinceLastIdChange;

          unchecked {
            sinceLastIdChange = i - lastIdChange;
          }

          DATASTORE.subUintForId(poolId, "secured", (DCU.DEPOSIT_AMOUNT * (sinceLastIdChange)));
          DATASTORE.addUintForId(poolId, activeValKey, (sinceLastIdChange));
          DATASTORE.subUintForId(poolId, proposedValKey, (sinceLastIdChange));

          poolId = self._validators[pubkeys[i]].poolId;
          withdrawalCredential = DATASTORE.readBytesForId(poolId, "withdrawalCredential");
          lastIdChange = i;
        }

        bytes memory signature = self._validators[pubkeys[i]].signature31;

        DCU.depositValidator(
          pubkeys[i],
          withdrawalCredential,
          signature,
          DCU.DEPOSIT_AMOUNT - DCU.DEPOSIT_AMOUNT_PRESTAKE
        );

        DATASTORE.appendBytesArrayForId(poolId, "validators", pubkeys[i]);
        self._validators[pubkeys[i]].state = VALIDATOR_STATE.ACTIVE;

        unchecked {
          i += 1;
        }
      }
      {
        uint256 sinceLastIdChange;
        unchecked {
          sinceLastIdChange = pubkeys.length - lastIdChange;
        }

        DATASTORE.subUintForId(poolId, "secured", DCU.DEPOSIT_AMOUNT * (sinceLastIdChange));
        DATASTORE.addUintForId(poolId, activeValKey, (sinceLastIdChange));
        DATASTORE.subUintForId(poolId, proposedValKey, (sinceLastIdChange));
        DATASTORE.addUintForId(operatorId, "totalActiveValidators", pubkeys.length);
        DATASTORE.subUintForId(operatorId, "totalProposedValidators", pubkeys.length);

        _increaseWalletBalance(DATASTORE, operatorId, DCU.DEPOSIT_AMOUNT_PRESTAKE * pubkeys.length);
      }
      emit BeaconStaked(pubkeys);
    }
  }
}
