// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

// internal - globals
import {ID_TYPE} from "../../../globals/id_type.sol";
import {PERCENTAGE_DENOMINATOR, gETH_DENOMINATOR} from "../../../globals/macros.sol";
import {VALIDATOR_STATE} from "../../../globals/validator_state.sol";
import {RESERVED_KEY_SPACE as rks} from "../../../globals/reserved_key_space.sol";
// internal - interfaces
import {IgETH} from "../../../interfaces/IgETH.sol";
import {IGeodePackage} from "../../../interfaces/packages/IGeodePackage.sol";
import {ILiquidityPool} from "../../../interfaces/packages/ILiquidityPool.sol";
import {IWhitelist} from "../../../interfaces/helpers/IWhitelist.sol";
// internal - structs
import {DataStoreModuleStorage} from "../../DataStoreModule/structs/storage.sol";
import {StakeModuleStorage} from "../structs/storage.sol";
import {ConstantValidatorData} from "../structs/helpers.sol";
import {Validator} from "../structs/utils.sol";
// internal - libraries
import {DataStoreModuleLib as DSML} from "../../DataStoreModule/libs/DataStoreModuleLib.sol";
import {DepositContractLib as DCL} from "./DepositContractLib.sol";

/**
 * @title SML: Stake Module Library (The Staking Library)
 *
 * @notice Creating a global standard for Staking, allowing anyone to OWN a trustless staking pool,
 * improving the user experience for stakers and removing the "need" for centralized or decentralized intermediaries.
 * * Exclusively contains functions related to:
 * * 1. Pool and Operator management, after initiation (review IEL).
 * * 2. Validator Delegation.
 * * 3. Depositing.
 * * 4. Staking Operations.
 *
 * @dev review: DataStoreModule for the id based isolated storage logic.
 * @dev review: InitiatorExtensionLib for initiator functions.
 * @dev review: OracleExtensionLib for oracle logic.
 *
 * @dev Every pool is isolated and every validator is unique. We segregate all the risk.
 *
 * @dev CONTROLLER and Maintainer:
 * CONTROLLER is the owner of an ID, it manages the pool/operator. Its security is exteremely important.
 * maintainer is the worker, can be used to automate some daily tasks:
 * * distributing validators for Staking Pools or creating validators for Operators.
 * * not so crucial in terms of security.
 *
 * @dev Users:
 * Type 4 : Permissioned Operators
 * * Needs to be onboarded by the Dual Governance (Senate + Governance).
 * * Maintains Beacon Chain Validators on behalf of the Staking Pools.
 * * Can participate in the Operator Marketplace after initiation.
 * * Can utilize maintainers for staking operations.
 *
 * Type 5 : Permissionless Configurable Staking Pools
 * * Permissionless to create.
 * * Can utilize powers of packages and middlewares such as Bound Liquidity Pools, gETHMiddlewares etc.
 * * Can be public or private, can use a whitelist if private.
 * * Can utilize maintainers for validator distribution on Operator Marketplace.
 * * Uses a Withdrawal Contract to be given as withdrawalCredential on validator creation,
 * * accruing rewards and keeping Staked Ether safe and isolated.
 *
 * @dev Packages:
 * An ID can only point to one version of a Package at a time.
 * Built by utilizing the Modules!
 * Can be upgraded by a dual governance, via pullUpgrade.
 * * A Package's dual governance consists of Portal(governance) and the pool owner(senate).
 *
 * Type 10011 : Withdrawal Contract
 * * Mandatory.
 * * CONTROLLER is the implementation contract position (always)
 * * Version Release Requires the approval of Senate
 * * Upgrading to a new version is optional for pool owners.
 * * * Staking Pools are in "Isolation Mode" until their Withdrawal Contract is upgraded.
 * * * Meaning, no more Depositing or Validator Proposal can happen.
 * * Custodian of the validator funds after creation, including any type of rewards and fees.
 *
 * Type 10021 : Liquidity Pool implementation
 * * Optional.
 * * CONTROLLER is the implementation contract position (always)
 * * Version Release Requires the approval of Senate
 * * Upgrading to a new version is optional for pool owners.
 * * * Liquidity Pools are in "Isolation Mode" until upgraded.
 *
 * @dev Middlewares:
 * Can support many different versions that can be utilized by the Pool Owners.
 * No particular way to build one.
 * Cannot be upgraded.
 * Currently only gETHMiddlewares.
 *
 * Type 20011 : gETHMiddleware
 * * Optional.
 * * CONTROLLER is the implementation contract position (always)
 * * Requires the approval of Senate
 * * Currently should be utilized on initiation.
 *
 * @dev Contracts relying on this library must initialize StakeModuleLib.StakeModuleStorage
 *
 * @dev Functions are protected with authentication function
 *
 * @author Ice Bear & Crash Bandicoot
 */

library StakeModuleLib {
  using DSML for DataStoreModuleStorage;

  /**
   * @custom:section                           ** CONSTANTS **
   */

  /// @notice limiting the GOVERNANCE_FEE to 5%
  uint256 internal constant MAX_POOL_INFRASTRUCTURE_FEE = 5e8; // (PERCENTAGE_DENOMINATOR * 5) / 100;

  /// @notice limit the beacon delays on entry and exit since it can be adjusted by the governance.
  uint256 internal constant MAX_BEACON_DELAY = 90 days; // = MIN_VALIDATOR_PERIOD

  /// @notice limiting the pool and operator maintenance fee, 10%
  uint256 internal constant MAX_MAINTENANCE_FEE = 1e9; // (PERCENTAGE_DENOMINATOR * 10) / 100;

  /// @notice effective on allowance per operator, prevents overflow. Exclusive, save gas with +1.
  uint256 internal constant MAX_ALLOWANCE = 1e6;

  /// @notice price of gETH is only valid for 24H, minting is not allowed afterwards.
  uint256 internal constant PRICE_EXPIRY = 24 hours;

  /// @notice ignoring any buybacks if the Liquidity Pool has a low debt
  uint256 internal constant IGNORABLE_DEBT = 1 ether;

  /// @notice limiting the operator.validatorPeriod, between 3 months to 2 years
  uint256 internal constant MIN_VALIDATOR_PERIOD = 90 days; // 3 * 30 days
  uint256 internal constant MAX_VALIDATOR_PERIOD = 730 days; // 2 * 365 days

  /// @notice some parameter changes are effective after a delay
  uint256 internal constant SWITCH_LATENCY = 3 days;

  /**
   * @custom:section                           ** EVENTS **
   */
  event InfrastructureFeeSet(uint256 _type, uint256 fee);
  event BeaconDelaySet(uint256 entryDelay, uint256 exitDelay);
  event VisibilitySet(uint256 id, bool isPrivate);
  event YieldReceiverSet(uint256 indexed poolId, address yieldReceiver);
  event MaintainerChanged(uint256 indexed id, address newMaintainer);
  event FeeSwitched(uint256 indexed id, uint256 fee, uint256 effectiveAfter);
  event ValidatorPeriodSwitched(uint256 indexed operatorId, uint256 period, uint256 effectiveAfter);
  event Delegation(uint256 poolId, uint256 indexed operatorId, uint256 allowance);
  event FallbackOperator(uint256 poolId, uint256 indexed operatorId, uint256 threshold);
  event Deposit(uint256 indexed poolId, uint256 boughtgETH, uint256 mintedgETH);
  event StakeProposal(uint256 poolId, uint256 operatorId, bytes[] pubkeys);
  event Stake(bytes[] pubkeys);
  event ExitRequest(bytes pubkey);
  event Exit(bytes pubkey);

  /**
   * @custom:section                           ** GOVERNING **
   *
   * @custom:visibility -> external
   * @dev IMPORTANT! These functions should be governed by a governance! Which is not done here!
   */

  /**
   * @notice Set the maxiumum allowed beacon delay for blaming validators on creation and exit.
   * @dev high beacon delays will affect the ux negatively, low delays can cause issues for operators.
   */
  function setBeaconDelays(StakeModuleStorage storage self, uint256 entry, uint256 exit) external {
    require(entry < MAX_BEACON_DELAY, "SML:> MAX");
    require(exit < MAX_BEACON_DELAY, "SML:> MAX");

    self.BEACON_DELAY_ENTRY = entry;
    self.BEACON_DELAY_EXIT = exit;

    emit BeaconDelaySet(entry, exit);
  }

  /**
   * @notice Set a fee (denominated in PERCENTAGE_DENOMINATOR) for any given TYPE.
   * @dev Changing the Staking Pool fee, only applies to the newly created validators.
   * @dev advise that there can be other fees within the package, thus we will never allow
   * * governance to take more than x%, while x<80(at least). For now, 50% limit on all fees
   * * makes sense to us. However, it can be adjusted to any value between 0-80 in the future.
   */
  function setInfrastructureFee(
    StakeModuleStorage storage self,
    uint256 _type,
    uint256 fee
  ) external {
    if (_type == ID_TYPE.POOL) {
      require(fee <= MAX_POOL_INFRASTRUCTURE_FEE, "PORTAL:> MAX");
    } else {
      require(fee < PERCENTAGE_DENOMINATOR / 2, "SML:> 50%");
    }

    self.infrastructureFees[_type] = fee;
    emit InfrastructureFeeSet(_type, fee);
  }

  /**
   * @custom:section                           ** AUTHENTICATION **
   *
   * @custom:visibility -> view-internal
   */

  /**
   * @notice restricts the access to given function based on TYPE and msg.sender
   * @param _expectCONTROLLER restricts the access to only CONTROLLER.
   * @param _expectMaintainer restricts the access to only maintainer.
   * @param _restrictionMap Restricts which TYPEs can pass the authentication.
   * * [0: Operator = TYPE(4), 1: Pool = TYPE(5)]
   * @dev can only be used after an ID is initiated
   * @dev CONTROLLERS and maintainers of the Prisoned Operators cannot access.
   */
  function _authenticate(
    DataStoreModuleStorage storage DATASTORE,
    uint256 _id,
    bool _expectCONTROLLER,
    bool _expectMaintainer,
    bool[2] memory _restrictionMap
  ) internal view {
    require(DATASTORE.readUint(_id, rks.initiated) != 0, "SML:not initiated");

    uint256 typeOfId = DATASTORE.readUint(_id, rks.TYPE);

    if (typeOfId == ID_TYPE.OPERATOR) {
      require(_restrictionMap[0], "SML:TYPE not allowed");
      if (_expectCONTROLLER || _expectMaintainer) {
        require(!isPrisoned(DATASTORE, _id), "SML:prisoned, get in touch with governance");
      }
    } else if (typeOfId == ID_TYPE.POOL) {
      require(_restrictionMap[1], "SML:TYPE not allowed");
    } else {
      revert("SML:invalid TYPE");
    }

    if (_expectMaintainer) {
      require(
        msg.sender == DATASTORE.readAddress(_id, rks.maintainer),
        "SML:sender not maintainer"
      );
      return;
    }

    if (_expectCONTROLLER) {
      require(
        msg.sender == DATASTORE.readAddress(_id, rks.CONTROLLER),
        "SML:sender not CONTROLLER"
      );
      return;
    }
  }

  /**
   * @custom:subsection                           ** POOL VISIBILITY **
   */

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice changes the visibility of the pool
   * @param makePrivate true if pool should be private, false for public pools
   * @dev whitelist is cleared when pool is set to public, to prevent legacy bugs if ever made private again.
   * Note private pools can whitelist addresses with the help of a third party contract.
   */
  function setPoolVisibility(
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    bool makePrivate
  ) public {
    _authenticate(DATASTORE, poolId, true, false, [false, true]);
    require(makePrivate != isPrivatePool(DATASTORE, poolId), "SML:already set");

    DATASTORE.writeUint(poolId, rks.privatePool, makePrivate ? 1 : 0);

    if (!makePrivate) {
      DATASTORE.writeAddress(poolId, rks.whitelist, address(0));
    }

    emit VisibilitySet(poolId, makePrivate);
  }

  /**
   * @notice private pools can whitelist addresses with the help of a third party contract.
   * @dev Whitelisting contracts should implement IWhitelist interface.
   */
  function setWhitelist(
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    address whitelist
  ) external {
    _authenticate(DATASTORE, poolId, true, false, [false, true]);
    require(isPrivatePool(DATASTORE, poolId), "SML:must be private pool");

    DATASTORE.writeAddress(poolId, rks.whitelist, whitelist);
  }

  /**
   * @custom:visibility -> view-public
   */

  /**
   * @notice returns true if the pool is private
   */
  function isPrivatePool(
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId
  ) public view returns (bool) {
    return (DATASTORE.readUint(poolId, rks.privatePool) == 1);
  }

  /**
   * @notice checks if the Whitelist allows staker to use given private pool
   * @dev Owner of the pool doesn't need whitelisting
   * @dev Otherwise requires a whitelisting address to be set
   */
  function isWhitelisted(
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    address staker
  ) public view returns (bool) {
    if (DATASTORE.readAddress(poolId, rks.CONTROLLER) == staker) {
      return true;
    }

    address whitelist = DATASTORE.readAddress(poolId, rks.whitelist);
    if (whitelist == address(0)) {
      return false;
    }

    if (whitelist.code.length > 0) {
      try IWhitelist(whitelist).isAllowed(staker) returns (bool _isAllowed) {
        return _isAllowed;
      } catch {
        return false;
      }
    } else {
      return false;
    }
  }

  /**
   * @custom:section                           ** ID MANAGEMENT **
   *
   */

  /**
   * @custom:subsection                           ** YIELD SEPARATION **
   */

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice Set the yield receiver address to activate or deactivete yield separation logic.
   * * If set other than address(0) separation will be activated, if set back to address(0)
   * * separation will be deactivated again.
   * @param poolId the gETH id of the Pool
   * @param yieldReceiver address of the yield receiver
   * @dev Only CONTROLLER of pool can set yield receier.
   */
  function setYieldReceiver(
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    address yieldReceiver
  ) external {
    _authenticate(DATASTORE, poolId, true, false, [false, true]);

    DATASTORE.writeAddress(poolId, rks.yieldReceiver, yieldReceiver);
    emit YieldReceiverSet(poolId, yieldReceiver);
  }

  /**
   * @custom:subsection                           ** MAINTAINER **
   */

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice Set the maintainer address on initiation or later
   * @param _newMaintainer address of the new maintainer
   */
  function _setMaintainer(
    DataStoreModuleStorage storage DATASTORE,
    uint256 _id,
    address _newMaintainer
  ) internal {
    require(_newMaintainer != address(0), "SML:maintainer cannot be zero");

    DATASTORE.writeAddress(_id, rks.maintainer, _newMaintainer);
    emit MaintainerChanged(_id, _newMaintainer);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice CONTROLLER of the ID can change the maintainer to any address other than ZERO_ADDRESS
   * @dev there can only be 1 maintainer per ID.
   * @dev it is wise to change the maintainer before the CONTROLLER, in case of any migration
   * @dev we don't use _authenticate here because malicious maintainers can imprison operators
   * * and prevent them entering here, smh.
   */
  function changeMaintainer(
    DataStoreModuleStorage storage DATASTORE,
    uint256 id,
    address newMaintainer
  ) external {
    require(DATASTORE.readUint(id, rks.initiated) != 0, "SML:ID is not initiated");
    require(msg.sender == DATASTORE.readAddress(id, rks.CONTROLLER), "SML:sender not CONTROLLER");
    uint256 typeOfId = DATASTORE.readUint(id, rks.TYPE);
    require(typeOfId == ID_TYPE.OPERATOR || typeOfId == ID_TYPE.POOL, "SML:invalid TYPE");

    _setMaintainer(DATASTORE, id, newMaintainer);
  }

  /**
   * @custom:subsection                           ** MAINTENANCE FEE **
   */

  /**
   * @custom:visibility -> view-public
   */

  /**
   * @notice Gets fee as a percentage, PERCENTAGE_DENOMINATOR = 100%
   *
   * @dev respecs to the switching delay.
   *
   * @return fee = percentage * PERCENTAGE_DENOMINATOR / 100
   */
  function getMaintenanceFee(
    DataStoreModuleStorage storage DATASTORE,
    uint256 id
  ) public view returns (uint256 fee) {
    if (DATASTORE.readUint(id, rks.feeSwitch) > block.timestamp) {
      return DATASTORE.readUint(id, rks.priorFee);
    }
    return DATASTORE.readUint(id, rks.fee);
  }

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice internal function to set fee with NO DELAY
   */
  function _setMaintenanceFee(
    DataStoreModuleStorage storage DATASTORE,
    uint256 _id,
    uint256 _newFee
  ) internal {
    require(_newFee <= MAX_MAINTENANCE_FEE, "SML:> MAX_MAINTENANCE_FEE");
    DATASTORE.writeUint(_id, rks.fee, _newFee);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice Changes the fee that is applied to the newly created validators, with A DELAY OF SWITCH_LATENCY.
   * @dev Cannot be called again while its currently switching.
   * @dev advise that 100% == PERCENTAGE_DENOMINATOR
   */
  function switchMaintenanceFee(
    DataStoreModuleStorage storage DATASTORE,
    uint256 id,
    uint256 newFee
  ) external {
    _authenticate(DATASTORE, id, true, false, [true, true]);

    require(block.timestamp > DATASTORE.readUint(id, rks.feeSwitch), "SML:currently switching");

    DATASTORE.writeUint(id, rks.priorFee, DATASTORE.readUint(id, rks.fee));
    DATASTORE.writeUint(id, rks.feeSwitch, block.timestamp + SWITCH_LATENCY);

    _setMaintenanceFee(DATASTORE, id, newFee);

    emit FeeSwitched(id, newFee, block.timestamp + SWITCH_LATENCY);
  }

  /**
   * @custom:subsection                           ** INTERNAL WALLET **
   *
   * @dev Internal wallet of an ID accrues fees over time.
   * It is also used by Node Operators to fund 1 ETH per validator proposal, which is reimbursed if/when activated.
   */

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice Simply increases the balance of an IDs Maintainer wallet
   * @param _value Ether (in Wei) amount to increase the wallet balance.
   */
  function _increaseWalletBalance(
    DataStoreModuleStorage storage DATASTORE,
    uint256 _id,
    uint256 _value
  ) internal {
    DATASTORE.addUint(_id, rks.wallet, _value);
  }

  /**
   * @notice To decrease the balance of an Operator's wallet internally
   * @param _value Ether (in Wei) amount to decrease the wallet balance and send back to Maintainer.
   */
  function _decreaseWalletBalance(
    DataStoreModuleStorage storage DATASTORE,
    uint256 _id,
    uint256 _value
  ) internal {
    require(DATASTORE.readUint(_id, rks.wallet) >= _value, "SML:insufficient wallet balance");
    DATASTORE.subUint(_id, rks.wallet, _value);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice external function to increase the internal wallet balance
   * @dev anyone can increase the balance directly, useful for withdrawalContracts and fees etc.
   */
  function increaseWalletBalance(
    DataStoreModuleStorage storage DATASTORE,
    uint256 id
  ) external returns (bool success) {
    _authenticate(DATASTORE, id, false, false, [true, true]);
    _increaseWalletBalance(DATASTORE, id, msg.value);
    success = true;
  }

  /**
   * @notice external function to decrease the internal wallet balance
   * @dev only CONTROLLER can decrease the balance externally,
   * @return success if the amount was sent and deducted
   */
  function decreaseWalletBalance(
    DataStoreModuleStorage storage DATASTORE,
    uint256 id,
    uint256 value
  ) external returns (bool success) {
    _authenticate(DATASTORE, id, true, false, [true, true]);

    require(address(this).balance >= value, "SML:insufficient contract balance");

    _decreaseWalletBalance(DATASTORE, id, value);
    address controller = DATASTORE.readAddress(id, rks.CONTROLLER);

    (success, ) = payable(controller).call{value: value}("");
    require(success, "SML:Failed to send ETH");
  }

  /**
   * @custom:subsection                           ** OPERATORS PERIOD **
   */

  /**
   * @custom:visibility -> view-public
   */

  function getValidatorPeriod(
    DataStoreModuleStorage storage DATASTORE,
    uint256 id
  ) public view returns (uint256 period) {
    if (DATASTORE.readUint(id, rks.periodSwitch) > block.timestamp) {
      return DATASTORE.readUint(id, rks.priorPeriod);
    }
    return DATASTORE.readUint(id, rks.validatorPeriod);
  }

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice internal function to set validator period with NO DELAY
   */
  function _setValidatorPeriod(
    DataStoreModuleStorage storage DATASTORE,
    uint256 _operatorId,
    uint256 _newPeriod
  ) internal {
    require(_newPeriod >= MIN_VALIDATOR_PERIOD, "SML:< MIN_VALIDATOR_PERIOD");
    require(_newPeriod <= MAX_VALIDATOR_PERIOD, "SML:> MAX_VALIDATOR_PERIOD");

    DATASTORE.writeUint(_operatorId, rks.validatorPeriod, _newPeriod);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice updates validatorPeriod for given operator, with A DELAY OF SWITCH_LATENCY.
   * @dev limited by MIN_VALIDATOR_PERIOD and MAX_VALIDATOR_PERIOD
   */
  function switchValidatorPeriod(
    DataStoreModuleStorage storage DATASTORE,
    uint256 operatorId,
    uint256 newPeriod
  ) external {
    _authenticate(DATASTORE, operatorId, true, false, [true, false]);

    require(
      block.timestamp > DATASTORE.readUint(operatorId, rks.periodSwitch),
      "SML:currently switching"
    );

    DATASTORE.writeUint(
      operatorId,
      rks.priorPeriod,
      DATASTORE.readUint(operatorId, rks.validatorPeriod)
    );
    DATASTORE.writeUint(operatorId, rks.periodSwitch, block.timestamp + SWITCH_LATENCY);

    _setValidatorPeriod(DATASTORE, operatorId, newPeriod);

    emit ValidatorPeriodSwitched(operatorId, newPeriod, block.timestamp + SWITCH_LATENCY);
  }

  /**
   * @custom:section                           ** PRISON **
   *
   * @custom:visibility -> view-public
   * @dev check OEL.blameProposal and OEL.blameExit for imprisonment details
   */

  /**
   * @notice Checks if the given operator is Prisoned
   * @dev rks.release key refers to the end of the last imprisonment, when the limitations of operator is lifted
   */
  function isPrisoned(
    DataStoreModuleStorage storage DATASTORE,
    uint256 operatorId
  ) public view returns (bool) {
    return (block.timestamp < DATASTORE.readUint(operatorId, rks.release));
  }

  /**
   * @custom:section                           ** VALIDATOR DELEGATION **
   */

  /**
   * @custom:visibility -> view-public
   */

  /**
   * @notice maximum number of remaining operator allowance that the given Operator is allowed to create for given Pool
   * @dev an operator cannot create new validators if:
   * * 1. operator is a monopoly
   * * 2. allowance is filled
   * * * But if operator is set as a fallback, it can if set fallbackThreshold is reached on all allowances.
   * @dev If operator withdraws a validator, then able to create a new one.
   * @dev prestake checks the approved validator count to make sure the number of validators are not bigger than allowance
   * @dev allowance doesn't change when new validators created or old ones are unstaked.
   */
  function operatorAllowance(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    uint256 operatorId
  ) public view returns (uint256 remValidators) {
    // monopoly check
    {
      // readUint for an array gives us length
      uint256 numOperatorValidators = DATASTORE.readUint(operatorId, rks.validators);
      uint256 monopoly_threshold = self.MONOPOLY_THRESHOLD;
      if (numOperatorValidators >= monopoly_threshold) {
        return 0;
      } else {
        remValidators = monopoly_threshold - numOperatorValidators;
      }
    }

    // fallback check
    {
      if (operatorId == DATASTORE.readUint(poolId, rks.fallbackOperator)) {
        // readUint for an array gives us length
        uint256 numPoolValidators = DATASTORE.readUint(poolId, rks.validators);
        uint256 totalAllowance = DATASTORE.readUint(poolId, rks.totalAllowance);

        if (
          totalAllowance == 0 ||
          (((numPoolValidators * PERCENTAGE_DENOMINATOR) / totalAllowance) >=
            DATASTORE.readUint(poolId, rks.fallbackThreshold))
        ) {
          return remValidators;
        }
      }
    }

    // approval check
    {
      uint256 allowance = DATASTORE.readUint(poolId, DSML.getKey(operatorId, rks.allowance));
      uint256 pooledValidators = DATASTORE.readUint(
        poolId,
        DSML.getKey(operatorId, rks.proposedValidators)
      ) + DATASTORE.readUint(poolId, DSML.getKey(operatorId, rks.activeValidators));
      if (pooledValidators >= allowance) {
        return 0;
      } else {
        uint256 remAllowance = allowance - pooledValidators;
        if (remValidators > remAllowance) {
          remValidators = remAllowance;
        }
      }
    }
  }

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice To give allowence to node operator for a pool. It re-sets the allowance with the given value.
   * @dev The value that is returned is not the new allowance, but the old one since it is required
   * * at the point where it is being returned.
   * @return oldAllowance to be used later, nothing is done with it within this function.
   */
  function _approveOperator(
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    uint256 operatorId,
    uint256 allowance
  ) internal returns (uint256 oldAllowance) {
    bytes32 allowanceKey = DSML.getKey(operatorId, rks.allowance);

    oldAllowance = DATASTORE.readUint(poolId, allowanceKey);
    DATASTORE.writeUint(poolId, allowanceKey, allowance);

    emit Delegation(poolId, operatorId, allowance);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice To allow a Node Operator run validators for your Pool with a given number of validators.
   * * This number can be set again at any given point in the future.
   * @param poolId the gETH id of the Pool
   * @param operatorIds array of Operator IDs to allow them create validators
   * @param allowances the MAX number of validators that can be created by the Operator, for given Pool
   * @dev When decreased the approved validator count below current active+proposed validators,
   * operator cannot create new validators.
   */
  function delegate(
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    uint256[] calldata operatorIds,
    uint256[] calldata allowances
  ) external {
    _authenticate(DATASTORE, poolId, false, true, [false, true]);
    uint256 operatorIdsLen = operatorIds.length;
    require(operatorIdsLen == allowances.length, "SML:allowances should match");

    for (uint256 i; i < operatorIdsLen; ) {
      require(
        DATASTORE.readUint(operatorIds[i], rks.TYPE) == ID_TYPE.OPERATOR,
        "SML:id not operator"
      );
      require(allowances[i] <= MAX_ALLOWANCE, "SML:> MAX_ALLOWANCE, set fallback");

      unchecked {
        i += 1;
      }
    }

    uint256 newCumulativeSubset;
    uint256 oldCumulativeSubset;
    for (uint256 i; i < operatorIdsLen; ) {
      newCumulativeSubset += allowances[i];
      oldCumulativeSubset += _approveOperator(DATASTORE, poolId, operatorIds[i], allowances[i]);

      unchecked {
        i += 1;
      }
    }

    if (newCumulativeSubset > oldCumulativeSubset) {
      DATASTORE.addUint(poolId, rks.totalAllowance, newCumulativeSubset - oldCumulativeSubset);
    } else if (newCumulativeSubset < oldCumulativeSubset) {
      DATASTORE.subUint(poolId, rks.totalAllowance, oldCumulativeSubset - newCumulativeSubset);
    }
  }

  /**
   * @notice To allow a Node Operator run validators for your Pool without a limit
   * * after pool reaches a given treshold as percentage.
   * * fallback operator and percentage can be set again at any given point in the future.
   * * cannot set an operator as a fallback operator while it is currently in prison.
   * @param poolId the gETH id of the Pool
   * @param operatorId Operator ID to allow create validators
   * @param fallbackThreshold the percentage (with PERCENTAGE_DENOMINATOR) that fallback operator
   * * is activated for given Pool. Should not be greater than 100.
   */
  function setFallbackOperator(
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    uint256 operatorId,
    uint256 fallbackThreshold
  ) external {
    _authenticate(DATASTORE, poolId, false, true, [false, true]);

    if (operatorId == 0) {
      DATASTORE.writeUint(poolId, rks.fallbackOperator, 0);
      DATASTORE.writeUint(poolId, rks.fallbackThreshold, 0);
      emit FallbackOperator(poolId, 0, 0);
    } else {
      require(
        DATASTORE.readUint(operatorId, rks.TYPE) == ID_TYPE.OPERATOR,
        "SML:fallback not operator"
      );

      require(
        fallbackThreshold <= PERCENTAGE_DENOMINATOR,
        "SML:threshold cannot be greater than 100"
      );

      DATASTORE.writeUint(poolId, rks.fallbackThreshold, fallbackThreshold);
      DATASTORE.writeUint(poolId, rks.fallbackOperator, operatorId);

      emit FallbackOperator(poolId, operatorId, fallbackThreshold);
    }
  }

  /**
   * @custom:section                           ** POOLING  **
   */

  /**
   * @custom:subsection                           ** DEPOSIT HELPERS **
   */

  /**
   * @custom:visibility -> view-internal
   */

  function _isGeodePackageIsolated(address _packageAddress) internal view returns (bool) {
    return IGeodePackage(_packageAddress).isolationMode();
  }

  /**
   * @notice returns wrapped bound liquidity pool. If deployed, if not in isolationMode.
   * @dev returns address(0) if no pool or it is under isolation
   */
  function _getLiquidityPool(
    DataStoreModuleStorage storage DATASTORE,
    uint256 _poolId
  ) internal view returns (ILiquidityPool) {
    address liqPool = DATASTORE.readAddress(_poolId, rks.liquidityPool);
    if (liqPool == address(0)) {
      return ILiquidityPool(address(0));
    } else if (_isGeodePackageIsolated(liqPool)) {
      return ILiquidityPool(address(0));
    } else {
      return ILiquidityPool(liqPool);
    }
  }

  /**
   * @custom:visibility -> view-public
   */

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
    StakeModuleStorage storage self,
    uint256 poolId
  ) public view returns (bool isValid) {
    uint256 lastupdate = self.gETH.priceUpdateTimestamp(poolId);
    unchecked {
      isValid =
        lastupdate + PRICE_EXPIRY >= block.timestamp &&
        lastupdate >= self.ORACLE_UPDATE_TIMESTAMP;
    }
  }

  /**
   * @notice checks if staking is allowed in given staking pool
   * @notice staking is not allowed if:
   * 1. Price is not valid
   * 2. WithdrawalContract is in Isolation Mode, can have many reasons
   */
  function isMintingAllowed(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId
  ) public view returns (bool) {
    return
      (isPriceValid(self, poolId)) &&
      !(_isGeodePackageIsolated(DATASTORE.readAddress(poolId, rks.withdrawalContract)));
  }

  /**
   * @custom:subsection                           ** DEPOSIT **
   */

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice mints gETH for a given ETH amount, keeps the tokens in Portal.
   * @dev fails if minting is not allowed: invalid price, or isolationMode.
   */
  function _mintgETH(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 _poolId,
    uint256 _ethAmount
  ) internal returns (uint256 mintedgETH) {
    require(isMintingAllowed(self, DATASTORE, _poolId), "SML:minting is not allowed");

    uint256 price = self.gETH.pricePerShare(_poolId);
    require(price > 0, "SML:price is zero?");

    mintedgETH = (((_ethAmount * gETH_DENOMINATOR) / price));
    self.gETH.mint(address(this), _poolId, mintedgETH, "");
    DATASTORE.addUint(_poolId, rks.surplus, _ethAmount);
  }

  /**
   * @notice conducts a buyback using the given liquidity pool
   * @param _poolId id of the gETH that will be bought
   * @param _maxEthToSell max ETH amount to sell in the liq pool
   * @param _deadline TX is expected to revert by Swap.sol if not meet
   * @dev this function assumes that pool is deployed by deployLiquidityPool
   * as index 0 is ETH and index 1 is gETH!
   */
  function _buyback(
    DataStoreModuleStorage storage DATASTORE,
    uint256 _poolId,
    uint256 _maxEthToSell,
    uint256 _deadline
  ) internal returns (uint256 remETH, uint256 boughtgETH) {
    ILiquidityPool LP = _getLiquidityPool(DATASTORE, _poolId);
    // skip if no liquidity pool is found
    if (address(LP) != address(0)) {
      uint256 debt = LP.getDebt();
      // skip if debt is too low
      if (debt > IGNORABLE_DEBT) {
        if (_maxEthToSell > debt) {
          // if debt is lower, then only sell debt
          remETH = _maxEthToSell - debt;
        } else {
          // if eth is lower, then sell all eth, remETH already 0
          debt = _maxEthToSell;
        }
        // SWAP in LP
        boughtgETH = LP.swap{value: debt}(0, 1, debt, 0, _deadline);
      } else {
        remETH = _maxEthToSell;
      }
    } else {
      remETH = _maxEthToSell;
    }
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice Allowing users to deposit into a staking pool.
   * @notice If a pool is not public, only the controller and if there is a whitelist contract, the whitelisted addresses can deposit.
   * @param poolId id of the staking pool, liquidity pool and gETH to be used.
   * @param mingETH liquidity pool parameter
   * @param deadline liquidity pool parameter
   * @dev an example for minting + buybacks
   * Buys from DWP if price is low -debt-, mints new tokens if surplus is sent -more than debt-
   * * debt  msgValue
   * * 100   10  => buyback
   * * 100   100 => buyback
   * * 10    100 => buyback + mint
   * * 1     x   => mint
   * * 0.5   x   => mint
   * * 0     x   => mint
   */
  function deposit(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    uint256 mingETH,
    uint256 deadline,
    address receiver
  ) external returns (uint256 boughtgETH, uint256 mintedgETH) {
    _authenticate(DATASTORE, poolId, false, false, [false, true]);
    require(msg.value > 0, "SML:msg.value cannot be zero");
    require(deadline > block.timestamp, "SML:deadline not met");
    require(receiver != address(0), "SML:receiver is zero address");

    if (isPrivatePool(DATASTORE, poolId)) {
      require(isWhitelisted(DATASTORE, poolId, msg.sender), "SML:sender not whitelisted");
    }

    uint256 remEth = msg.value;
    (remEth, boughtgETH) = _buyback(DATASTORE, poolId, remEth, deadline);

    if (remEth > 0) {
      mintedgETH = _mintgETH(self, DATASTORE, poolId, remEth);
    }

    require(boughtgETH + mintedgETH >= mingETH, "SML:less than minimum");

    // send back to user
    self.gETH.safeTransferFrom(address(this), receiver, poolId, boughtgETH + mintedgETH, "");

    emit Deposit(poolId, boughtgETH, mintedgETH);
  }

  /**
   * @custom:section                           ** VALIDATOR CREATION **
   *
   * @dev Creation of a Validator takes 2 steps: propose and beacon stake.
   * Before entering stake() function, _canStake verifies the eligibility of
   * given pubKey that is proposed by an operator with proposeStake function.
   * Eligibility is defined by an optimistic alienation, check OracleUtils._alienateValidator() for info.
   */

  /**
   * @custom:visibility -> view
   */

  /**
   * @notice internal function to check if a validator can use the pool funds
   *
   *  @param _pubkey BLS12-381 public key of the validator
   *  @return true if:
   *   - pubkey should be proposed
   *   - pubkey should not be alienated (https://bit.ly/3Tkc6UC)
   *   - the validator's index is already covered by VERIFICATION_INDEX. Updated by Telescope.
   */
  function _canStake(
    StakeModuleStorage storage self,
    bytes calldata _pubkey,
    uint256 _verificationIndex
  ) internal view returns (bool) {
    return
      (self.validators[_pubkey].state == VALIDATOR_STATE.PROPOSED) &&
      (self.validators[_pubkey].index <= _verificationIndex);
  }

  /**
   * @notice external function to check if a validator can use the pool funds
   */
  function canStake(
    StakeModuleStorage storage self,
    bytes calldata pubkey
  ) external view returns (bool) {
    return _canStake(self, pubkey, self.VERIFICATION_INDEX);
  }

  /**
   * @dev -> external
   */

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
   * @param signatures31 Array of BLS12-381 signatures that will be used to send 31 ETH from pool on stake() function call
   *
   * @dev DCL.DEPOSIT_AMOUNT_PRESTAKE = 1 ether, DCL.DEPOSIT_AMOUNT = 32 ether which is the minimum amount to create a validator.
   * 31 Ether will be staked after verification of oracles. 32 in total.
   * 1 ether will be sent back to Node Operator when the finalized deposit is successful.
   * @dev ProposeStake requires enough allowance from Staking Pools to Operators.
   * @dev ProposeStake requires enough funds within Wallet.
   * @dev Max number of validators to propose is per call is MAX_DEPOSITS_PER_CALL (currently 50)
   */
  function proposeStake(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    uint256 operatorId,
    bytes[] calldata pubkeys,
    bytes[] calldata signatures1,
    bytes[] calldata signatures31
  ) external {
    // checks
    _authenticate(DATASTORE, operatorId, false, true, [true, false]);
    _authenticate(DATASTORE, poolId, false, false, [false, true]);
    require(
      !(_isGeodePackageIsolated(DATASTORE.readAddress(poolId, rks.withdrawalContract))),
      "SML:withdrawalContract is isolated"
    );

    uint256 pkLen = pubkeys.length;

    require((pkLen > 0) && (pkLen <= DCL.MAX_DEPOSITS_PER_CALL), "SML:1 - 50 validators");

    require(
      pkLen == signatures1.length && pkLen == signatures31.length,
      "SML:invalid input length"
    );

    require(
      operatorAllowance(self, DATASTORE, poolId, operatorId) >= pkLen,
      "SML:insufficient allowance"
    );

    require(
      DATASTORE.readUint(poolId, rks.surplus) >= DCL.DEPOSIT_AMOUNT * pkLen,
      "SML:not enough surplus"
    );

    _decreaseWalletBalance(DATASTORE, operatorId, (pkLen * DCL.DEPOSIT_AMOUNT_PRESTAKE));

    for (uint256 i; i < pkLen; ) {
      require(pubkeys[i].length == DCL.PUBKEY_LENGTH, "SML:PUBKEY_LENGTH ERROR");
      require(signatures1[i].length == DCL.SIGNATURE_LENGTH, "SML:SIGNATURE_LENGTH ERROR");
      require(signatures31[i].length == DCL.SIGNATURE_LENGTH, "SML:SIGNATURE_LENGTH ERROR");

      unchecked {
        i += 1;
      }
    }

    ConstantValidatorData memory valData = ConstantValidatorData({
      index: uint64(self.VALIDATORS_INDEX + 1),
      period: uint64(getValidatorPeriod(DATASTORE, operatorId)),
      poolFee: getMaintenanceFee(DATASTORE, poolId),
      operatorFee: getMaintenanceFee(DATASTORE, operatorId),
      infrastructureFee: self.infrastructureFees[ID_TYPE.POOL],
      withdrawalCredential: DATASTORE.readBytes(poolId, rks.withdrawalCredential)
    });

    for (uint256 i; i < pkLen; ) {
      require(
        self.validators[pubkeys[i]].state == VALIDATOR_STATE.NONE,
        "SML: used or alienated pk"
      );

      self.validators[pubkeys[i]] = Validator(
        VALIDATOR_STATE.PROPOSED,
        valData.index + uint64(i),
        uint64(block.timestamp),
        valData.period,
        poolId,
        operatorId,
        valData.poolFee,
        valData.operatorFee,
        valData.infrastructureFee,
        signatures31[i]
      );

      DCL.depositValidator(
        pubkeys[i],
        valData.withdrawalCredential,
        signatures1[i],
        DCL.DEPOSIT_AMOUNT_PRESTAKE
      );

      unchecked {
        i += 1;
      }
    }

    DATASTORE.subUint(poolId, rks.surplus, (pkLen * DCL.DEPOSIT_AMOUNT));
    DATASTORE.addUint(poolId, rks.secured, (pkLen * DCL.DEPOSIT_AMOUNT));

    DATASTORE.addUint(poolId, DSML.getKey(operatorId, rks.proposedValidators), pkLen);
    DATASTORE.appendBytesArrayBatch(poolId, rks.validators, pubkeys);
    DATASTORE.appendBytesArrayBatch(operatorId, rks.validators, pubkeys);

    self.VALIDATORS_INDEX += pkLen;

    emit StakeProposal(poolId, operatorId, pubkeys);
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
   *  separate them in similar groups as much as possible.
   *  @dev Max number of validators to boostrap is MAX_DEPOSITS_PER_CALL (currently 50)
   *  @dev A pubkey that is alienated will not get through. Do not frontrun during ProposeStake.
   */
  function stake(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 operatorId,
    bytes[] calldata pubkeys
  ) external {
    _authenticate(DATASTORE, operatorId, false, true, [true, false]);

    require(
      (pubkeys.length > 0) && (pubkeys.length <= DCL.MAX_DEPOSITS_PER_CALL),
      "SML:1 - 50 validators"
    );

    {
      uint256 pubkeysLen = pubkeys.length;
      uint256 _verificationIndex = self.VERIFICATION_INDEX;
      for (uint256 j; j < pubkeysLen; ) {
        require(
          _canStake(self, pubkeys[j], _verificationIndex),
          "SML:not all pubkeys are stakeable"
        );

        require(
          self.validators[pubkeys[j]].operatorId == operatorId,
          "SML:not all pubkeys belong to operator"
        );

        unchecked {
          j += 1;
        }
      }
    }

    {
      bytes32 activeValKey = DSML.getKey(operatorId, rks.activeValidators);
      bytes32 proposedValKey = DSML.getKey(operatorId, rks.proposedValidators);
      uint256 poolId = self.validators[pubkeys[0]].poolId;
      bytes memory withdrawalCredential = DATASTORE.readBytes(poolId, rks.withdrawalCredential);

      uint256 lastIdChange = 0;
      for (uint256 i; i < pubkeys.length; ) {
        uint256 newPoolId = self.validators[pubkeys[i]].poolId;
        if (poolId != newPoolId) {
          uint256 sinceLastIdChange;

          unchecked {
            sinceLastIdChange = i - lastIdChange;
          }

          DATASTORE.subUint(poolId, rks.secured, (DCL.DEPOSIT_AMOUNT * (sinceLastIdChange)));
          DATASTORE.subUint(poolId, proposedValKey, (sinceLastIdChange));
          DATASTORE.addUint(poolId, activeValKey, (sinceLastIdChange));

          lastIdChange = i;
          poolId = newPoolId;
          withdrawalCredential = DATASTORE.readBytes(poolId, rks.withdrawalCredential);
        }

        DCL.depositValidator(
          pubkeys[i],
          withdrawalCredential,
          self.validators[pubkeys[i]].signature31,
          (DCL.DEPOSIT_AMOUNT - DCL.DEPOSIT_AMOUNT_PRESTAKE)
        );

        self.validators[pubkeys[i]].state = VALIDATOR_STATE.ACTIVE;

        unchecked {
          i += 1;
        }
      }
      {
        uint256 sinceLastIdChange;
        unchecked {
          sinceLastIdChange = pubkeys.length - lastIdChange;
        }

        DATASTORE.subUint(poolId, rks.secured, DCL.DEPOSIT_AMOUNT * (sinceLastIdChange));
        DATASTORE.subUint(poolId, proposedValKey, (sinceLastIdChange));
        DATASTORE.addUint(poolId, activeValKey, (sinceLastIdChange));
      }

      _increaseWalletBalance(DATASTORE, operatorId, DCL.DEPOSIT_AMOUNT_PRESTAKE * pubkeys.length);

      emit Stake(pubkeys);
    }
  }

  /**
   * @custom:section                           ** VALIDATOR EXITS **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice Notifies the node operator with ExitRequest event
   * @dev Prevents the request if validator is still within the MIN_VALIDATOR_PERIOD
   * @dev Only the active validators can be called for an exit
   * @dev Can only be called by the withdrawalContract of the pool given validator belongs to.
   */
  function requestExit(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    bytes calldata pk
  ) external {
    require(
      block.timestamp > self.validators[pk].createdAt + MIN_VALIDATOR_PERIOD,
      "SML:early exit not allowed"
    );
    require(
      msg.sender == DATASTORE.readAddress(poolId, rks.withdrawalContract),
      "SML:sender is not withdrawal contract"
    );
    require(self.validators[pk].poolId == poolId, "SML:incorrect poolId");
    require(self.validators[pk].state == VALIDATOR_STATE.ACTIVE, "SML:not an active validator");

    self.validators[pk].state = VALIDATOR_STATE.EXIT_REQUESTED;

    emit ExitRequest(pk);
  }

  /**
   * @notice Finalizes the exit process for a validator.
   * @dev Strongly advised to be called right after the exiting process is over.
   * @dev Operators can exit at any time they want.
   * @dev Can only be called by the withdrawalContract of the pool given validator belongs to.
   */
  function finalizeExit(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    bytes calldata pk
  ) external {
    require(
      msg.sender == DATASTORE.readAddress(poolId, rks.withdrawalContract),
      "SML:sender is not withdrawal contract"
    );
    require(self.validators[pk].poolId == poolId, "SML:incorrect poolId");

    uint256 state = self.validators[pk].state;
    require(
      state == VALIDATOR_STATE.ACTIVE || state == VALIDATOR_STATE.EXIT_REQUESTED,
      "SML:not an active validator"
    );

    self.validators[pk].state = VALIDATOR_STATE.EXITED;

    emit Exit(pk);
  }
}
