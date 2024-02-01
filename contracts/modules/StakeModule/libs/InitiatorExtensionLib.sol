// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// external - contracts
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// internal - globals
import {ID_TYPE} from "../../../globals/id_type.sol";
import {RESERVED_KEY_SPACE as rks} from "../../../globals/reserved_key_space.sol";
// internal - interfaces
import {IgETHMiddleware} from "../../../interfaces/middlewares/IgETHMiddleware.sol";
import {IGeodePackage} from "../../../interfaces/packages/IGeodePackage.sol";
// internal - structs
import {DataStoreModuleStorage} from "../../DataStoreModule/structs/storage.sol";
import {StakeModuleStorage} from "../structs/storage.sol";
// internal - libraries
import {DataStoreModuleLib as DSML} from "../../DataStoreModule/libs/DataStoreModuleLib.sol";
import {DepositContractLib as DCL} from "./DepositContractLib.sol";
import {StakeModuleLib as SML} from "./StakeModuleLib.sol";

/**
 * @title IEL: Initiator Extension Library
 *
 * @notice An extension to SML.
 * @notice This library is responsible from:
 * * 1. Node Operator Initiator for permissioned IDs
 * * 2. Configurable Staking Pools Initiator and its helpers.
 * * 3. Bound Liquidity Pool deployment after pool initiation.
 *
 * @dev review: DataStoreModule for the id based isolated storage logic.
 * @dev review: StakeModuleLib for base staking logic.
 *
 * @dev This library utilizes the '_authenticate' function on the external deployLiquidityPool,
 *  Compared to gETHMiddleware(optional) and WithdrawalContract(mandatory), LP be activated after
 * the pool initiation.
 *
 * @dev This is an external library, requires deployment.
 *
 * @author Ice Bear & Crash Bandicoot
 */

library InitiatorExtensionLib {
  using DSML for DataStoreModuleStorage;
  using SML for StakeModuleStorage;

  /**
   * @custom:section                           ** EVENTS **
   */
  event InitiationDepositSet(uint256 initiationDeposit);
  event IdInitiated(uint256 id, uint256 indexed TYPE);
  event MiddlewareDeployed(uint256 poolId, uint256 version);
  event PackageDeployed(uint256 poolId, uint256 packageType, address instance);

  /**
   * @custom:section                           ** GOVERNING **
   *
   * @custom:visibility -> external
   * @dev IMPORTANT! These functions should be governed by a governance! Which is not done here!
   */

  /**
   * @notice Set the required amount for a pool initiation.
   * @dev note that, could have been used to prevent pool creation if there were no limits.
   */
  function setInitiationDeposit(
    StakeModuleStorage storage self,
    uint256 initiationDeposit
  ) external {
    require(initiationDeposit <= DCL.DEPOSIT_AMOUNT);

    self.INITIATION_DEPOSIT = initiationDeposit;

    emit InitiationDepositSet(initiationDeposit);
  }

  /**
   * @custom:section                           ** OPERATOR INITIATOR **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice initiates ID as a Permissionned Node Operator
   * @notice requires ID to be approved as a node operator with a specific CONTROLLER
   * @param fee as a percentage limited by MAX_MAINTENANCE_FEE, PERCENTAGE_DENOMINATOR represents 100%
   * @param validatorPeriod the expected maximum staking interval. This value should between
   * * MIN_VALIDATOR_PERIOD and MAX_VALIDATOR_PERIOD values defined as constants above.
   * Operator can unstake at any given point before this period ends.
   * If operator disobeys this rule, it can be prisoned with blameProposal()
   * @param maintainer an address that automates daily operations, a script, a contract...
   * @dev operators can fund their internal wallet on initiation by simply sending some ether.
   */
  function initiateOperator(
    DataStoreModuleStorage storage DATASTORE,
    uint256 id,
    uint256 fee,
    uint256 validatorPeriod,
    address maintainer
  ) external {
    require(DATASTORE.readUint(id, rks.initiated) == 0, "SML:already initiated");
    require(DATASTORE.readUint(id, rks.TYPE) == ID_TYPE.OPERATOR, "SML:TYPE not allowed");
    require(msg.sender == DATASTORE.readAddress(id, rks.CONTROLLER), "SML:sender not CONTROLLER");

    DATASTORE.writeUint(id, rks.initiated, block.timestamp);

    SML._setMaintenanceFee(DATASTORE, id, fee);
    SML._setValidatorPeriod(DATASTORE, id, validatorPeriod);
    SML._setMaintainer(DATASTORE, id, maintainer);
    SML._increaseWalletBalance(DATASTORE, id, msg.value);

    emit IdInitiated(id, ID_TYPE.OPERATOR);
  }

  /**
   * @custom:section                           ** STAKING POOL INITIATOR **
   *
   * @dev this section also contains the helper functions for packages and middlewares.
   */

  /**
   * @notice Creates a Configurable Trustless Staking Pool!
   * @param fee as a percentage limited by MAX_MAINTENANCE_FEE, PERCENTAGE_DENOMINATOR is 100%
   * @param middlewareVersion Pool creators can choose any allowed version as their gETHMiddleware
   * @param maintainer an address that automates daily operations, a script, a contract... not so critical.
   * @param name is utilized while generating an ID for the Pool, similar to any other ID generation.
   * @param middleware_data middlewares might require additional data on initialization; like name, symbol, etc.
   * @param config array(3)= [private(true) or public(false), deploy a middleware(if true), deploy liquidity pool(if true)]
   * @dev checking only initiated is enough to validate that ID is not used. no need to check TYPE, CONTROLLER etc.
   * @dev requires INITIATION_DEPOSIT worth of funds (currently 1 validator) to be deposited on initiation, prevent sybil attacks.
   */
  function initiatePool(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 fee,
    uint256 middlewareVersion,
    address maintainer,
    bytes calldata name,
    bytes calldata middleware_data,
    bool[3] calldata config
  ) external returns (uint256 poolId) {
    require(msg.value == self.INITIATION_DEPOSIT, "SML:need 1 validator worth of funds");

    poolId = DSML.generateId(name, ID_TYPE.POOL);
    require(DATASTORE.readUint(poolId, rks.initiated) == 0, "SML:already initiated");
    require(poolId > 1e9, "SML:Wow! Low poolId");

    DATASTORE.writeUint(poolId, rks.initiated, block.timestamp);

    DATASTORE.writeUint(poolId, rks.TYPE, ID_TYPE.POOL);
    DATASTORE.writeAddress(poolId, rks.CONTROLLER, msg.sender);
    DATASTORE.writeBytes(poolId, rks.NAME, name);
    DATASTORE.allIdsByType[ID_TYPE.POOL].push(poolId);

    SML._setMaintainer(DATASTORE, poolId, maintainer);
    SML._setMaintenanceFee(DATASTORE, poolId, fee);

    // deploy a withdrawal Contract - mandatory
    _deployWithdrawalContract(self, DATASTORE, poolId);

    if (config[0]) {
      // set pool to private
      SML.setPoolVisibility(DATASTORE, poolId, true);
    }
    if (config[1]) {
      // deploy a gETH middleware(erc20 etc.) - optional
      _deploygETHMiddleware(self, DATASTORE, poolId, middlewareVersion, middleware_data);
    }
    if (config[2]) {
      // deploy a bound liquidity pool - optional
      _deployLiquidityPool(self, DATASTORE, poolId);
    }

    // initially 1 ETHER = 1 ETHER
    self.gETH.setPricePerShare(1 ether, poolId);

    // mint gETH and send back to the caller
    uint256 mintedgETH = SML._mintgETH(self, DATASTORE, poolId, msg.value);
    self.gETH.safeTransferFrom(address(this), msg.sender, poolId, mintedgETH, "");

    emit IdInitiated(poolId, ID_TYPE.POOL);
  }

  /**
   * @custom:section                           ** POOL INITIATOR HELPERS **
   */

  /**
   * @custom:subsection                        ** gETH MIDDLEWARES **
   *
   * @custom:visibility -> internal
   */

  /**
   * @notice internal function to set a gETHMiddleware
   * @param _middleware address of the new gETHMiddleware for given ID
   * @dev every middleware has a unique index within the middlewares dynamic array.
   * @dev if ever unset, SHOULD replace the implementation with address(0) for obvious security reasons.
   */
  function _setgETHMiddleware(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 id,
    address _middleware
  ) internal {
    require(!self.gETH.isMiddleware(_middleware, id), "SML:already middleware");

    DATASTORE.appendAddressArray(id, rks.middlewares, _middleware);

    self.gETH.setMiddleware(_middleware, id, true);
  }

  /**
   * @notice deploys a new gETHMiddleware by cloning (no upgradability)
   * @param _id gETH id, also required for IgETHMiddleware.initialize
   * @param _versionId provided version id, can use any as a middleware if allowed for TYPE = MIDDLEWARE_GETH
   * @param _middleware_data middlewares might require additional data on initialization; like name, symbol, etc.
   * @dev currrently, cannot deploy a middleware after initiation, thus only used by the initiator.
   * @dev currrently, cannot unset a middleware.
   */
  function _deploygETHMiddleware(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 _id,
    uint256 _versionId,
    bytes calldata _middleware_data
  ) internal {
    require(_versionId > 0, "SML:versionId cannot be 0");
    require(self.middlewares[ID_TYPE.MIDDLEWARE_GETH][_versionId], "SML:not a middleware");

    address newgETHMiddleware = Clones.clone(DATASTORE.readAddress(_versionId, rks.CONTROLLER));

    IgETHMiddleware(newgETHMiddleware).initialize(_id, address(self.gETH), _middleware_data);

    _setgETHMiddleware(self, DATASTORE, _id, newgETHMiddleware);

    // isolate the contract from middleware risk for ID
    self.gETH.avoidMiddlewares(_id, true);

    emit MiddlewareDeployed(_id, _versionId);
  }

  /**
   * @notice deploys a new package for given id with given type from packages mapping.
   * @param _type given package type
   * @param _poolId pool id, required for IGeodePackage.initialize
   * @param _package_data packages might require additional data on initialization
   * @dev no cloning because GeodePackages has Limited Upgradability (based on UUPS)
   */
  function _deployGeodePackage(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 _poolId,
    uint256 _type,
    bytes memory _package_data
  ) internal returns (address packageInstance) {
    uint256 versionId = self.packages[_type];
    require(versionId > 0, "SML:versionId cannot be 0");

    packageInstance = address(
      new ERC1967Proxy(DATASTORE.readAddress(versionId, rks.CONTROLLER), "")
    );
    // we don't call on deployment because initialize uses _getImplementation() which is not available
    IGeodePackage(packageInstance).initialize(
      _poolId,
      DATASTORE.readAddress(_poolId, rks.CONTROLLER),
      DATASTORE.readBytes(versionId, rks.NAME),
      _package_data
    );

    emit PackageDeployed(_poolId, _type, packageInstance);
  }

  /**
   * @custom:subsection                        ** WITHDRAWAL CONTRACT **
   *
   * @custom:visibility -> internal
   */

  /**
   * @notice Deploys a Withdrawal Contract that will be used as a withdrawal credential on validator creation
   * @dev every pool requires a Withdrawal Contract, thus this function is only used by the initiator
   */
  function _deployWithdrawalContract(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 _poolId
  ) internal {
    address wp = _deployGeodePackage(
      self,
      DATASTORE,
      _poolId,
      ID_TYPE.PACKAGE_WITHDRAWAL_CONTRACT,
      bytes("")
    );

    DATASTORE.writeAddress(_poolId, rks.withdrawalContract, wp);
    DATASTORE.writeBytes(_poolId, rks.withdrawalCredential, DCL.addressToWC(wp));
  }

  /**
   * @custom:subsection                        ** BOUND LIQUIDITY POOL **
   */

  /**
   * @custom:visibility -> internal
   */
  /**
   * @notice deploys a bound liquidity pool for a staking pool.
   * @dev gives full allowance to the pool (should not be a problem as Portal only temporarily holds gETH)
   * @dev unlike withdrawal Contract, a controller can deploy a liquidity pool after initiation as well
   * @dev _package_data of a liquidity pool is only the staking pool's name, used on LPToken.
   */
  function _deployLiquidityPool(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId
  ) internal {
    address lp = _deployGeodePackage(
      self,
      DATASTORE,
      poolId,
      ID_TYPE.PACKAGE_LIQUIDITY_POOL,
      DATASTORE.readBytes(poolId, rks.NAME)
    );

    DATASTORE.writeAddress(poolId, rks.liquidityPool, lp);
    // approve gETH so we can use it in buybacks
    self.gETH.setApprovalForAll(lp, true);
  }

  /**
   * @custom:visibility -> external
   */
  /**
   * @notice allows pools to deploy a Liquidity Pool after initiation, if it does not have one.
   */
  function deployLiquidityPool(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId
  ) public {
    SML._authenticate(DATASTORE, poolId, true, false, [false, true]);
    require(DATASTORE.readAddress(poolId, rks.liquidityPool) == address(0), "SML:already deployed");

    _deployLiquidityPool(self, DATASTORE, poolId);
  }
}
