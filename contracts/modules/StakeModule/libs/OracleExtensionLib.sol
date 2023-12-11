// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// external - libraries
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
// internal - globals
import {PERCENTAGE_DENOMINATOR, gETH_DENOMINATOR} from "../../../globals/macros.sol";
import {RESERVED_KEY_SPACE as rks} from "../../../globals/reserved_key_space.sol";
import {ID_TYPE} from "../../../globals/id_type.sol";
import {VALIDATOR_STATE} from "../../../globals/validator_state.sol";
// internal - structs
import {DataStoreModuleStorage} from "../../DataStoreModule/structs/storage.sol";
import {StakeModuleStorage} from "../structs/storage.sol";
// internal - libraries
import {DataStoreModuleLib as DSML} from "../../DataStoreModule/libs/DataStoreModuleLib.sol";
import {DepositContractLib as DCL} from "./DepositContractLib.sol";
import {StakeModuleLib as SML} from "./StakeModuleLib.sol";

/**
 * @title OEL: Oracle Extension Library
 *
 * @notice An extension to SML
 * @notice Oracle, named Telescope, handles some operations for The Staking Library,
 * * using the logic explained below.
 *
 * @dev review: DataStoreModule for the id based isolated storage logic.
 * @dev review: StakeModuleLib for base staking logic.
 *
 * @dev Telescope is currently responsible for 4 tasks:
 * * Updating the on-chain price of all pools with a MerkleRoot for minting operations
 * * Updating the on-chain balances info of all validators with a MerkleRoot for withdrawal operations
 * * Confirming validator proposals
 * * Regulating the Node Operators
 *
 * 1. updateVerificationIndex: Confirming validator proposals
 * * 2 step process is essential to prevent the frontrunning with a problematic withdrawalCredential: https://bit.ly/3Tkc6UC
 * * Simply, all proposed validator has an index bound to them,
 * * n representing the latest proposal: (0,n]
 * * Telescope verifies the validator data provided in proposeStake:
 * * especially sig1, sig31 and withdrawal credentials.
 * * Telescope confirms the latest index verified and states the faulty validator proposals (aliens)
 * * If a validator proposal is faulty then it's state is set to 69, refer to globals/validator_state.sol
 *
 * 2. regulateOperators: Regulating the Operators
 * * Operators can act faulty in many different ways. To prevent such actions,
 * * Telescope regulates them with well defined limitations.
 * * Currently only issue is the fee theft, meaning operators have not
 * * used the withdrawal contract for miner fees or MEV boost.
 * * There can be other restrictions in the future.
 *
 * 2. reportBeacon: Continous Data from Beacon chain: Price Merkle Root & Balances Merkle Root & # of active validators
 * * 1. Oracle Nodes calculate the price of its derivative, according to the validator data such as balance and fees.
 * * 2. If a pool doesn't have a validator, the price is kept the same.
 * * 3. A merkle tree is constructed with the order of allIdsByType array.
 * * 4. A watcher collects all the signatures from Multiple Oracle Nodes, and submits the merkle root.
 * * 5. Anyone can update the price of the derivative  by calling priceSync() functions with correct merkle proofs
 * * 6. Minting is allowed within PRICE_EXPIRY (24H) after the last price update.
 * * 7. Updates the regulation around Monopolies and provides BALANCE_MERKLE_ROOT to be used within withdrawal process.
 *
 * @dev Most external functions have OracleOnly modifier. Except: priceSync, priceSyncBatch, blameExit and blameProposal.
 *
 * @dev This is an external library, requires deployment.
 *
 * @author Ice Bear & Crash Bandicoot
 */

library OracleExtensionLib {
  using DSML for DataStoreModuleStorage;
  using SML for StakeModuleStorage;

  /**
   * @custom:section                           ** CONSTANTS **
   */
  /// @notice effective on MONOPOLY_THRESHOLD, limiting the active validators: Set to 1%
  uint256 internal constant MONOPOLY_RATIO = PERCENTAGE_DENOMINATOR / 100;

  /// @notice sensible value for the minimum beacon chain validators. No reasoning.
  uint256 internal constant MIN_VALIDATOR_COUNT = 50000;

  /// @notice limiting the access for Operators in case of bad/malicious/faulty behaviour
  uint256 internal constant PRISON_SENTENCE = 14 days;

  /// @notice maximum delay between the creation of an (approved) proposal and stake() call.
  uint256 internal constant MAX_BEACON_DELAY = 14 days;

  /**
   * @custom:section                           ** EVENTS **
   */
  event Alienated(bytes pubkey);
  event VerificationIndexUpdated(uint256 validatorVerificationIndex);
  event FeeTheft(uint256 indexed id, bytes proofs);
  event Prisoned(uint256 indexed operatorId, bytes proof, uint256 releaseTimestamp);
  event OracleReported(
    bytes32 priceMerkleRoot,
    bytes32 balanceMerkleRoot,
    uint256 monopolyThreshold
  );

  /**
   * @custom:section                           ** MODIFIERS **
   */
  modifier onlyOracle(StakeModuleStorage storage self) {
    require(msg.sender == self.ORACLE_POSITION, "OEL:sender NOT ORACLE");
    _;
  }

  /**
   * @custom:section                                       ** VERIFICATION INDEX **
   */

  /**
   * @custom:visibility -> internal
   *
   * @notice "Alien" is a validator that is created with a faulty withdrawal
   * credential or signatures, this is a malicious act.
   * @notice Alienation results in imprisonment for the operator of the faulty validator proposal.
   * @dev While alienating a validator we should adjust the 'surplus' and 'secured'
   * balances of the pool accordingly
   * @dev We should adjust the 'proposedValidators' to fix allowances.
   */
  function _alienateValidator(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 verificationIndex,
    bytes calldata _pk
  ) internal {
    require(self.validators[_pk].index <= verificationIndex, "OEL:unexpected index");
    require(
      self.validators[_pk].state == VALIDATOR_STATE.PROPOSED,
      "OEL:NOT all pubkeys are pending"
    );

    uint256 operatorId = self.validators[_pk].operatorId;
    _imprison(DATASTORE, operatorId, _pk);

    uint256 poolId = self.validators[_pk].poolId;
    DATASTORE.subUint(poolId, rks.secured, DCL.DEPOSIT_AMOUNT);
    DATASTORE.addUint(poolId, rks.surplus, DCL.DEPOSIT_AMOUNT);

    DATASTORE.subUint(poolId, DSML.getKey(operatorId, rks.proposedValidators), 1);
    DATASTORE.addUint(poolId, DSML.getKey(operatorId, rks.alienValidators), 1);

    self.validators[_pk].state = VALIDATOR_STATE.ALIENATED;

    emit Alienated(_pk);
  }

  /**
   * @custom:visibility -> external
   *
   * @notice Updating VERIFICATION_INDEX, signaling that it is safe to activate
   * the validator proposals with lower index than new VERIFICATION_INDEX
   * @param validatorVerificationIndex (inclusive) index of the highest validator that is verified to be activated
   * @param alienatedPubkeys faulty proposals within the range of new and old verification indexes.
   */
  function updateVerificationIndex(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 validatorVerificationIndex,
    bytes[] calldata alienatedPubkeys
  ) external onlyOracle(self) {
    require(self.VALIDATORS_INDEX >= validatorVerificationIndex, "OEL:high VERIFICATION_INDEX");
    require(validatorVerificationIndex > self.VERIFICATION_INDEX, "OEL:low VERIFICATION_INDEX");

    uint256 alienatedPubkeysLen = alienatedPubkeys.length;
    for (uint256 i; i < alienatedPubkeysLen; ) {
      _alienateValidator(self, DATASTORE, validatorVerificationIndex, alienatedPubkeys[i]);

      unchecked {
        i += 1;
      }
    }

    self.VERIFICATION_INDEX = validatorVerificationIndex;
    emit VerificationIndexUpdated(validatorVerificationIndex);
  }

  /**
   * @dev                                       ** REGULATING OPERATORS **
   */

  /**
   * @custom:section                           ** PRISON **
   *
   * When node operators act in a malicious way, which can also be interpreted as
   * an honest mistake like using a faulty signature, Oracle imprisons the operator.
   * These conditions are:
   * * 1. Created a malicious validator(alien): faulty withdrawal credential, faulty signatures etc.
   * * 2. Have not respect the validatorPeriod (or blamed for some other valid case)
   * * 3. Stole block fees or MEV boost rewards from the pool
   *
   * @dev this section lacks a potential punishable act, for now early exits are not enforced:
   * While state is EXIT_REQUESTED: validator requested exit, but it hasn't been executed.
   */

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice Put an operator in prison
   * @dev rks.release key refers to the end of the last imprisonment, when the limitations of operator is lifted
   */
  function _imprison(
    DataStoreModuleStorage storage DATASTORE,
    uint256 _operatorId,
    bytes calldata _proof
  ) internal {
    SML._authenticate(DATASTORE, _operatorId, false, false, [true, false]);

    DATASTORE.writeUint(_operatorId, rks.release, block.timestamp + PRISON_SENTENCE);

    emit Prisoned(_operatorId, _proof, block.timestamp + PRISON_SENTENCE);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice imprisoning an Operator if the validator proposal is approved but have not been executed.
   * @dev anyone can call this function while the state is PROPOSED
   * @dev this check can be problematic in the case the beaconchain deposit delay is > MAX_BEACON_DELAY,
   * * depending on the expected delay of telescope approvals.
   * @dev _canStake checks == VALIDATOR_STATE.PROPOSED.
   */
  function blameProposal(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    bytes calldata pk
  ) external {
    require(self._canStake(pk, self.VERIFICATION_INDEX), "OEL:can not blame proposal");
    require(
      block.timestamp > self.validators[pk].createdAt + MAX_BEACON_DELAY,
      "OEL:acceptable delay"
    );

    _imprison(DATASTORE, self.validators[pk].operatorId, pk);
  }

  /**
   * @notice imprisoning an Operator if the validator have not been exited until expected exit
   * @dev normally, oracle should verify the signed exit request on beacon chain for a (deterministic) epoch
   * * before approval. This function enforces it further for the stakers.
   * @dev anyone can call this function while the state is ACTIVE
   * @dev if operator has given enough allowance, they SHOULD rotate the validators to avoid being prisoned
   */
  function blameExit(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    bytes calldata pk
  ) external {
    require(self.validators[pk].state == VALIDATOR_STATE.ACTIVE, "OEL:unexpected validator state");
    require(
      block.timestamp > self.validators[pk].createdAt + self.validators[pk].period,
      "OEL:validator is active"
    );

    _imprison(DATASTORE, self.validators[pk].operatorId, pk);
  }

  /**
  
   */

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice regulating operators, currently only regulation is towards fee theft, can add more stuff in the future.
   * @param feeThefts Operator ids who have stolen MEV or block rewards detected
   * @param proofs  BlockNumber, tx or any other referance as a proof
   * @dev Stuff here result in imprisonment
   */
  function regulateOperators(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256[] calldata feeThefts,
    bytes[] calldata proofs
  ) external onlyOracle(self) {
    require(feeThefts.length == proofs.length, "OEL:invalid proofs");

    uint256 feeTheftsLen = feeThefts.length;
    for (uint256 i; i < feeTheftsLen; ) {
      _imprison(DATASTORE, feeThefts[i], proofs[i]);

      emit FeeTheft(feeThefts[i], proofs[i]);

      unchecked {
        i += 1;
      }
    }
  }

  /**
   * @custom:section                           ** CONTINUOUS UPDATES **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice Telescope reports all of the g-derivate prices with a new PRICE_MERKLE_ROOT.
   * Also reports all of the validator balances with a BALANCE_MERKLE_ROOT.
   * Then, updates the ORACLE_UPDATE_TIMESTAMP and MONOPOLY_THRESHOLD
   *
   * @param allValidatorsCount Number of all validators within BeaconChain, all of them.
   * Prevents monopolies.
   */
  function reportBeacon(
    StakeModuleStorage storage self,
    bytes32 priceMerkleRoot,
    bytes32 balanceMerkleRoot,
    uint256 allValidatorsCount
  ) external onlyOracle(self) {
    require(allValidatorsCount > MIN_VALIDATOR_COUNT, "OEL:low validator count");

    self.PRICE_MERKLE_ROOT = priceMerkleRoot;
    self.BALANCE_MERKLE_ROOT = balanceMerkleRoot;
    self.ORACLE_UPDATE_TIMESTAMP = block.timestamp;

    uint256 newThreshold = (allValidatorsCount * MONOPOLY_RATIO) / PERCENTAGE_DENOMINATOR;
    self.MONOPOLY_THRESHOLD = newThreshold;

    emit OracleReported(priceMerkleRoot, balanceMerkleRoot, newThreshold);
  }

  /**
   * @custom:section                           **  PRICE UPDATE **
   *
   * @dev Permissionless.
   */

  /**
   * @custom:visibility -> view-internal
   *
   * @dev in order to prevent faulty updates to the derivative prices there are boundaries to price updates.
   * 1. Price should not be increased more than DAILY_PRICE_INCREASE_LIMIT
   *  with the factor of how many days since priceUpdateTimestamp has past.
   * 2. Price should not be decreased more than DAILY_PRICE_DECREASE_LIMIT
   *  with the factor of how many days since priceUpdateTimestamp has past.
   *
   * @dev Worth noting, if price drops more than x%, UP TO (slashing percentage/x) days deposits/withdrawals are halted.
   * Example:
   * * A pool can have only one validator, it can get slashed.
   * * Lets say max decrease is 5%, and 50% is slashed.
   * * Then deposits/withdrawals are halted for 10 days.
   * This is not a bug, but a safe circuit-breaker.
   * This logic have effects the withdrawal contract logic.
   */
  function _sanityCheck(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 _id,
    uint256 _newPrice
  ) internal view {
    require(DATASTORE.readUint(_id, rks.TYPE) == ID_TYPE.POOL, "OEL:not a pool?");

    uint256 lastUpdate = self.gETH.priceUpdateTimestamp(_id);
    uint256 dayPercentSinceUpdate = ((block.timestamp - lastUpdate) * PERCENTAGE_DENOMINATOR) /
      1 days;

    uint256 curPrice = self.gETH.pricePerShare(_id);

    uint256 maxPriceIncrease = ((curPrice *
      self.DAILY_PRICE_INCREASE_LIMIT *
      dayPercentSinceUpdate) / PERCENTAGE_DENOMINATOR) / PERCENTAGE_DENOMINATOR;

    uint256 maxPriceDecrease = ((curPrice *
      self.DAILY_PRICE_DECREASE_LIMIT *
      dayPercentSinceUpdate) / PERCENTAGE_DENOMINATOR) / PERCENTAGE_DENOMINATOR;

    require(
      (_newPrice + maxPriceDecrease >= curPrice) && (_newPrice <= curPrice + maxPriceIncrease),
      "OEL:price is insane, price update is halted"
    );
  }

  /**
   * @custom:visibility -> internal
   *
   * @notice syncing the price of g-derivatives after checking the merkle proofs and the sanity of the price.
   * @param _price price of the derivative denominated in gETH.denominator()
   * @param _priceProof merkle proofs
   */
  function _priceSync(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 _poolId,
    uint256 _price,
    bytes32[] calldata _priceProof
  ) internal {
    require(
      self.ORACLE_UPDATE_TIMESTAMP > self.gETH.priceUpdateTimestamp(_poolId),
      "OEL:no price change"
    );

    bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_poolId, _price))));
    require(
      MerkleProof.verify(_priceProof, self.PRICE_MERKLE_ROOT, leaf),
      "OEL:NOT all proofs are valid"
    );

    _sanityCheck(self, DATASTORE, _poolId, _price);

    address yieldReceiver = DATASTORE.readAddress(_poolId, rks.yieldReceiver);

    if (yieldReceiver == address(0)) {
      self.gETH.setPricePerShare(_price, _poolId);
    } else {
      uint256 currentPrice = self.gETH.pricePerShare(_poolId);
      if (_price > currentPrice) {
        uint256 supplyDiff = ((_price - currentPrice) * self.gETH.totalSupply(_poolId)) /
          gETH_DENOMINATOR;
        self.gETH.mint(address(this), _poolId, supplyDiff, "");
        self.gETH.safeTransferFrom(address(this), yieldReceiver, _poolId, supplyDiff, "");
      } else {
        self.gETH.setPricePerShare(_price, _poolId);
      }
    }
  }

  /**
   * @custom:visibility -> external
   *
   * @notice external function to set a derivative price on Portal
   * @param price price of the derivative denominated in gETH.denominator()
   * @param priceProof merkle proofs
   */
  function priceSync(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProof
  ) external {
    _priceSync(self, DATASTORE, poolId, price, priceProof);
  }

  /**
   * @custom:visibility -> external
   *
   * @notice external function to set a multiple derivatives price at once, saves gas.
   * @param prices price of the derivative denominated in gETH.denominator()
   * @param priceProofs merkle proofs
   */
  function priceSyncBatch(
    StakeModuleStorage storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256[] calldata poolIds,
    uint256[] calldata prices,
    bytes32[][] calldata priceProofs
  ) external {
    require(poolIds.length == prices.length, "OEL:array lengths not equal");
    require(poolIds.length == priceProofs.length, "OEL:array lengths not equal");

    uint256 poolIdsLen = poolIds.length;
    for (uint256 i; i < poolIdsLen; ) {
      _priceSync(self, DATASTORE, poolIds[i], prices[i], priceProofs[i]);

      unchecked {
        i += 1;
      }
    }
  }
}
