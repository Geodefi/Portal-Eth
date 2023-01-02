// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./DataStoreUtilsLib.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";
// import "./OracleUtilsLib.sol";
import "../../interfaces/IgETH.sol";
import "../../interfaces/IMiniGovernance.sol";
import "../../interfaces/ISwap.sol";
import {IERC20InterfacePermitUpgradable as IgETHInterface} from "../../interfaces/IERC20InterfacePermitUpgradable.sol";
import "../../interfaces/ISwap.sol";
import "../../interfaces/ILPToken.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title StakeUtils library
 * @notice Exclusively contains functions related to ETH Liquid Staking design
 * @notice biggest part of the functionality is related to Dynamic Staking Pools
 * which relies on continuous buybacks (DWP) to maintain the price health with debt/surplus calculations
 * @dev Contracts relying on this library must initialize StakeUtils.StakePool
 * @dev ALL "fee" variables are limited by PERCENTAGE_DENOMINATOR.
 * * For example, when fee is equal to PERCENTAGE_DENOMINATOR/2, it means 50% of the fee
 * Note refer to DataStoreUtils before reviewing
 * Note refer to MaintainerUtilsLib before reviewing
 * Note refer to OracleUtilsLib before reviewing
 * Note *suggested* refer to GeodeUtils before reviewing
 * Note beware of the staking pool and operator implementations:
 *
 * Type 4 stands for Operators:
 * They maintain Beacon Chain Validators on behalf of Planets and Comets
 * * only if they are allowed to
 * Operators have properties like fee(as a percentage), maintainer.
 *
 * Type 5 stands for Public Staking Pool (Planets):
 * * Every Planet is also an Operator by design.
 * * * Planets inherits Operator functionalities and parameters, with additional
 * * * properties related to miniGovernances and staking pools - surplus, secured, liquidityPool etc.
 * * ID of a pool represents an id of gETH.
 * * For now, creation of staking pools are not permissionless but the usage of it is.
 * * * Meaning Everyone can stake and unstake using public pools.
 *
 * Type 6 stands for Staking Pools (Comets):
 * * It is permissionless, one can directly create a Comet by simply
 * * * choosing a name and sending MIN_AMOUNT which is expected to be 32 ether.
 * * GeodeUtils generates IDs based on types, meaning same name can be used for a Planet and a Comet simultaneously.
 * * The creation process is permissionless but staking is not.
 * * * Meaning Only Comet's maintainer can stake but everyone can hold the derivative
 * * In Comets, there is a Withdrawal Queue instead of DWP.
 * * NOT IMPLEMENTED YET
 *
 * Type 11 stands for a new Mini Governance implementation id:
 * * like always CONTROLLER is the implementation contract position
 * * requires the approval of Senate
 * * Pools are in "Isolation Mode" until their mini governance is upgraded to given proposal ID.
 * * * Meaning, no more Depositing or Staking can happen.
 */

library StakeUtils {
    using DataStoreUtils for DataStoreUtils.DataStore;

    /**
     * @param state 0: inactive, 1: proposed/cured validator, 2: active validator, 3: exited,  69: alienated proposal
     * @param index representing this validators placement on the chronological order of the proposed validators
     * @param planetId needed for withdrawal_credential
     * @param operatorId needed for staking after allowence
     * @param poolFee percentage of the rewards that will got to pool's maintainer, locked when the validator is created
     * @param operatorFee percentage of the rewards that will got to operator's maintainer, locked when the validator is created
     * @param createdAt the timestamp pointing the proposal to create a validator with given pubkey.
     * @param expectedExit expected timestamp of the exit of validator. Calculated with operator["validatorPeriod"]
     * @param signature BLS12-381 signature of the validator
     **/
    struct Validator {
        uint8 state;
        uint256 index;
        uint256 poolId;
        uint256 operatorId;
        uint256 poolFee;
        uint256 operatorFee;
        uint256 createdAt;
        uint256 expectedExit;
        bytes signature;
    }
    /**
     * @param MONOPOLY_THRESHOLD max number of validators 1 operator is allowed to operate, updated daily by oracle
     * @param VERIFICATION_INDEX the highest index of the validators that are verified ( to be not alien ) by Telescope. Updated by Telescope.
     **/
    struct StakePool {
        IgETH gETH;
        // OracleUtils.Oracle TELESCOPE;
        uint256 MAX_MAINTAINER_FEE;
        uint256 MINI_GOVERNANCE_VERSION;
        uint256 VALIDATORS_INDEX;
        uint256 VERIFICATION_INDEX;
        uint256 MONOPOLY_THRESHOLD;
        address DEFAULT_gETH_INTERFACE;
        address DEFAULT_LP;
        address DEFAULT_LP_TOKEN;
        mapping(bytes => Validator) _validators;
        uint256[5] __gap;
    }

    /**
     * @notice                      ** Constants **
     */

    /// @notice PERCENTAGE_DENOMINATOR represents 100%
    uint256 public constant PERCENTAGE_DENOMINATOR = 10**10;

    /// @notice limiting the operator.validatorPeriod, between 3 months to 5 years
    uint256 public constant MIN_VALIDATOR_PERIOD = 90 days;
    uint256 public constant MAX_VALIDATOR_PERIOD = 1825 days;

    /// @notice ignoring any buybacks if the DWP has a low debt
    uint256 public constant IGNORABLE_DEBT = 1 ether;

    /// @notice when a maintainer changes the fee, it is effective after a delay
    uint256 public constant SWITCH_LATENCY = 3 days;

    /// @notice default DWP parameters
    uint256 public constant DEFAULT_A = 60;
    uint256 public constant DEFAULT_FEE = (4 * PERCENTAGE_DENOMINATOR) / 10000;
    uint256 public constant DEFAULT_ADMIN_FEE =
        (5 * PERCENTAGE_DENOMINATOR) / 10;

    /**
     * @notice                      ** gETH specific functions **
     */

    /**
     * @notice sets a erc1155Interface for gETH
     * @param _interface address of the new gETH ERC1155 interface for given ID
     * @dev every interface has a unique index within "interfaces" dynamic array.
     * * even if unsetted, it just replaces the implementation with address(0) for obvious security reasons
     */
    function _setInterface(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        address _interface
    ) internal {
        uint256 interfacesLength = DATASTORE.readUintForId(
            id,
            "interfacesLength"
        );
        require(
            !self.gETH.isInterface(_interface, id),
            "StakeUtils: already interface"
        );
        DATASTORE.writeAddressForId(
            id,
            DataStoreUtils.getKey(interfacesLength, "interfaces"),
            _interface
        );
        DATASTORE.addUintForId(id, "interfacesLength", 1);
        self.gETH.setInterface(_interface, id, true);
    }

    /**
     * @notice lists all interfaces, unsetted interfaces will return address(0)
     */
    function allInterfaces(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external view returns (address[] memory) {
        uint256 interfacesLength = DATASTORE.readUintForId(
            id,
            "interfacesLength"
        );
        address[] memory interfaces = new address[](interfacesLength);
        for (uint256 i = 0; i < interfacesLength; i++) {
            interfaces[i] = DATASTORE.readAddressForId(
                id,
                DataStoreUtils.getKey(i, "interfaces")
            );
        }
        return interfaces;
    }

    /**
     * @notice                      ** Maintainer Functionalities **
     */

    /**
     * @notice Initiators
     */

    /**
     * @notice initiates ID as an node operator
     * @dev requires ID to be approved as a node operator with a specific CONTROLLER
     * @param validatorPeriod the expected maximum staking interval. This value should between
     * * MIN_VALIDATOR_PERIOD and MAX_VALIDATOR_PERIOD values defined as constants above,
     * * this check is done inside updateValidatorPeriod function.
     * Operator can unstake at any given point before this period ends.
     * If operator disobeys this rule, it can be prisoned with blameOperator()
     */
    function initiateOperator(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        uint256 fee,
        address maintainer,
        uint256 validatorPeriod
    ) external {
        require(
            DATASTORE.readUintForId(id, "initiated") == 0,
            "StakeUtils: already initiated"
        );

        require(
            msg.sender == DATASTORE.readAddressForId(id, "CONTROLLER"),
            "StakeUtils: NOT CONTROLLER"
        );
        require(
            DATASTORE.readUintForId(id, "TYPE") == 4,
            "StakeUtils: NOT correct TYPE"
        );

        require(
            fee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        require(
            validatorPeriod >= MIN_VALIDATOR_PERIOD,
            "StakeUtils: should be more than MIN_VALIDATOR_PERIOD"
        );
        require(
            validatorPeriod <= MAX_VALIDATOR_PERIOD,
            "StakeUtils: should be less than MAX_VALIDATOR_PERIOD"
        );

        DATASTORE.writeAddressForId(id, "maintainer", maintainer);
        DATASTORE.writeUintForId(id, "initiated", block.timestamp);
        DATASTORE.writeUintForId(id, "released", block.timestamp);
        DATASTORE.writeUintForId(id, "fee", fee);
        DATASTORE.writeUintForId(id, "validatorPeriod", validatorPeriod);

        // emit IdInitiated(id, 4);
    }

    /**
     * configurable: ERC20, private or public, liquidity pool
     * this should somehow be made into permissionless... (CONTROLLER, NAME, TYPE)
     */
    function initiatePool(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 fee,
        address CONTROLLER,
        bytes calldata NAME,
        string[2] calldata _interfaceSpecs,
        bool[3] calldata config
    ) external {
        uint256 id = uint256(keccak256(abi.encodePacked(NAME, uint256(4))));
        require(
            DATASTORE.readUintForId(id, "initiated") == 0,
            "MaintainerUtils: already initiated"
        );

        require(
            fee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );

        require(CONTROLLER != address(0), "StakeUtils: invalid CONTROLLER");

        DATASTORE.writeBytesForId(id, "NAME", NAME);
        DATASTORE.writeAddressForId(id, "CONTROLLER", CONTROLLER);
        DATASTORE.writeUintForId(id, "TYPE", 5);

        _deployMiniGovernance(self, DATASTORE, id);
        if (config[1]) _deployInterface(self, DATASTORE, id, _interfaceSpecs);
        if (config[2]) _deployLiquidityPool(self, DATASTORE, id);

        DATASTORE.writeUintForId(id, "public", config[0] ? 1 : 0);
        DATASTORE.writeAddressForId(id, "maintainer", CONTROLLER);
        DATASTORE.writeUintForId(id, "fee", fee);
        DATASTORE.writeUintForId(id, "initiated", block.timestamp);
    }

    /**
     * @notice deploys a mini governance contract that will be used as a withdrawal credential
     * using the last approved MINI_GOVERNANCE_VERSION
     */
    function _deployMiniGovernance(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id
    ) internal {
        address miniGovernance = address(
            new ERC1967Proxy(
                DATASTORE.readAddressForId(
                    self.MINI_GOVERNANCE_VERSION,
                    "CONTROLLER"
                ),
                abi.encodeWithSelector(
                    IMiniGovernance(address(0)).initialize.selector,
                    self.gETH,
                    address(this),
                    DATASTORE.readAddressForId(_id, "CONTROLLER"),
                    _id,
                    self.MINI_GOVERNANCE_VERSION
                )
            )
        );

        DATASTORE.writeAddressForId(_id, "miniGovernance", miniGovernance);

        DATASTORE.writeBytesForId(
            _id,
            "withdrawalCredential",
            DCU.addressToWC(miniGovernance)
        );
    }

    function _deployInterface(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id,
        string[2] calldata _interfaceSpecs
    ) internal {
        address gInterface = Clones.clone(self.DEFAULT_gETH_INTERFACE);
        IgETHInterface(gInterface).initialize(
            _id,
            _interfaceSpecs[0],
            _interfaceSpecs[1],
            address(self.gETH)
        );
        _setInterface(self, DATASTORE, _id, gInterface);
    }

    /**
     * @notice deploys a new liquidity pool using DEFAULT_LP
     * @dev sets the liquidity pool and LP token for id
     */
    function _deployLiquidityPool(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id
    ) internal {
        address lp = Clones.clone(self.DEFAULT_LP);
        bytes memory NAME = DATASTORE.readBytesForId(_id, "NAME");
        address lpToken = ISwap(lp).initialize(
            IgETH(self.gETH),
            _id,
            string(abi.encodePacked(NAME, "-Geode LP Token")),
            string(abi.encodePacked(NAME, "-LP")),
            DEFAULT_A,
            DEFAULT_FEE,
            DEFAULT_ADMIN_FEE,
            self.DEFAULT_LP_TOKEN
        );
        // transfer ownership of DWP to GOVERNANCE
        // // // Ownable(lp).transferOwnership(self.GOVERNANCE);

        // approve token so we can use it in buybacks
        self.gETH.setApprovalForAll(lp, true);

        DATASTORE.writeAddressForId(_id, "liquidityPool", lp);
    }

    /**
     * @notice Authentication
     */

    /**
     * @notice restricts the access to given function based on TYPE
     * @notice also allows onlyMaintainer check whenever required
     * @param expectMaintainer restricts the access to only maintainer
     * @param restrictionMap 0: Operator = TYPE(4), Planet = TYPE(5), Comet = TYPE(6),
     */
    function authenticate(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        bool expectMaintainer,
        bool[2] memory restrictionMap
    ) internal view {
        if (expectMaintainer) {
            require(
                msg.sender == DATASTORE.readAddressForId(id, "maintainer"),
                "MaintainerUtils: sender NOT maintainer"
            );
        }
        uint256 typeOfId = DATASTORE.readUintForId(id, "TYPE");

        require(
            DATASTORE.readUintForId(id, "initiated") != 0,
            "MaintainerUtils: ID is not initiated"
        );

        if (typeOfId == 4) {
            require(
                restrictionMap[0] == true,
                "MaintainerUtils: TYPE NOT allowed"
            );
        } else if (typeOfId == 5) {
            require(
                restrictionMap[1] == true,
                "MaintainerUtils: TYPE NOT allowed"
            );
        } else revert("MaintainerUtils: invalid TYPE");
    }

    /**
     * @notice CONTROLLER of the ID can change the maintainer to any address other than ZERO_ADDRESS
     * @dev it is wise to change the maintainer before the CONTROLLER, in case of any migration
     * @dev handle with care
     * NOTE intended (suggested) usage is to set a contract address that will govern the id for maintainer,
     * while keeping the controller as a multisig or provide smt like 0x000000000000000000000000000000000000dEaD
     */
    function changeMaintainer(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        address newMaintainer
    ) external {
        authenticate(DATASTORE, id, false, [true, true]);
        require(
            msg.sender == DATASTORE.readAddressForId(id, "CONTROLLER"),
            "MaintainerUtils: sender NOT CONTROLLER"
        );
        require(
            newMaintainer != address(0),
            "MaintainerUtils: maintainer can NOT be zero"
        );
        DATASTORE.writeAddressForId(id, "maintainer", newMaintainer);
        // emit MaintainerChanged(id, newMaintainer);
    }

    /**
     * @notice Maintainer Fee
     */

    /**
     * @notice Gets fee percentage in terms of PERCENTAGE_DENOMINATOR.
     * @dev even if MAX_MAINTAINER_FEE is decreased later, it returns limited maximum.
     * @param id planet, comet or operator ID
     * @return fee = percentage * PERCENTAGE_DENOMINATOR / 100 as a perfcentage
     */
    function getMaintainerFee(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) internal view returns (uint256 fee) {
        if (DATASTORE.readUintForId(id, "feeSwitch") > block.timestamp) {
            return DATASTORE.readUintForId(id, "priorFee");
        }
        return DATASTORE.readUintForId(id, "fee");
    }

    /**
     * @notice Changes the fee that is applied by distributeFee on Oracle Updates.
     * @dev advise that 100% == PERCENTAGE_DENOMINATOR
     * @param id planet, comet or operator ID
     */
    function switchMaintainerFee(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        uint256 newFee
    ) external {
        authenticate(DATASTORE, id, true, [true, true]);
        require(
            newFee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        require(
            block.timestamp > DATASTORE.readUintForId(id, "feeSwitch"),
            "MaintainerUtils: fee is currently switching"
        );
        DATASTORE.writeUintForId(
            id,
            "priorFee",
            DATASTORE.readUintForId(id, "fee")
        );
        DATASTORE.writeUintForId(
            id,
            "feeSwitch",
            block.timestamp + SWITCH_LATENCY
        );
        DATASTORE.writeUintForId(id, "fee", newFee);

        // emit MaintainerFeeSwitched(
        //     id,
        //     newFee,
        //     block.timestamp + SWITCH_LATENCY
        // );
    }

    /**
     * @notice Maintainer Wallet
     */

    /**
     * @notice To increase the balance of a Maintainer's wallet
     * @param _id the id of the Operator
     * @param _value Ether (in Wei) amount to increase the wallet balance.
     * @return success boolean value which is true if successful, should be used by Operator is Maintainer is a contract.
     */
    function _increaseMaintainerWallet(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id,
        uint256 _value
    ) internal returns (bool success) {
        DATASTORE.addUintForId(_id, "wallet", _value);
        return true;
    }

    /**
     * @dev only maintainer can increase the balance directly,
     * * other than that it also collects validator rewards
     */
    function increaseMaintainerWallet(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external returns (bool success) {
        authenticate(DATASTORE, id, true, [true, false]);
        return _increaseMaintainerWallet(DATASTORE, id, msg.value);
    }

    /**
     * @notice To decrease the balance of an Operator's wallet
     * @dev only maintainer can decrease the balance
     * @param _id the id of the Operator
     * @param _value Ether (in Wei) amount to decrease the wallet balance and send back to Maintainer.
     * @return success boolean value which is "sent", should be used by Operator is Maintainer is a contract.
     */
    function _decreaseMaintainerWallet(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id,
        uint256 _value
    ) internal returns (bool success) {
        require(
            DATASTORE.readUintForId(_id, "wallet") >= _value,
            "MaintainerUtils: NOT enough balance in wallet"
        );
        DATASTORE.subUintForId(_id, "wallet", _value);
        return true;
    }

    /**
     * @dev only maintainer can decrease the balance directly,
     * * other than that it can be used to propose Validators
     * @dev if a maintainer is in prison, it can not decrease the wallet
     */
    function decreaseMaintainerWallet(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        uint256 value
    ) external returns (bool success) {
        authenticate(DATASTORE, id, true, [true, true]);

        require(
            address(this).balance >= value,
            "StakeUtils: not enough balance in Portal (?)"
        );

        bool decreased = _decreaseMaintainerWallet(DATASTORE, id, value);

        (bool sent, ) = msg.sender.call{value: value}("");
        require(decreased && sent, "StakeUtils: Failed to send ETH");
        return sent;
    }

    /**
     * @notice                           ** Pool - Operator Allowance **
     */

    /** *
     * @notice operatorAllowence is the number of validators that the given Operator is allowed to create on behalf of the Planet
     * @dev an operator can not create new validators if:
     * * 1. allowence is 0 (zero)
     * * 2. lower than the current (proposed + active) number of validators
     * * But if operator withdraws a validator, then able to create a new one.
     * @dev prestake checks the approved validator count to make sure the number of validators are not bigger than allowence
     * @dev allowence doesn't change when new validators created or old ones are unstaked.
     * @return allowance
     */
    function operatorAllowance(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 poolId,
        uint256 operatorId
    ) public view returns (uint256 allowance) {
        allowance = DATASTORE.readUintForId(
            poolId,
            DataStoreUtils.getKey(operatorId, "allowance")
        );
    }

    /**
     * @notice To allow a Node Operator run validators for your Planet with Max number of validators.
     * * This number can be set again at any given point in the future.
     *
     * @dev If planet decreases the approved validator count, below current running validator,
     * operator can only withdraw until to new allowence.
     * @dev only maintainer of _planetId can approve an Operator
     * @param poolId the gETH id of the Planet, only Maintainer can call this function
     * @param operatorId the id of the Operator to allow them create validators for a given Planet
     * @param allowance the MAX number of validators that can be created by the Operator for a given Planet
     */
    function approveOperator(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 poolId,
        uint256 operatorId,
        uint256 allowance
    ) external returns (bool) {
        authenticate(DATASTORE, poolId, true, [false, true]);
        authenticate(DATASTORE, operatorId, false, [true, false]);

        DATASTORE.writeUintForId(
            poolId,
            DataStoreUtils.getKey(operatorId, "allowance"),
            allowance
        );

        // emit OperatorApproval(poolId, operatorId, allowance);
        return true;
    }

    /**
     * @notice                ** Operator (TYPE 4) specific functions **
     */

    /**
     * @notice updates validatorPeriod for given operator, limited by MIN_VALIDATOR_PERIOD and MAX_VALIDATOR_PERIOD
     */
    function _updateValidatorPeriod(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 operatorId,
        uint256 newPeriod
    ) internal {
        require(
            newPeriod >= MIN_VALIDATOR_PERIOD,
            "StakeUtils: should be more than MIN_VALIDATOR_PERIOD"
        );
        require(
            newPeriod <= MAX_VALIDATOR_PERIOD,
            "StakeUtils: should be less than MAX_VALIDATOR_PERIOD"
        );

        require(
            block.timestamp >
                DATASTORE.readUintForId(operatorId, "periodSwitch"),
            "StakeUtils: period is currently switching"
        );

        DATASTORE.writeUintForId(
            operatorId,
            "priorPeriod",
            DATASTORE.readUintForId(operatorId, "validatorPeriod")
        );

        DATASTORE.writeUintForId(
            operatorId,
            "periodSwitch",
            block.timestamp + SWITCH_LATENCY
        );

        DATASTORE.writeUintForId(operatorId, "validatorPeriod", newPeriod);

        // emit ValidatorPeriodUpdated(operatorId, newPeriod);
    }

    function updateValidatorPeriod(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 operatorId,
        uint256 newPeriod
    ) external {
        authenticate(DATASTORE, operatorId, true, [true, false]);
        _updateValidatorPeriod(DATASTORE, operatorId, newPeriod);
    }

    /**
     * @notice                      ** STAKING POOL (TYPE 5)  specific functions **
     */

    /**
     * @notice returns miniGovernance as a contract
     */
    function miniGovernanceById(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id
    ) internal view returns (IMiniGovernance) {
        return
            IMiniGovernance(DATASTORE.readAddressForId(_id, "miniGovernance"));
    }

    /**
     * @notice returns liquidityPool as a contract
     */
    function liquidityPoolById(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id
    ) internal view returns (ISwap) {
        return ISwap(DATASTORE.readAddressForId(_id, "liquidityPool"));
    }

    /**
     * @dev pausing requires pool to be NOT paused already
     */
    function pauseStakingForPool(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external {
        authenticate(DATASTORE, id, true, [false, true]);

        require(
            DATASTORE.readUintForId(id, "stakePaused") == 0,
            "StakeUtils: staking already paused"
        );

        DATASTORE.writeUintForId(id, "stakePaused", 1); // meaning true
        // emit PoolPaused(id);
    }

    /**
     * @dev unpausing requires pool to be paused already
     */
    function unpauseStakingForPool(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external {
        authenticate(DATASTORE, id, true, [false, true]);

        require(
            DATASTORE.readUintForId(id, "stakePaused") == 1,
            "StakeUtils: staking already NOT paused"
        );

        DATASTORE.writeUintForId(id, "stakePaused", 0); // meaning false
        // emit PoolUnpaused(id);
    }

    /**
     * @notice                      ** DEPOSIT(user) functionality **
     */

    /**
     * @notice checks if staking is allowed in a pool.
     * * when a pool is paused for staking NO new funds can be minted.
     * @notice staking is not allowed if:
     * 1. MiniGovernance is in Isolation Mode, this means it is not upgraded to current version
     * 2. Staking is simply paused by the Pool maintainer
     * @dev minting is paused when stakePaused == 1, meaning true.
     */
    function canDeposit(DataStoreUtils.DataStore storage DATASTORE, uint256 _id)
        public
        view
        returns (bool)
    {
        return
            (DATASTORE.readUintForId(_id, "stakePaused") == 0) &&
            !(miniGovernanceById(DATASTORE, _id).recoveryMode());
    }

    /**
     * @notice conducts a buyback using the given liquidity pool,
     * @param to address to send bought gETH(id). burns the tokens if to=address(0), transfers if not
     * @param poolId id of the gETH that will be bought
     * @param sellEth ETH amount to sell
     * @param minToBuy TX is expected to revert by Swap.sol if not meet
     * @param deadline TX is expected to revert by Swap.sol if not meet
     * @dev this function assumes that pool is deployed by deployliquidityPool
     * as index 0 is eth and index 1 is Geth
     */
    function _buyback(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        address to,
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
        if (to == address(0)) {
            // burn
            self.gETH.burn(address(this), poolId, outAmount);
        } else {
            // send back to user
            self.gETH.safeTransferFrom(
                address(this),
                to,
                poolId,
                outAmount,
                ""
            );
        }
    }

    /**
     * @notice Allowing users to deposit into a public staking pool.
     * * Buys from DWP if price is low -debt-, mints new tokens if surplus is sent -more than debt-
     * @param planetId id of the staking pool, liquidity pool and gETH to be used.
     * @param mingETH liquidity pool parameter
     * @param deadline liquidity pool parameter
     * // debt  msg.value
     * // 100   10  => buyback
     * // 100   100 => buyback
     * // 10    100 => buyback + mint
     * // 1     x   => mint
     * // 0.5   x   => mint
     * // 0     x   => mint
     */
    function deposit(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 planetId,
        uint256 mingETH,
        uint256 deadline
    ) external returns (uint256 totalgETH) {
        authenticate(DATASTORE, planetId, false, [false, true]);
        require(msg.value > 1e15, "StakeUtils: at least 0.001 eth");
        require(deadline > block.timestamp, "StakeUtils: deadline not met");
        require(canDeposit(DATASTORE, planetId), "StakeUtils: minting paused");

        if (DATASTORE.readUintForId(planetId, "public") == 0)
            require(
                msg.sender ==
                    DATASTORE.readAddressForId(planetId, "maintainer"),
                "StakeUtils: private pool"
            );

        uint256 debt = liquidityPoolById(DATASTORE, planetId).getDebt();

        if (debt >= msg.value) {
            return
                _buyback(
                    self,
                    DATASTORE,
                    msg.sender,
                    planetId,
                    msg.value,
                    mingETH,
                    deadline
                );
        } else {
            uint256 boughtgETH = 0;
            uint256 remEth = msg.value;
            if (debt > IGNORABLE_DEBT) {
                boughtgETH = _buyback(
                    self,
                    DATASTORE,
                    msg.sender,
                    planetId,
                    debt,
                    0,
                    deadline
                );
                remEth -= debt;
            }
            uint256 mintedgETH = (
                ((remEth * self.gETH.denominator()) /
                    self.gETH.pricePerShare(planetId))
            );
            self.gETH.mint(msg.sender, planetId, mintedgETH, "");
            DATASTORE.addUintForId(planetId, "surplus", remEth);

            require(
                boughtgETH + mintedgETH >= mingETH,
                "StakeUtils: less than mingETH"
            );
            // do this on Portal.
            // if (self.TELESCOPE._isOracleActive()) {
            //     bytes32 dailyBufferKey = DataStoreUtils.getKey(
            //         block.timestamp -
            //             (block.timestamp % OracleUtils.ORACLE_PERIOD),
            //         "mintBuffer"
            //     );
            //     DATASTORE.addUintForId(planetId, dailyBufferKey, mintedgETH);
            // }
            return boughtgETH + mintedgETH;
        }
    }

    /**
     * @notice                      ** STAKE(operator) functions **
     */

    /**
     * @notice checks if a validator can use pool funds
     * Creation of a Validator takes 2 steps.
     * Before entering beaconStake function, _canStake verifies the eligibility of
     * given pubKey that is proposed by an operator with proposeStake function.
     * Eligibility is defined by an optimistic alienation, check alienate() for info.
     *
     *  @param pubkey BLS12-381 public key of the validator
     *  @return true if:
     *   - pubkey should be proposeStaked
     *   - pubkey should not be alienated (https://bit.ly/3Tkc6UC)
     *   - validator's index should be lower than VERIFICATION_INDEX. Updated by Telescope.
     *  else:
     *      return false
     */
    function _canStake(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        bytes calldata pubkey,
        uint256 verificationIndex
    ) internal view returns (bool) {
        return
            self._validators[pubkey].state == 1 &&
            self._validators[pubkey].index <= verificationIndex &&
            !(
                miniGovernanceById(DATASTORE, self._validators[pubkey].poolId)
                    .recoveryMode()
            );
    }

    /**
     * @notice Validator Credentials Proposal function, first step of crating validators.
     * * Once a pubKey is proposed and not alienated for some time,
     * * it is optimistically allowed to take funds from staking pools.
     *
     * @param poolId the id of the staking pool whose TYPE can be 5 or 6.
     * @param operatorId the id of the Operator whose maintainer calling this function
     * @param pubkeys  Array of BLS12-381 public keys of the validators that will be proposed
     * @param signatures1 Array of BLS12-381 signatures of the validators that will be proposed
     *
     * @dev DEPOSIT_AMOUNT_PRESTAKE = 1 ether, which is the minimum number to create validator.
     * 31 Ether will be staked after verification of oracles. 32 in total.
     * 1 ether will be sent back to Node Operator when finalized deposit is successful.
     * @dev ProposeStake requires enough allowance from Staking Pools to Operators.
     * @dev ProposeStake requires enough funds within maintainerWallet.
     * @dev Max number of validators to propose is MAX_DEPOSITS_PER_CALL (currently 64)
     */
    function proposeStake(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 poolId,
        uint256 operatorId,
        bytes[] calldata pubkeys,
        bytes[] calldata signatures1,
        bytes[] calldata signatures31
    ) external {
        authenticate(DATASTORE, operatorId, true, [true, false]);
        authenticate(DATASTORE, poolId, false, [false, true]);
        // require(
        //     !OracleUtils.isPrisoned(DATASTORE, operatorId),
        //     "StakeUtils: operator is in prison, get in touch with governance"
        // );

        require(
            pubkeys.length == signatures1.length,
            "StakeUtils: invalid signatures1 length"
        );
        require(
            pubkeys.length == signatures31.length,
            "StakeUtils: invalid signatures31 length"
        );

        require(
            pubkeys.length > 0 && pubkeys.length <= DCU.MAX_DEPOSITS_PER_CALL,
            "StakeUtils: MAX 64 nodes per call"
        );

        // require(
        //     (DATASTORE.readUintForId(operatorId, "totalActiveValidators") +
        //         DATASTORE.readUintForId(operatorId, "totalProposedValidators") +
        //         pubkeys.length) <= self.TELESCOPE.MONOPOLY_THRESHOLD,
        //     "StakeUtils: IceBear does NOT like monopolies"
        // );

        require(
            (DATASTORE.readUintForId(
                poolId,
                DataStoreUtils.getKey(operatorId, "proposedValidators")
            ) +
                DATASTORE.readUintForId(
                    poolId,
                    DataStoreUtils.getKey(operatorId, "activeValidators")
                ) +
                pubkeys.length) <=
                operatorAllowance(DATASTORE, poolId, operatorId),
            "StakeUtils: NOT enough allowance"
        );

        require(
            DATASTORE.readUintForId(poolId, "surplus") >=
                DCU.DEPOSIT_AMOUNT * pubkeys.length,
            "StakeUtils: NOT enough surplus"
        );

        _decreaseMaintainerWallet(
            DATASTORE,
            operatorId,
            pubkeys.length * DCU.DEPOSIT_AMOUNT_PRESTAKE
        );

        DATASTORE.subUintForId(
            poolId,
            "surplus",
            (DCU.DEPOSIT_AMOUNT * pubkeys.length)
        );

        DATASTORE.addUintForId(
            poolId,
            "secured",
            (DCU.DEPOSIT_AMOUNT * pubkeys.length)
        );

        DATASTORE.addUintForId(
            poolId,
            DataStoreUtils.getKey(operatorId, "proposedValidators"),
            pubkeys.length
        );

        DATASTORE.addUintForId(
            operatorId,
            "totalProposedValidators",
            pubkeys.length
        );

        {
            uint256[2] memory fees = [
                getMaintainerFee(DATASTORE, poolId),
                getMaintainerFee(DATASTORE, operatorId)
            ];
            bytes memory withdrawalCredential = DATASTORE.readBytesForId(
                poolId,
                "withdrawalCredential"
            );
            uint256 expectedExit = block.timestamp +
                DATASTORE.readUintForId(operatorId, "validatorPeriod");
            uint256 nextValidatorsIndex = self.VALIDATORS_INDEX + 1;
            uint256 poolValidators = DATASTORE.readUintForId(
                poolId,
                "validatorsLength"
            );
            for (uint256 i; i < pubkeys.length; i++) {
                // require(
                //     self.TELESCOPE._validators[pubkeys[i]].state == 0,
                //     "StakeUtils: Pubkey already used or alienated"
                // );
                require(
                    pubkeys[i].length == DCU.PUBKEY_LENGTH,
                    "StakeUtils: PUBKEY_LENGTH ERROR"
                );
                require(
                    signatures1[i].length == DCU.SIGNATURE_LENGTH,
                    "StakeUtils: SIGNATURE_LENGTH ERROR"
                );

                require(
                    signatures31[i].length == DCU.SIGNATURE_LENGTH,
                    "StakeUtils: SIGNATURE_LENGTH ERROR"
                );

                DCU.depositValidator(
                    pubkeys[i],
                    withdrawalCredential,
                    signatures1[i],
                    DCU.DEPOSIT_AMOUNT_PRESTAKE
                );

                self._validators[pubkeys[i]] = Validator(
                    1,
                    nextValidatorsIndex + i,
                    poolId,
                    operatorId,
                    fees[0],
                    fees[1],
                    block.timestamp,
                    expectedExit,
                    signatures31[i]
                );

                DATASTORE.writeBytesForId(
                    poolId,
                    DataStoreUtils.getKey(poolValidators + i, "validators"),
                    pubkeys[i]
                );
                // emit ProposeStaked(pubkeys[i], poolId, operatorId);
            }
        }
        DATASTORE.addUintForId(poolId, "validatorsLength", pubkeys.length);
        self.VALIDATORS_INDEX += pubkeys.length;
    }

    /**
     *  @notice Sends 31 Eth from staking pool to validators that are previously created with ProposeStake.
     *  1 Eth per successful validator boostraping is returned back to MaintainerWallet.
     *
     *  @param operatorId the id of the Operator whose maintainer calling this function
     *  @param pubkeys  Array of BLS12-381 public keys of the validators that are already proposed with ProposeStake.
     *
     *  @dev To save gas cost, pubkeys should be arranged by planedIds.
     *  ex: [pk1, pk2, pk3, pk4, pk5, pk6, pk7]
     *  pk1, pk2, pk3 from planet1
     *  pk4, pk5 from planet2
     *  pk6 from planet3
     *  seperate them in similar groups as much as possible.
     *  @dev Max number of validators to boostrap is MAX_DEPOSITS_PER_CALL (currently 64)
     *  @dev A pubkey that is alienated will not get through. Do not frontrun during ProposeStake.
     */
    function beaconStake(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 operatorId,
        bytes[] calldata pubkeys
    ) external {
        authenticate(DATASTORE, operatorId, true, [true, false]);

        // require(
        //     !self.TELESCOPE._isOracleActive(),
        //     "StakeUtils: ORACLE is active"
        // );
        require(
            pubkeys.length > 0 && pubkeys.length <= DCU.MAX_DEPOSITS_PER_CALL,
            "StakeUtils: MAX 64 nodes"
        );
        {
            uint256 verificationIndex = self.VERIFICATION_INDEX;
            for (uint256 j; j < pubkeys.length; j++) {
                require(
                    _canStake(self, DATASTORE, pubkeys[j], verificationIndex),
                    "StakeUtils: NOT all pubkeys are stakeable"
                );
            }
        }
        {
            bytes32 activeValKey = DataStoreUtils.getKey(
                operatorId,
                "activeValidators"
            );
            bytes32 proposedValKey = DataStoreUtils.getKey(
                operatorId,
                "proposedValidators"
            );

            // uint256 planetId = self.TELESCOPE._validators[pubkeys[0]].poolId;
            uint256 planetId = 1;
            bytes memory withdrawalCredential = DATASTORE.readBytesForId(
                planetId,
                "withdrawalCredential"
            );

            uint256 lastPlanetChange;
            for (uint256 i; i < pubkeys.length; i++) {
                // if (planetId != self.TELESCOPE._validators[pubkeys[i]].poolId) {
                DATASTORE.subUintForId(
                    planetId,
                    "secured",
                    (DCU.DEPOSIT_AMOUNT * (i - lastPlanetChange))
                );
                DATASTORE.addUintForId(
                    planetId,
                    activeValKey,
                    (i - lastPlanetChange)
                );
                DATASTORE.subUintForId(
                    planetId,
                    proposedValKey,
                    (i - lastPlanetChange)
                );
                lastPlanetChange = i;
                // planetId = self.TELESCOPE._validators[pubkeys[i]].poolId;
                withdrawalCredential = DATASTORE.readBytesForId(
                    planetId,
                    "withdrawalCredential"
                );
                // }

                // bytes memory signature = self
                //     .TELESCOPE
                //     ._validators[pubkeys[i]]
                //     .signature;

                bytes memory signature = bytes("");

                DCU.depositValidator(
                    pubkeys[i],
                    withdrawalCredential,
                    signature,
                    DCU.DEPOSIT_AMOUNT - DCU.DEPOSIT_AMOUNT_PRESTAKE
                );

                // self.TELESCOPE._validators[pubkeys[i]].state = 2;
                // emit BeaconStaked(pubkeys[i]);
            }

            DATASTORE.subUintForId(
                planetId,
                "secured",
                DCU.DEPOSIT_AMOUNT * (pubkeys.length - lastPlanetChange)
            );
            DATASTORE.addUintForId(
                planetId,
                activeValKey,
                (pubkeys.length - lastPlanetChange)
            );
            DATASTORE.subUintForId(
                planetId,
                proposedValKey,
                (pubkeys.length - lastPlanetChange)
            );
            DATASTORE.subUintForId(
                operatorId,
                "totalProposedValidators",
                pubkeys.length
            );
            DATASTORE.addUintForId(
                operatorId,
                "totalActiveValidators",
                pubkeys.length
            );
        }
        _increaseMaintainerWallet(
            DATASTORE,
            operatorId,
            DCU.DEPOSIT_AMOUNT_PRESTAKE * pubkeys.length
        );
    }

    /**
     * @notice                      ** UNSTAKE(operator) functions **
     */
}
