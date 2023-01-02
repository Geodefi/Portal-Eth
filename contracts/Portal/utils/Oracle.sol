// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./DataStoreUtilsLib.sol";
import "./Stake.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";
import "../../interfaces/IgETH.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title OracleUtils library to be used within stakeUtils
 * @notice Oracle, named Telescope, is responsible from 2 tasks:
 * * regulating the validator creations and exits
 * * syncs the price of all pools with merkleroot
 *
 * Regulating the validators/operators:
 * * state 1: validators is proposed since enough allowence is given from pool maintainers, 1 ETH is locked from maintainerWallet
 * * state 2: stake was approved by Oracle, operator used user funds to activate the validator, 1 ETH is released
 * * state 69: validator was malicious(alien), probably front-runned with a problematic withdrawalCredential, (https://bit.ly/3Tkc6UC)
 * * state 3: validator is exited. However, if the signal turns out to be false, then Telescope reports and sets to state 2, prisoning the operator.
 * * * Reports the Total number of Beacon validators to make sure no operator is running more validators then they should within Geode Universe.
 *
 *
 * Syncing the Prices:
 * * Telescope works the first 30 minutes of every day(GMT), with an archive node that points the first second.
 * * Catches the beacon chain balances and decreases the fees, groups them by ids
 * * Creates a merkle root, by simply calculating all prices from every pool, either private or public
 * * Verifies merkle root with price proofs of all public pools.
 * * * Private pools need to verify their own price once a day, otherwise minting is not allowed.
 * * * * This is why merkle root of all prices is needed
 *
 * @dev Prisoned Validator:
 * * 1. created a malicious validator(alien)
 * * 2. withdrawn without a signal
 * * 3. signaled but not withdrawn
 * * 4. did not respect the validatorPeriod
 *
 * @dev ALL "fee" variables are limited by PERCENTAGE_DENOMINATOR = 100%
 * Note refer to DataStoreUtils before reviewing
 */

library OracleUtils {
    using DataStoreUtils for DataStoreUtils.DataStore;
    using StakeUtils for StakeUtils.StakePool;

    /**
     * @param ORACLE_POSITION https://github.com/Geodefi/Telescope-Eth
     * @param ORACLE_UPDATE_TIMESTAMP the timestamp of the latest oracle update
     * @param PERIOD_PRICE_INCREASE_LIMIT limiting the price increases for one oracle period, 24h. Effective for any time interval
     * @param PERIOD_PRICE_DECREASE_LIMIT limiting the price decreases for one oracle period, 24h. Effective for any time interval
     * @param PRICE_MERKLE_ROOT merkle root of the prices of every pool, planet or comet
     * @param __gap keep the struct size at 16
     **/
    struct Oracle {
        address ORACLE_POSITION;
        uint256 ORACLE_UPDATE_TIMESTAMP;
        uint256 PERIOD_PRICE_INCREASE_LIMIT;
        uint256 PERIOD_PRICE_DECREASE_LIMIT;
        bytes32 PRICE_MERKLE_ROOT;
        uint256[6] __gap;
    }

    /// @notice PERCENTAGE_DENOMINATOR represents 100%
    uint256 public constant PERCENTAGE_DENOMINATOR = 10**10;

    /// @notice Oracle is active for the first 30 min of every day
    uint256 public constant ORACLE_PERIOD = 1 days;
    uint256 public constant ORACLE_ACTIVE_PERIOD = 30 minutes;

    /// @notice effective on MONOPOLY_THRESHOLD, limiting the active validators, set to 5% at start.
    uint256 public constant MONOPOLY_RATIO = (5 * PERCENTAGE_DENOMINATOR) / 100;

    /// @notice limiting some abilities of Operators in case of bad behaviour
    uint256 public constant PRISON_SENTENCE = 30 days;

    modifier onlyOracle(Oracle storage self) {
        require(
            msg.sender == self.ORACLE_POSITION,
            "OracleUtils: sender NOT ORACLE"
        );
        _;
    }

    /**
     * @notice Oracle is only allowed for a period every day & some operations are stopped then
     * @return false if the last oracle update happened already (within the current daily period)
     */
    function _isOracleActive(Oracle storage self) internal view returns (bool) {
        return
            (block.timestamp % ORACLE_PERIOD <= ORACLE_ACTIVE_PERIOD) &&
            (self.ORACLE_UPDATE_TIMESTAMP <
                block.timestamp - ORACLE_ACTIVE_PERIOD);
    }

    /**
     * @notice Checks if the given operator is Prisoned
     * @dev "released" key refers to the end of the last imprisonment, the limit on the abilities of operator is lifted then
     */
    function isPrisoned(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _operatorId
    ) internal view returns (bool _isPrisoned) {
        _isPrisoned =
            block.timestamp <= DATASTORE.readUintForId(_operatorId, "released");
    }

    /**
     * @notice releases an imprisoned operator immidately
     * @dev in different situations such as a faulty improsenment or coordinated testing periods
     * * Governance can vote on releasing the prisoners
     * @dev onlyGovernance check is in Portal
     */
    function releasePrisoned(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 operatorId
    ) external {
        require(
            isPrisoned(DATASTORE, operatorId),
            "OracleUtils: NOT in prison"
        );
        DATASTORE.writeUintForId(operatorId, "released", block.timestamp);
        // emit Released(operatorId);
    }

    /**
     * @notice Put an operator in prison, "release" points to the date the operator will be out
     */
    function imprison(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _operatorId
    ) internal {
        DATASTORE.writeUintForId(
            _operatorId,
            "released",
            block.timestamp + PRISON_SENTENCE
        );
        // emit Prisoned(_operatorId, block.timestamp + PRISON_SENTENCE);
    }

    /**
     * @notice allows improsening an Operator if the validator have not been exited until expectedExit
     * @dev anyone can call this function
     * @dev if operator has given enough allowence, they can rotate the validators to avoid being prisoned
     */
    function blameOperator(
        DataStoreUtils.DataStore storage DATASTORE,
        StakeUtils.StakePool storage STAKE,
        bytes calldata pk
    ) external {
        if (
            block.timestamp > STAKE._validators[pk].expectedExit &&
            STAKE._validators[pk].state == 2
        ) {
            imprison(DATASTORE, STAKE._validators[pk].operatorId);
        }
    }

    /**
     * @notice An "Alien" is a validator that is created with a false withdrawal credential, this is a malicious act.
     * @dev imprisonates the operator who proposed a malicious validator.
     */
    function _alienateValidator(
        Oracle storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        StakeUtils.StakePool storage STAKE,
        bytes calldata _pk
    ) internal {
        require(
            STAKE._validators[_pk].state == 1,
            "OracleUtils: NOT all alienPubkeys are pending"
        );
        uint256 planetId = STAKE._validators[_pk].poolId;
        DATASTORE.subUintForId(planetId, "secured", DCU.DEPOSIT_AMOUNT);
        DATASTORE.addUintForId(planetId, "surplus", DCU.DEPOSIT_AMOUNT);
        STAKE._validators[_pk].state = 69;

        imprison(DATASTORE, STAKE._validators[_pk].operatorId);
        // emit Alienated(_pk);
    }

    /**
     * @notice "Busting" refers to a false signal, meaning there is a signal but no Unstake
     * @dev imprisonates the operator who signaled a fake Unstake
     */
    function _bustSignal(
        Oracle storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        StakeUtils.StakePool storage STAKE,
        bytes calldata _pk
    ) internal {
        require(
            STAKE._validators[_pk].state == 3,
            "OracleUtils: pubkey is NOT signaled"
        );
        STAKE._validators[_pk].state = 2;

        imprison(DATASTORE, STAKE._validators[_pk].operatorId);
        // emit Busted(_pk);
    }

    /**
     * @notice "Busting" refers to unsignaled withdrawal, meaning there is an unstake but no Signal
     * @dev imprisonates the operator who haven't signal the unstake
     */
    function _bustExit(
        Oracle storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        StakeUtils.StakePool storage STAKE,
        bytes calldata _pk
    ) internal {
        require(
            STAKE._validators[_pk].state == 2,
            "OracleUtils: Signaled, cannot be busted"
        );
        STAKE._validators[_pk].state = 3;

        imprison(DATASTORE, STAKE._validators[_pk].operatorId);
        // emit Busted(_pk);
    }

    /**
     * @notice Updating VERIFICATION_INDEX, signaling that it is safe to allow
     * validators with lower index than VERIFICATION_INDEX to stake with staking pool funds
     * @param allValidatorsCount total number of validators to figure out what is the current Monopoly Requirement
     * @param validatorVerificationIndex index of the highest validator that is verified to be activated
     * @param alienatedPubkeys proposals with lower index than new_index who frontrunned proposeStake
     * with incorrect withdrawal credential results in imprisonment.
     */
    function updateVerificationIndex(
        // MOVE THIS PROCESS TO STAKE...
        Oracle storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        StakeUtils.StakePool storage STAKE,
        uint256 allValidatorsCount,
        uint256 validatorVerificationIndex,
        bytes[] calldata alienatedPubkeys
    ) external onlyOracle(self) {
        require(!_isOracleActive(self), "OracleUtils: oracle is active");
        require(allValidatorsCount > 4999, "OracleUtils: low validator count");
        // require(
        //     self.VALIDATORS_INDEX >= validatorVerificationIndex,
        //     "OracleUtils: high VERIFICATION_INDEX"
        // );
        // require(
        //     validatorVerificationIndex >= self.VERIFICATION_INDEX,
        //     "OracleUtils: low VERIFICATION_INDEX"
        // );
        // self.VERIFICATION_INDEX = validatorVerificationIndex;

        for (uint256 i; i < alienatedPubkeys.length; i++) {
            // _alienateValidator(self, DATASTORE, alienatedPubkeys[i]);
        }

        STAKE.MONOPOLY_THRESHOLD =
            (allValidatorsCount * MONOPOLY_RATIO) /
            PERCENTAGE_DENOMINATOR;

        // emit VerificationIndexUpdated(validatorVerificationIndex);
    }

    /**
     * @notice regulating operators within Geode with verifiable proofs
     * @param bustedExits validators that have not signaled before Unstake
     * @param bustedSignals validators that are "mistakenly:)" signaled but not Unstaked
     * @param feeThefts [0]: Operator ids who have stolen MEV or block rewards, [1]: detected BlockNumber as proof
     * @dev Both of these functions results in imprisonment.
     */
    function regulateOperators(
        Oracle storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        StakeUtils.StakePool storage STAKE,
        bytes[] calldata bustedExits,
        bytes[] calldata bustedSignals,
        uint256[2][] calldata feeThefts
    ) external onlyOracle(self) {
        require(!_isOracleActive(self), "OracleUtils: oracle is active");

        for (uint256 i; i < bustedExits.length; i++) {
            _bustExit(self, DATASTORE, STAKE, bustedExits[i]);
        }

        for (uint256 j; j < bustedSignals.length; j++) {
            _bustSignal(self, DATASTORE, STAKE, bustedSignals[j]);
        }
        for (uint256 k; k < feeThefts.length; k++) {
            imprison(DATASTORE, feeThefts[k][0]);
            // emit FeeTheft(feeThefts[k][0], feeThefts[k][1]);
        }
    }

    /**
     * @notice                          ** Updating PricePerShare **
     */

    /**
     * @notice calculates the current price and expected report price
     * @dev surplus at the oracle time is found with the help of mint and burn buffers
     * @param _dailyBufferMintKey represents the gETH minted during oracleActivePeriod, unique to every day
     * @param _dailyBufferBurnKey represents the gETH burned during oracleActivePeriod, unique to every day
     * @dev calculates the totalEther amount, decreases the amount minted while oracle was working (first 30m),
     * finds the expected Oracle price by totalEther / supply , finds the current price by unbufferedEther / unbufferedSupply
     */
    function _findPricesClearBuffer(
        Oracle storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        StakeUtils.StakePool storage STAKE,
        bytes32 _dailyBufferMintKey,
        bytes32 _dailyBufferBurnKey,
        uint256 _poolId,
        uint256 _beaconBalance
    ) internal returns (uint256, uint256) {
        uint256 totalEther = _beaconBalance +
            DATASTORE.readUintForId(_poolId, "secured") +
            DATASTORE.readUintForId(_poolId, "surplus");

        uint256 denominator = STAKE.gETH.denominator();
        uint256 unbufferedEther;

        {
            uint256 price = STAKE.gETH.pricePerShare(_poolId);
            unbufferedEther =
                totalEther -
                (DATASTORE.readUintForId(_poolId, _dailyBufferMintKey) *
                    price) /
                denominator;

            unbufferedEther +=
                (DATASTORE.readUintForId(_poolId, _dailyBufferBurnKey) *
                    price) /
                denominator;
        }

        uint256 supply = STAKE.gETH.totalSupply(_poolId);

        uint256 unbufferedSupply = supply -
            DATASTORE.readUintForId(_poolId, _dailyBufferMintKey);

        unbufferedSupply += DATASTORE.readUintForId(
            _poolId,
            _dailyBufferBurnKey
        );

        // clears daily buffer for the gas refund
        DATASTORE.writeUintForId(_poolId, _dailyBufferMintKey, 0);
        DATASTORE.writeUintForId(_poolId, _dailyBufferBurnKey, 0);

        return (
            (unbufferedEther * denominator) / unbufferedSupply,
            (totalEther * denominator) / supply
        );
    }

    /**
     * @dev in order to prevent attacks from malicious Oracle there are boundaries to price & fee updates.
     * 1. Price should not be increased more than PERIOD_PRICE_INCREASE_LIMIT
     *  with the factor of how many days since oracleUpdateTimestamp has past.
     * 2. Price should not be decreased more than PERIOD_PRICE_DECREASE_LIMIT
     *  with the factor of how many days since oracleUpdateTimestamp has past.
     */
    function _sanityCheck(
        Oracle storage self,
        StakeUtils.StakePool storage STAKE,
        uint256 _id,
        uint256 _periodsSinceUpdate,
        uint256 _newPrice
    ) internal view {
        uint256 curPrice = STAKE.gETH.pricePerShare(_id);
        uint256 maxPrice = curPrice +
            ((curPrice *
                self.PERIOD_PRICE_INCREASE_LIMIT *
                _periodsSinceUpdate) / PERCENTAGE_DENOMINATOR);

        uint256 minPrice = curPrice -
            ((curPrice *
                self.PERIOD_PRICE_DECREASE_LIMIT *
                _periodsSinceUpdate) / PERCENTAGE_DENOMINATOR);

        require(
            _newPrice >= minPrice && _newPrice <= maxPrice,
            "OracleUtils: price is insane"
        );
    }

    /**
     * @notice syncing the price of g-derivative after checking the merkle proofs and the sanity of it.
     * @param _beaconBalance the total balance -excluding fees- of all validators of this pool
     * @param _periodsSinceUpdate time(s) since the last update of the g-derivative's price.
     * while public pools are using ORACLE_UPDATE_TIMESTAMP, private pools will refer gEth.priceUpdateTimestamp()
     * @param _priceProofs the merkle proof of the latests prices that are reported by Telescope
     * @dev if merkle proof holds the oracle price, new price is the current price of the derivative
     */
    function _priceSync(
        Oracle storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        StakeUtils.StakePool storage STAKE,
        bytes32[2] memory _dailyBufferKeys,
        uint256 _poolId,
        uint256 _beaconBalance,
        uint256 _periodsSinceUpdate, // calculation for this changes for private pools
        bytes32[] calldata _priceProofs // uint256 prices[]
    ) internal {
        (uint256 oraclePrice, uint256 price) = _findPricesClearBuffer(
            self,
            DATASTORE,
            STAKE,
            _dailyBufferKeys[0],
            _dailyBufferKeys[1],
            _poolId,
            _beaconBalance
        );
        _sanityCheck(self, STAKE, _poolId, _periodsSinceUpdate, oraclePrice);
        bytes32 node = keccak256(abi.encodePacked(_poolId, oraclePrice));

        require(
            MerkleProof.verify(_priceProofs, self.PRICE_MERKLE_ROOT, node),
            "OracleUtils: NOT all proofs are valid"
        );

        STAKE.gETH.setPricePerShare(price, _poolId);
    }

    /**
     * @notice Telescope reports all of the g-derivate prices with a new PRICE_MERKLE_ROOT
     * @notice after report updates the prices of the public pools
     * @notice updates the ORACLE_UPDATE_TIMESTAMP
     * @dev if merkle proof holds the oracle price, new price is the found price of the derivative
     */
    function reportOracle(
        Oracle storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        bytes32 merkleRoot,
        uint256[] calldata beaconBalances,
        bytes32[][] calldata priceProofs
    ) external onlyOracle(self) {
        require(_isOracleActive(self), "OracleUtils: oracle is NOT active");

        uint256 planetCount = DATASTORE.allIdsByType[5].length;
        require(
            beaconBalances.length == planetCount,
            "OracleUtils: incorrect beaconBalances length"
        );
        require(
            priceProofs.length == planetCount,
            "OracleUtils: incorrect priceProofs length"
        );

        self.PRICE_MERKLE_ROOT = merkleRoot;

        // // // we dont do this here anymore.
        // uint256 periodsSinceUpdate = (block.timestamp +
        //     ORACLE_ACTIVE_PERIOD -
        //     self.ORACLE_UPDATE_TIMESTAMP) / ORACLE_PERIOD;

        // // // refering the first second of the period: block.timestamp - (block.timestamp % ORACLE_PERIOD)
        // // bytes32[2] memory dailyBufferKeys = [
        // //     DataStoreUtils.getKey(
        // //         block.timestamp - (block.timestamp % ORACLE_PERIOD),
        // //         "mintBuffer"
        // //     ),
        // //     DataStoreUtils.getKey(
        // //         block.timestamp - (block.timestamp % ORACLE_PERIOD),
        // //         "burnBuffer"
        // //     )
        // // ];

        // // for (uint256 i = 0; i < beaconBalances.length; i++) {
        // //     _priceSync(
        // //         self,
        // //         DATASTORE,
        // //         dailyBufferKeys,
        // //         DATASTORE.allIdsByType[5][i],
        // //         beaconBalances[i],
        // //         periodsSinceUpdate,
        // //         priceProofs[i]
        // //     );
        // // }
        self.ORACLE_UPDATE_TIMESTAMP =
            block.timestamp -
            (block.timestamp % ORACLE_PERIOD);
    }
}
