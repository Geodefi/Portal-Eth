// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./DataStoreLib.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";
import "../../interfaces/IgETH.sol";

library OracleUtils {
    using DataStoreUtils for DataStoreUtils.DataStore;

    event Alienated(bytes pubkey, bool isAlien);
    event Busted(bytes pubkey, bool isBusted);
    event VerificationIndexUpdated(uint256 newIndex);

    /**
     * @param state 0: inactive, 1: proposed/cured validator, 2: active validator, 3: signaled/released withdrawal,
     4: withdrawn, 58: busted withdrawal, 69: alienated proposal (https://bit.ly/3Tkc6UC)
     * @param index representing this validators placement on the chronological order of the proposed validators
     * @param planetId needed for withdrawal_credential
     * @param operatorId needed for staking after allowence
     * @param signature BLS12-381 signature of the validator
     **/
    struct Validator {
        uint8 state;
        uint256 index;
        uint256 poolId;
        uint256 operatorId;
        uint256 poolFee;
        uint256 operatorFee;
        // bytes withdrawalCredential;
        bytes signature;
    }

    /**
     * @param ORACLE_POSITION https://github.com/Geodefi/Telescope-Eth
     * @param VERIFICATION_INDEX the highest index of the validators that are verified to be activated. Updated by Telescope. set to 0 at start
     * @param VALIDATORS_INDEX total number of validators that are proposed at some point. includes all states of validators. set to 0 at start
     **/
    struct Oracle {
        IgETH gETH;
        address ORACLE_POSITION;
        uint256 ORACLE_UPDATE_TIMESTAMP;
        uint256 MONOPOLY_THRESHOLD; // max number of validators an operator is allowed to operate.
        uint256 VALIDATORS_INDEX;
        uint256 VERIFICATION_INDEX;
        uint256 PERIOD_PRICE_INCREASE_LIMIT;
        uint256 PERIOD_PRICE_DECREASE_LIMIT;
        bytes32 PRICE_MERKLE_ROOT;
        mapping(bytes => Validator) Validators;
    }

    /// @notice Oracle is active for the first 30 min of every day
    uint256 public constant ORACLE_PERIOD = 1 days;
    uint256 public constant ORACLE_ACTIVE_PERIOD = 30 minutes;

    // as a percentage while PERCENTAGE_DENOMINATOR = 100%, set by governance
    uint256 public constant MONOPOLY_RATIO = (5 * PERCENTAGE_DENOMINATOR) / 100;
    uint256 public constant PRISON_SENTENCE = 7 days;

    /// @notice PERCENTAGE_DENOMINATOR represents 100%
    uint256 public constant PERCENTAGE_DENOMINATOR = 10**10;

    modifier onlyOracle(Oracle storage self) {
        require(
            msg.sender == self.ORACLE_POSITION,
            "OracleUtils: sender NOT ORACLE"
        );
        _;
    }

    /**
     * @notice                      ** HELPER functions **
     */
    function _getKey(uint256 _id, string memory _param)
        internal
        pure
        returns (bytes32)
    {
        return bytes32(keccak256(abi.encodePacked(_id, _param)));
    }

    /**
     * @notice Oracle is only allowed for a period every day & pool operations are stopped then
     * @return false if the last oracle update happened already (within the current daily period)
     */
    function _isOracleActive(Oracle storage self) internal view returns (bool) {
        return
            (block.timestamp % ORACLE_PERIOD <= ORACLE_ACTIVE_PERIOD) &&
            (self.ORACLE_UPDATE_TIMESTAMP <
                block.timestamp - ORACLE_ACTIVE_PERIOD);
    }

    /**
     * @notice              ** Regulating the Operators and PubKeys **
     */

    /**
     *  @notice Creation of a Validator takes 3 steps. Before entering beaconStake function,
     *  canStake verifies the eligibility of given pubKey that is proposed by an operator
     *  with Prestake function. Eligibility is defined by alienation, check alienate() for info.
     *
     *  @param pubkey BLS12-381 public key of the validator
     *  @return true if:
     *   - pubkey should be proposeStaked
     *   - validator's index should be lower than VERIFICATION_INDEX, updated by TELESCOPE
     *   - pubkey should not be alienated (https://bit.ly/3Tkc6UC)
     *  else:
     *      return false
     */
    function canStake(Oracle storage self, bytes calldata pubkey)
        public
        view
        returns (bool)
    {
        return
            self.Validators[pubkey].state == 1 &&
            self.Validators[pubkey].index <= self.VERIFICATION_INDEX;
    }

    function _alienateValidator(
        Oracle storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        bytes calldata pk
    ) internal {
        require(
            self.Validators[pk].state == 1,
            "OracleUtils: NOT all alienPubkeys are pending"
        );
        uint256 planetId = self.Validators[pk].poolId;
        _DATASTORE.subUintForId(planetId, "secured", DCU.DEPOSIT_AMOUNT);
        _DATASTORE.addUintForId(planetId, "surplus", DCU.DEPOSIT_AMOUNT);
        self.Validators[pk].state = 69;
        emit Alienated(pk, true);
    }

    function _cureValidator(
        Oracle storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        bytes calldata pk
    ) internal {
        require(
            self.Validators[pk].state == 69,
            "OracleUtils: NOT all curedPubkeys are alienated"
        );
        uint256 planetId = self.Validators[pk].poolId;
        if (
            _DATASTORE.readUintForId(planetId, "surplus") >=
            (DCU.DEPOSIT_AMOUNT)
        ) {
            _DATASTORE.addUintForId(planetId, "secured", DCU.DEPOSIT_AMOUNT);
            _DATASTORE.subUintForId(planetId, "surplus", DCU.DEPOSIT_AMOUNT);
            self.Validators[pk].state = 1;
            emit Alienated(pk, false);
        }
    }

    function _bustValidator(Oracle storage self, bytes calldata pk) internal {
        require(
            self.Validators[pk].state == 3,
            "OracleUtils: NOT all bustedPubkeys are signaled"
        );
        self.Validators[pk].state = 58;
        emit Busted(pk, true);
    }

    function _releaseValidator(Oracle storage self, bytes calldata pk)
        internal
    {
        require(
            self.Validators[pk].state == 58,
            "OracleUtils: NOT all releasedPubkeys are busted"
        );
        self.Validators[pk].state = 3;
        emit Busted(pk, false);
    }

    /**
     * @notice Updating VERIFICATION_INDEX, signaling that it is safe to allow
     * validators with lower index than VERIFICATION_INDEX to stake with staking pool funds.
     * @param newVerificationIndex index of the highest validator that is verified to be activated
     * @param regulatedPubkeys matrix of validator pubkeys that are lower than new_index which also
     * either frontrunned proposeStake function thus alienated OR proven to be mistakenly alienated.
     */
    function regulateOperators(
        Oracle storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 allValidatorsCount,
        uint256 newVerificationIndex,
        bytes[][] calldata regulatedPubkeys, //0: alienated, 1: cured, 2: busted, 3: released
        uint256[] calldata prisonedIds
    ) external onlyOracle(self) {
        require(!_isOracleActive(self), "OracleUtils: oracle is active");
        require(allValidatorsCount > 999, "OracleUtils: low validator count");
        require(
            self.VALIDATORS_INDEX >= newVerificationIndex,
            "OracleUtils: high VERIFICATION_INDEX"
        );
        require(
            newVerificationIndex >= self.VERIFICATION_INDEX,
            "OracleUtils: low VERIFICATION_INDEX"
        );
        require(
            regulatedPubkeys.length == 4,
            "OracleUtils: regulatedPubkeys length != 4"
        );

        for (uint256 a; a < regulatedPubkeys[0].length; a++) {
            _alienateValidator(self, _DATASTORE, regulatedPubkeys[0][a]);
        }

        for (uint256 c; c < regulatedPubkeys[1].length; ++c) {
            _cureValidator(self, _DATASTORE, regulatedPubkeys[1][c]);
        }

        for (uint256 b; b < regulatedPubkeys[2].length; b++) {
            _bustValidator(self, regulatedPubkeys[2][b]);
        }

        for (uint256 r; r < regulatedPubkeys[3].length; r++) {
            _releaseValidator(self, regulatedPubkeys[3][r]);
        }

        for (uint256 p; p < prisonedIds.length; ++p) {
            _DATASTORE.writeUintForId(
                prisonedIds[p],
                "released",
                block.timestamp + PRISON_SENTENCE
            );
            // event here
        }

        self.MONOPOLY_THRESHOLD =
            (allValidatorsCount * MONOPOLY_RATIO) /
            PERCENTAGE_DENOMINATOR;

        self.VERIFICATION_INDEX = newVerificationIndex;
        emit VerificationIndexUpdated(newVerificationIndex);
    }

    /**
     * @notice                          ** Updating PricePerShare **
     */

    /**
     * @notice in order to prevent attacks from malicious Oracle there are boundaries to price & fee updates.
     * @dev checks:
     * 1. Price should not be increased more than PERIOD_PRICE_INCREASE_LIMIT
     *  with the factor of how many days since oracleUpdateTimestamp has past.
     *  To encourage report oracle each day, price increase limit is not calculated by considering compound effect
     *  for multiple days.
     */
    function _sanityCheck(
        Oracle storage self,
        uint256 _id,
        uint256 periodsSinceUpdate,
        uint256 _newPrice
    ) internal view {
        uint256 curPrice = self.gETH.pricePerShare(_id);
        uint256 maxPrice = curPrice +
            ((curPrice *
                self.PERIOD_PRICE_INCREASE_LIMIT *
                periodsSinceUpdate) / PERCENTAGE_DENOMINATOR);
        require(_newPrice <= maxPrice, "OracleUtils: price is insane");

        uint256 minPrice = curPrice -
            ((curPrice *
                self.PERIOD_PRICE_DECREASE_LIMIT *
                periodsSinceUpdate) / PERCENTAGE_DENOMINATOR);
        require(_newPrice >= minPrice, "OracleUtils: price is insane");
    }

    function _priceSync(
        Oracle storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        bytes32[2] memory dailyBufferKeys,
        uint256 index,
        uint256 poolId,
        uint256 beaconBalance,
        uint256 periodsSinceUpdate, // calculation for this changes for private pools
        bytes32[] calldata priceProofs // uint256 prices[]
    ) internal {
        (uint256 oraclePrice, uint256 price) = _findPrices_ClearBuffer(
            self,
            _DATASTORE,
            dailyBufferKeys[0],
            dailyBufferKeys[1],
            poolId,
            beaconBalance
        );
        _sanityCheck(self, poolId, periodsSinceUpdate, oraclePrice);
        bytes32 node = keccak256(abi.encodePacked(index, poolId, oraclePrice));
        require(
            MerkleProof.verify(priceProofs, self.PRICE_MERKLE_ROOT, node),
            "MerkleDistributor: NOT all proofs are valid"
        );
        self.gETH.setPricePerShare(price, poolId);
    }

    function _findPrices_ClearBuffer(
        Oracle storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        bytes32 dailyBufferMintKey,
        bytes32 dailyBufferBurnKey,
        uint256 poolId,
        uint256 beaconBalance
    ) internal returns (uint256, uint256) {
        uint256 totalEther = beaconBalance +
            _DATASTORE.readUintForId(poolId, "secured") +
            _DATASTORE.readUintForId(poolId, "surplus");

        uint256 supply = self.gETH.totalSupply(poolId);
        uint256 price = self.gETH.pricePerShare(poolId);
        uint256 unbufferedEther = totalEther -
            (_DATASTORE.readUintForId(poolId, dailyBufferMintKey) * price) /
            self.gETH.totalSupply(poolId);

        unbufferedEther +=
            (_DATASTORE.readUintForId(poolId, dailyBufferBurnKey) * price) /
            self.gETH.denominator();

        uint256 unbufferedSupply = supply -
            _DATASTORE.readUintForId(poolId, dailyBufferMintKey);

        unbufferedSupply += _DATASTORE.readUintForId(
            poolId,
            dailyBufferBurnKey
        );

        // clears daily buffer for the gas refund
        _DATASTORE.writeUintForId(poolId, dailyBufferMintKey, 0);
        _DATASTORE.writeUintForId(poolId, dailyBufferBurnKey, 0);
        return (totalEther / supply, unbufferedEther / unbufferedSupply);
    }

    function reportOracle(
        Oracle storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        bytes32 merkleRoot,
        uint256[] calldata beaconBalances,
        bytes32[][] calldata priceProofs
    ) external onlyOracle(self) {
        require(_isOracleActive(self), "OracleUtils: oracle is NOT active");
        {
            uint256 planetCount = _DATASTORE.allIdsByType[5].length;
            require(
                beaconBalances.length == planetCount,
                "OracleUtils: incorrect beaconBalances length"
            );
            require(
                priceProofs.length == planetCount,
                "OracleUtils: incorrect priceProofs length"
            );
        }

        self.PRICE_MERKLE_ROOT = merkleRoot;

        uint256 periodsSinceUpdate = (block.timestamp +
            ORACLE_ACTIVE_PERIOD -
            self.ORACLE_UPDATE_TIMESTAMP) / ORACLE_PERIOD;

        bytes32[2] memory dailyBufferKeys = [
            _getKey(
                block.timestamp - (block.timestamp % ORACLE_PERIOD),
                "mintBuffer"
            ),
            _getKey(
                block.timestamp - (block.timestamp % ORACLE_PERIOD),
                "burnBuffer"
            )
        ];

        for (uint256 i = 0; i < beaconBalances.length; i++) {
            _priceSync(
                self,
                _DATASTORE,
                dailyBufferKeys,
                i,
                _DATASTORE.allIdsByType[5][i],
                beaconBalances[i],
                periodsSinceUpdate,
                priceProofs[i]
            );
        }
        self.ORACLE_UPDATE_TIMESTAMP =
            block.timestamp -
            (block.timestamp % ORACLE_PERIOD);
    }
}
