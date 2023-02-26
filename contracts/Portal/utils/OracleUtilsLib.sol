// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {ID_TYPE, VALIDATOR_STATE, PERCENTAGE_DENOMINATOR} from "./globals.sol";

import {DataStoreUtils as DSU} from "./DataStoreUtilsLib.sol";
import {StakeUtils as SU} from "./StakeUtilsLib.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title OracleUtils Library: An extension to StakeUtils Library
 * @notice Oracle, named Telescope, handles some operations for The Staking Library,
 * * using the following logic, which is very simple.
 *
 * @dev Telescope is responsible from 3 tasks:
 * * Updating the on-chain price of all pools with a MerkleRoot
 * * Confirming validator proposals
 * * Regulating the Node Operators
 *
 * 1. reportOracle: Continous Data Flow: Price Merkle Root and MONOPOLY_THRESHOLD
 * * 1. Oracle Nodes calculates the price of its derivative,
 * * * according to the validator data such as balance and fees.
 * * 2. If a pool doesn't have a validator, price is kept the same.
 * * 3. A merkle tree is constructed with the order of allIdsByType array.
 * * 4. A watcher collects all the signatures from Multiple Oracle Nodes, and submits the merkle root.
 * * 5. Anyone can update the price of the derivative
 * * * by calling priceSync() functions with correct merkle proofs
 * * 6. Minting is allowed within PRICE_EXPIRY (24H) after the last price update.
 * * 7. Updates the regulation around Monopolies
 *
 * 2. updateVerificationIndex :Confirming validator proposals
 * * Simply, all proposed validator has an index bound to them,
 * * n representing the latest proposal: (0,n]
 * * Telescope verifies the validator data provided in proposeStake:
 * * especially sig1, sig31 and withdrawal credentials.
 * * Telescope confirms the latest index it verified and states the faulty validator proposals (aliens)
 * * If a validator proposal is faulty then it's state is set to 69.
 * * * 2 step process is essential to prevent the frontrunning
 * * * with a problematic withdrawalCredential, (https://bit.ly/3Tkc6UC)
 *
 * 3. regulateOperators: Regulating the Operators
 * * Operators can act faulty in many different ways. To prevent such actions,
 * * Telescope regulates them with well defined limitations.
 * * * Currently only issue is the fee theft, meaning operator have not
 * * * used the withdrawal contract for miner fees or MEV boost.
 * * * * There can be other restrictions in the future.
 *
 * @dev All 3 functions have OracleOnly modifier, priceSync functions do not.
 *
 * @dev first review DataStoreUtils
 * @dev then review StakeUtils
 */

library OracleUtils {
  /// @notice Using DataStoreUtils for IsolatedStorage struct
  using DSU for DSU.IsolatedStorage;

  /// @notice Using StakeUtils for PooledStaking struct
  using SU for SU.PooledStaking;

  /// @notice EVENTS
  event Alienated(bytes indexed pubkey);
  event VerificationIndexUpdated(uint256 validatorVerificationIndex);
  event FeeTheft(uint256 indexed id, bytes proofs);
  event OracleReported(bytes32 merkleRoot, uint256 monopolyThreshold);

  /// @notice effective on MONOPOLY_THRESHOLD, limiting the active validators, set to 1% at start.
  uint256 public constant MONOPOLY_RATIO = (1 * PERCENTAGE_DENOMINATOR) / 100;

  /// @notice sensible value for the total beacon chain validators, no reasoning.
  uint256 public constant MIN_VALIDATOR_COUNT = 50000;

  modifier onlyOracle(SU.PooledStaking storage STAKER) {
    require(msg.sender == STAKER.ORACLE_POSITION, "OU: sender NOT ORACLE");
    _;
  }

  /**
   * @notice                                     ** VERIFICATION INDEX **
   **/

  /**
   * @dev  ->  internal
   */

  /**
   * @notice "Alien" is a validator that is created with a faulty withdrawal
   * credential or signatures, this is a malicious act.
   * @notice Alienation results in imprisonment for the operator of the faulty validator proposal.
   * @dev While alienating a validator we should adjust the 'surplus' and 'secured'
   * balances of the pool accordingly
   * @dev We should adjust the 'totalProposedValidators', 'proposedValidators' to fix allowances.
   */
  function _alienateValidator(
    DSU.IsolatedStorage storage DATASTORE,
    SU.PooledStaking storage STAKER,
    bytes calldata _pk
  ) internal {
    require(
      STAKER._validators[_pk].state == VALIDATOR_STATE.PROPOSED,
      "OU: NOT all pubkeys are pending"
    );
    require(
      STAKER._validators[_pk].index <= STAKER.VERIFICATION_INDEX,
      "OU: unexpected index"
    );
    SU._imprison(DATASTORE, STAKER._validators[_pk].operatorId, _pk);

    uint256 poolId = STAKER._validators[_pk].poolId;
    DATASTORE.subUintForId(poolId, "secured", DCU.DEPOSIT_AMOUNT);
    DATASTORE.addUintForId(poolId, "surplus", DCU.DEPOSIT_AMOUNT);

    uint256 operatorId = STAKER._validators[_pk].operatorId;
    DATASTORE.subUintForId(operatorId, "totalProposedValidators", 1);
    DATASTORE.subUintForId(
      poolId,
      DSU.getKey(operatorId, "proposedValidators"),
      1
    );

    STAKER._validators[_pk].state = VALIDATOR_STATE.ALIENATED;

    emit Alienated(_pk);
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice Updating VERIFICATION_INDEX, signaling that it is safe to activate
   * the validator proposals with lower index than new VERIFICATION_INDEX
   * @param validatorVerificationIndex (inclusive) index of the highest validator that is verified to be activated
   * @param alienatedPubkeys faulty proposals within the range of new and old verification indexes.
   */
  function updateVerificationIndex(
    DSU.IsolatedStorage storage DATASTORE,
    SU.PooledStaking storage STAKER,
    uint256 validatorVerificationIndex,
    bytes[] calldata alienatedPubkeys
  ) external onlyOracle(STAKER) {
    require(
      STAKER.VALIDATORS_INDEX >= validatorVerificationIndex,
      "OU: high VERIFICATION_INDEX"
    );
    require(
      validatorVerificationIndex > STAKER.VERIFICATION_INDEX,
      "OU: low VERIFICATION_INDEX"
    );

    STAKER.VERIFICATION_INDEX = validatorVerificationIndex;

    for (uint256 i; i < alienatedPubkeys.length; ++i) {
      _alienateValidator(DATASTORE, STAKER, alienatedPubkeys[i]);
    }

    emit VerificationIndexUpdated(validatorVerificationIndex);
  }

  /**
   * @notice                                     ** REGULATING OPERATORS **
   */

  /**
   * @dev  ->  external
   */

  /**
   * @notice regulating operators, currently only regulation is towards fee theft, can add more stuff in the future.
   * @param feeThefts Operator ids who have stolen MEV or block rewards detected
   * @param proofs  BlockNumber, tx or any other referance as a proof
   * @dev Stuff here result in imprisonment
   */
  function regulateOperators(
    DSU.IsolatedStorage storage DATASTORE,
    SU.PooledStaking storage STAKER,
    uint256[] calldata feeThefts,
    bytes[] calldata proofs
  ) external onlyOracle(STAKER) {
    require(feeThefts.length == proofs.length, "OU: invalid proofs");
    for (uint256 i; i < feeThefts.length; ++i) {
      SU._imprison(DATASTORE, feeThefts[i], proofs[i]);

      emit FeeTheft(feeThefts[i], proofs[i]);
    }
  }

  /**
   * @notice                                     ** CONTINUOUS UPDATES **
   */

  /**
   * @dev  ->  external
   */

  /**
   * @notice Telescope reports all of the g-derivate prices with a new PRICE_MERKLE_ROOT.
   * Then, updates the ORACLE_UPDATE_TIMESTAMP and MONOPOLY_THRESHOLD
   * @param allValidatorsCount Number of all validators within BeaconChain, all of them.
   * Prevents monopolies.
   */
  function reportOracle(
    SU.PooledStaking storage STAKER,
    bytes32 priceMerkleRoot,
    uint256 allValidatorsCount
  ) external onlyOracle(STAKER) {
    require(
      allValidatorsCount > MIN_VALIDATOR_COUNT,
      "OU: low validator count"
    );

    STAKER.PRICE_MERKLE_ROOT = priceMerkleRoot;
    STAKER.ORACLE_UPDATE_TIMESTAMP = block.timestamp;

    uint256 newThreshold = (allValidatorsCount * MONOPOLY_RATIO) /
      PERCENTAGE_DENOMINATOR;
    STAKER.MONOPOLY_THRESHOLD = newThreshold;

    emit OracleReported(priceMerkleRoot, newThreshold);
  }

  /**
   * @notice                                     ** Updating PricePerShare **
   */

  /**
   * @dev  ->  internal
   */

  /**
   * @dev in order to prevent faulty updates to the derivative prices there are boundaries to price updates.
   * 1. Price should not be increased more than DAILY_PRICE_INCREASE_LIMIT
   *  with the factor of how many days since priceUpdateTimestamp has past.
   * 2. Price should not be decreased more than DAILY_PRICE_DECREASE_LIMIT
   *  with the factor of how many days since priceUpdateTimestamp has past.
   */
  function _sanityCheck(
    DSU.IsolatedStorage storage DATASTORE,
    SU.PooledStaking storage STAKER,
    uint256 _id,
    uint256 _newPrice
  ) internal view {
    require(
      DATASTORE.readUintForId(_id, "TYPE") == ID_TYPE.POOL,
      "OU: not a pool?"
    );

    uint256 lastUpdate = STAKER.gETH.priceUpdateTimestamp(_id);
    uint256 dayPercentSinceUpdate = ((block.timestamp - lastUpdate) *
      PERCENTAGE_DENOMINATOR) / 1 days;

    uint256 curPrice = STAKER.gETH.pricePerShare(_id);

    uint256 maxPrice = curPrice +
      ((curPrice * STAKER.DAILY_PRICE_INCREASE_LIMIT * dayPercentSinceUpdate) /
        PERCENTAGE_DENOMINATOR) /
      PERCENTAGE_DENOMINATOR;

    uint256 minPrice = curPrice -
      ((curPrice * STAKER.DAILY_PRICE_DECREASE_LIMIT * dayPercentSinceUpdate) /
        PERCENTAGE_DENOMINATOR /
        PERCENTAGE_DENOMINATOR);

    require(
      _newPrice >= minPrice && _newPrice <= maxPrice,
      "OU: price is insane"
    );
  }

  /**
   * @notice syncing the price of g-derivatives after checking the merkle proofs and the sanity of the price.
   * @param _price price of the derivative denominated in gETH.denominator()
   * @param _priceProof merkle proofs
   */
  function _priceSync(
    DSU.IsolatedStorage storage DATASTORE,
    SU.PooledStaking storage STAKER,
    uint256 _poolId,
    uint256 _price,
    bytes32[] calldata _priceProof
  ) internal {
    bytes32 leaf = keccak256(
      bytes.concat(keccak256(abi.encode(_poolId, _price)))
    );
    require(
      MerkleProof.verify(_priceProof, STAKER.PRICE_MERKLE_ROOT, leaf),
      "OU: NOT all proofs are valid"
    );

    _sanityCheck(DATASTORE, STAKER, _poolId, _price);

    STAKER.gETH.setPricePerShare(_price, _poolId);
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice external function to set a derivative price on Portal
   * @param price price of the derivative denominated in gETH.denominator()
   * @param priceProof merkle proofs
   */
  function priceSync(
    DSU.IsolatedStorage storage DATASTORE,
    SU.PooledStaking storage STAKER,
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProof
  ) external {
    _priceSync(DATASTORE, STAKER, poolId, price, priceProof);
  }

  /**
   * @notice external function to set a multiple derivatives price at once, saves gas.
   * @param prices price of the derivative denominated in gETH.denominator()
   * @param priceProofs merkle proofs
   */
  function priceSyncBatch(
    DSU.IsolatedStorage storage DATASTORE,
    SU.PooledStaking storage STAKER,
    uint256[] calldata poolIds,
    uint256[] calldata prices,
    bytes32[][] calldata priceProofs
  ) external {
    require(poolIds.length == prices.length);
    require(poolIds.length == priceProofs.length);
    for (uint256 i = 0; i < poolIds.length; ++i) {
      _priceSync(DATASTORE, STAKER, poolIds[i], prices[i], priceProofs[i]);
    }
  }
}
