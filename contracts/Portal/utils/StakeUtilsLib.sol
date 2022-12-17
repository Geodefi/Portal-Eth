// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./DataStoreUtilsLib.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";
import "./MaintainerUtilsLib.sol";
import "./OracleUtilsLib.sol";
import "../../interfaces/IgETH.sol";
import "../../interfaces/IMiniGovernance.sol";
import "../../interfaces/ISwap.sol";

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
 * * * properties related to miniGovernances and staking pools - surplus, secured, withdrawalPool etc.
 * * ID of a pool represents an id of gETH.
 * * For now, creation of staking pools are not permissionless but the usage of it is.
 * * * Meaning Everyone can stake and unstake using public pools.
 *
 * Type 6 stands for Private Staking Pools (Comets):
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
    event ValidatorPeriodUpdated(uint256 operatorId, uint256 newPeriod);
    event OperatorApproval(
        uint256 planetId,
        uint256 operatorId,
        uint256 allowance
    );
    event PoolPaused(uint256 id);
    event PoolUnpaused(uint256 id);
    event ProposeStaked(bytes pubkey, uint256 planetId, uint256 operatorId);
    event BeaconStaked(bytes pubkey);
    event UnstakeSignal(uint256 poolId, bytes pubkey);
    event WithdrawalBoostChanged(
        uint256 poolId,
        uint256 withdrawalBoost,
        uint256 effectiveAfter
    );
    using DataStoreUtils for DataStoreUtils.DataStore;
    using MaintainerUtils for DataStoreUtils.DataStore;
    using OracleUtils for OracleUtils.Oracle;

    /**
     * @notice StakePool includes the parameters related to multiple Staking Pool Contracts.
     * @notice Dynamic Staking Pool contains a staking pool that works with a *bound* Withdrawal Pool (DWP) to create best pricing
     * for the staking derivative. Withdrawal Pools (DWP) uses StableSwap algorithm with Dynamic Pegs.
     * @param gETH ERC1155 contract that keeps the totalSupply, pricePerShare and balances of all StakingPools by ID
     * @param DEFAULT_gETH_INTERFACE default interface for the g-derivative, currently equivalent to ERC20
     * @param DEFAULT_DWP Dynamic Withdrawal Pool implementation, a STABLESWAP pool that will be used for given ID
     * @param DEFAULT_LP_TOKEN LP token implementation that will be used for DWP of given ID
     * @param MINI_GOVERNANCE_VERSION  limited to be changed with the senate approval.
     * * versioning is done by GeodeUtils.proposal.id, implementation is stored in DataStore.id.controller
     * @param MAX_MAINTAINER_FEE  limits fees, set by GOVERNANCE
     * @param BOOSTRAP_PERIOD during this period the surplus of the pool can not be burned for withdrawals, initially set to 6 months
     * @param BOOST_SWITCH_LATENCY when a maintainer changes the withdrawalBoost, it is effective after a delay
     * @param COMET_TAX tax that will be taken from private pools, limited by MAX_MAINTAINER_FEE, set by GOVERNANCE
     * @dev gETH should not be changed, ever!
     * @dev changing some of these parameters (gETH, ORACLE) MUST require a contract upgrade to ensure security.
     * We can change this in the future with a better GeodeUtils design, giving every update a type, like MINI_GOVERNANCE_VERSION
     **/
    struct StakePool {
        IgETH gETH;
        OracleUtils.Oracle TELESCOPE;
        address GOVERNANCE;
        address DEFAULT_gETH_INTERFACE;
        address DEFAULT_DWP;
        address DEFAULT_LP_TOKEN;
        uint256 MINI_GOVERNANCE_VERSION;
        uint256 MAX_MAINTAINER_FEE;
        uint256 BOOSTRAP_PERIOD;
        uint256 BOOST_SWITCH_LATENCY;
        uint256 COMET_TAX;
        uint256[5] __gap;
    }

    /// @notice PERCENTAGE_DENOMINATOR represents 100%
    uint256 public constant PERCENTAGE_DENOMINATOR = 10**10;

    /// @notice limiting the operator.validatorPeriod, currently around 5 years
    uint256 public constant MIN_VALIDATOR_PERIOD = 90 days;
    uint256 public constant MAX_VALIDATOR_PERIOD = 1825 days;

    /// @notice ignoring any buybacks if the DWP has a low debt
    uint256 public constant IGNORABLE_DEBT = 1 ether;

    modifier onlyGovernance(StakePool storage self) {
        require(
            msg.sender == self.GOVERNANCE,
            "StakeUtils: sender NOT GOVERNANCE"
        );
        _;
    }

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
     * @dev Consensys Diligence Audit team advised that there are many issues with having multiple interfaces,
     * as well as the possibility of setting a malicious interface.
     *
     * Interfaces are developed to provide a flexibility for the owners of a Staking Pools, however these risks
     * are very strong blockers, even with gETH.Avoiders implementation.
     *
     * Until there is a request for other interfaces, with proper solutions for provided issues,
     * we are limiting the abilities of Maintainers on Interfaces, except standard ERC20.
     */

    // function setInterface(
    //     StakePool storage self,
    //     DataStoreUtils.DataStore storage DATASTORE,
    //     uint256 id,
    //     address _interface
    // ) external {
    //     DATASTORE.authenticate(id, true, [false, true, true]);
    //     _setInterface(self, DATASTORE, id, _interface);
    // }

    /**
     * @notice unsets a erc1155Interface for gETH with given index -acquired from allInterfaces()-
     * @param index index of given interface at the "interfaces" dynamic array
     * @dev every interface has a unique interface index within interfaces dynamic array.
     * * even if unsetted, it just replaces the implementation with address(0) for obvious security reasons
     * @dev old Interfaces will still be active if not unsetted
     */
    // function unsetInterface(
    //     StakePool storage self,
    //     DataStoreUtils.DataStore storage DATASTORE,
    //     uint256 id,
    //     uint256 index
    // ) external {
    //     DATASTORE.authenticate(id, true, [false, true, true]);
    //     address _interface = DATASTORE.readAddressForId(
    //         id,
    //         DataStoreUtils.getKey(index, "interfaces")
    //     );
    //     require(
    //         _interface != address(0) && self.gETH.isInterface(_interface, id),
    //         "StakeUtils: already NOT interface"
    //     );
    //     DATASTORE.writeAddressForId(
    //         id,
    //         DataStoreUtils.getKey(index, "interfaces"),
    //         address(0)
    //     );
    //     self.gETH.setInterface(_interface, id, false);
    // }

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
     * @notice                      ** Maintainer Initiators **
     */
    /**
     * @notice initiates ID as an node operator
     * @dev requires ID to be approved as a node operator with a specific CONTROLLER
     * @param _validatorPeriod the expected maximum staking interval. This value should between
     * * MIN_VALIDATOR_PERIOD and MAX_VALIDATOR_PERIOD values defined as constants above,
     * * this check is done inside updateValidatorPeriod function.
     * Operator can unstake at any given point before this period ends.
     * If operator disobeys this rule, it can be prisoned with blameOperator()
     */
    function initiateOperator(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        uint256 _validatorPeriod
    ) external {
        require(
            _fee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        require(
            _validatorPeriod >= MIN_VALIDATOR_PERIOD,
            "StekeUtils: should be more than MIN_VALIDATOR_PERIOD"
        );
        require(
            _validatorPeriod <= MAX_VALIDATOR_PERIOD,
            "StekeUtils: should be less than MAX_VALIDATOR_PERIOD"
        );

        DATASTORE.initiateOperator(_id, _fee, _maintainer);
        DATASTORE.writeUintForId(_id, "validatorPeriod", _validatorPeriod);
    }

    /**
     * @notice initiates ID as a planet (public pool)
     * @dev requires ID to be approved as a planet with a specific CONTROLLER
     * @param _interfaceSpecs 0: interface name, 1: interface symbol, currently ERC20 specs.
     */
    function initiatePlanet(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        string[2] calldata _interfaceSpecs
    ) external {
        require(
            _fee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );

        address[5] memory addressSpecs = [
            address(self.gETH),
            _maintainer,
            self.DEFAULT_gETH_INTERFACE,
            self.DEFAULT_DWP,
            self.DEFAULT_LP_TOKEN
        ];
        uint256[3] memory uintSpecs = [_id, _fee, self.MINI_GOVERNANCE_VERSION];
        (
            address miniGovernance,
            address gInterface,
            address withdrawalPool
        ) = DATASTORE.initiatePlanet(uintSpecs, addressSpecs, _interfaceSpecs);

        DATASTORE.writeBytesForId(
            _id,
            "withdrawalCredential",
            DCU.addressToWC(miniGovernance)
        );

        _setInterface(self, DATASTORE, _id, gInterface);

        // initially 1 ETHER = 1 ETHER
        self.gETH.setPricePerShare(1 ether, _id);

        // transfer ownership of DWP to GOVERNANCE
        Ownable(withdrawalPool).transferOwnership(self.GOVERNANCE);
        // approve token so we can use it in buybacks
        self.gETH.setApprovalForAll(withdrawalPool, true);
    }

    /**
     * @notice                      ** Governance specific functions **
     */

    /**
     * @notice called when a proposal(TYPE=11) for a new MiniGovernance is approved by Senate
     * @dev CONTROLLER of the proposal id represents the implementation address
     * @dev This function seems like everyone can call, but it is called inside portal after approveProposal function
     * * and approveProposal has onlySenate modifier, can be called only by senate.
     */
    function setMiniGovernanceVersion(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external {
        require(DATASTORE.readUintForId(id, "TYPE") == 11);
        self.MINI_GOVERNANCE_VERSION = id;
    }

    /**
     * @notice                      ** Maintainer specific functions **
     */

    /**
     * @notice changes maintainer of the given operator, planet or comet
     * @dev Seems like authenticate is not correct, but authenticate checks for maintainer
     * and this function expects controller and DATASTORE.changeMaintainer checks that.
     */
    function changeMaintainer(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        address newMaintainer
    ) external {
        DATASTORE.authenticate(id, false, [true, true, true]);
        DATASTORE.changeMaintainer(id, newMaintainer);
    }

    /**
     * @param newFee new fee percentage in terms of PERCENTAGE_DENOMINATOR, reverts if given more than MAX_MAINTAINER_FEE
     * @dev there is a 7 days delay before the new fee is activated,
     * * this protect the pool maintainers from making bad operator choices
     */
    function switchMaintainerFee(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        uint256 newFee
    ) external {
        DATASTORE.authenticate(id, true, [true, true, true]);
        require(
            newFee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        DATASTORE.switchMaintainerFee(id, newFee);
    }

    /**
     * @dev only maintainer can increase the balance directly,
     * * other than that it also collects validator rewards
     */
    function increaseMaintainerWallet(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external returns (bool success) {
        DATASTORE.authenticate(id, true, [true, false, false]);

        return DATASTORE._increaseMaintainerWallet(id, msg.value);
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
        DATASTORE.authenticate(id, true, [true, true, true]);

        require(
            !OracleUtils.isPrisoned(DATASTORE, id),
            "StakeUtils: you are in prison, get in touch with governance"
        );

        require(
            address(this).balance >= value,
            "StakeUtils: not enough balance in Portal (?)"
        );

        bool decreased = DATASTORE._decreaseMaintainerWallet(id, value);

        (bool sent, ) = msg.sender.call{value: value}("");
        require(decreased && sent, "StakeUtils: Failed to send ETH");
        return sent;
    }

    /**
     * @notice                           ** Pool - Operator interactions **
     */
    /**
     * @param withdrawalBoost the percentage of arbitrague that will be shared
     * with Operator on Unstake. Can be used to incentivise Unstakes in case of depeg
     * @dev to prevent malicious swings in the withdrawal boost that can harm the competition,
     * Boost changes is also has a delay.
     */
    function switchWithdrawalBoost(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 poolId,
        uint256 withdrawalBoost
    ) external {
        DATASTORE.authenticate(poolId, true, [false, true, true]);
        require(
            block.timestamp > DATASTORE.readUintForId(poolId, "boostSwitch"),
            "StakeUtils: boost is currently switching"
        );
        DATASTORE.writeUintForId(
            poolId,
            "priorBoost",
            DATASTORE.readUintForId(poolId, "withdrawalBoost")
        );
        DATASTORE.writeUintForId(
            poolId,
            "boostSwitch",
            block.timestamp + self.BOOST_SWITCH_LATENCY
        );
        DATASTORE.writeUintForId(poolId, "withdrawalBoost", withdrawalBoost);

        emit WithdrawalBoostChanged(
            poolId,
            withdrawalBoost,
            block.timestamp + self.BOOST_SWITCH_LATENCY
        );
    }

    /**
     * @notice returns the withdrawalBoost with a time delay
     */
    function getWithdrawalBoost(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) internal view returns (uint256 boost) {
        if (DATASTORE.readUintForId(id, "boostSwitch") > block.timestamp) {
            return DATASTORE.readUintForId(id, "priorBoost");
        }
        return DATASTORE.readUintForId(id, "withdrawalBoost");
    }

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
        DATASTORE.authenticate(poolId, true, [false, true, true]);
        DATASTORE.authenticate(operatorId, false, [true, false, false]);

        DATASTORE.writeUintForId(
            poolId,
            DataStoreUtils.getKey(operatorId, "allowance"),
            allowance
        );

        emit OperatorApproval(poolId, operatorId, allowance);
        return true;
    }

    /**
     * @notice                ** Operator (TYPE 4 and 5) specific functions **
     */

    /**
     * @notice updates validatorPeriod for given operator, limited by MAX_VALIDATOR_PERIOD
     */
    function _updateValidatorPeriod(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 operatorId,
        uint256 newPeriod
    ) internal {
        require(
            newPeriod >= MIN_VALIDATOR_PERIOD,
            "StekeUtils: should be more than MIN_VALIDATOR_PERIOD"
        );
        require(
            newPeriod <= MAX_VALIDATOR_PERIOD,
            "StekeUtils: should be less than MAX_VALIDATOR_PERIOD"
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
            block.timestamp + MaintainerUtils.SWITCH_LATENCY
        );
        DATASTORE.writeUintForId(operatorId, "validatorPeriod", newPeriod);

        emit ValidatorPeriodUpdated(operatorId, newPeriod);
    }

    function updateValidatorPeriod(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 operatorId,
        uint256 newPeriod
    ) external {
        DATASTORE.authenticate(operatorId, true, [true, false, false]);
        _updateValidatorPeriod(DATASTORE, operatorId, newPeriod);
    }

    /**
     * @notice                      ** STAKING POOL (TYPE 5 and 6)  specific functions **
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
     * @notice returns withdrawalPool as a contract
     */
    function withdrawalPoolById(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id
    ) internal view returns (ISwap) {
        return ISwap(DATASTORE.readAddressForId(_id, "withdrawalPool"));
    }

    /**
     * @dev pausing requires pool to be NOT paused already
     */
    function pauseStakingForPool(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external {
        DATASTORE.authenticate(id, true, [false, true, true]);

        require(
            DATASTORE.readUintForId(id, "stakePaused") == 0,
            "StakeUtils: staking already paused"
        );

        DATASTORE.writeUintForId(id, "stakePaused", 1); // meaning true
        emit PoolPaused(id);
    }

    /**
     * @dev unpausing requires pool to be paused already
     */
    function unpauseStakingForPool(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external {
        DATASTORE.authenticate(id, true, [false, true, true]);

        require(
            DATASTORE.readUintForId(id, "stakePaused") == 1,
            "StakeUtils: staking already NOT paused"
        );

        DATASTORE.writeUintForId(id, "stakePaused", 0); // meaning false
        emit PoolUnpaused(id);
    }

    /**
     * @notice                      ** DEPOSIT(user) functions **
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
            !(miniGovernanceById(DATASTORE, _id).isolationMode());
    }

    /**
     * @notice conducts a buyback using the given withdrawal pool,
     * @param to address to send bought gETH(id). burns the tokens if to=address(0), transfers if not
     * @param poolId id of the gETH that will be bought
     * @param sellEth ETH amount to sell
     * @param minToBuy TX is expected to revert by Swap.sol if not meet
     * @param deadline TX is expected to revert by Swap.sol if not meet
     * @dev this function assumes that pool is deployed by deployWithdrawalPool
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
        // SWAP in WP
        outAmount = withdrawalPoolById(DATASTORE, poolId).swap{value: sellEth}(
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
     * @param planetId id of the staking pool, withdrawal pool and gETH to be used.
     * @param mingETH withdrawal pool parameter
     * @param deadline withdrawal pool parameter
     * // debt  msg.value
     * // 100   10  => buyback
     * // 100   100 => buyback
     * // 10    100 => buyback + mint
     * // 1     x   => mint
     * // 0.5   x   => mint
     * // 0     x   => mint
     */
    function depositPlanet(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 planetId,
        uint256 mingETH,
        uint256 deadline
    ) external returns (uint256 totalgETH) {
        DATASTORE.authenticate(planetId, false, [false, true, false]);

        require(msg.value > 1e15, "StakeUtils: at least 0.001 eth ");
        require(deadline > block.timestamp, "StakeUtils: deadline not met");
        require(canDeposit(DATASTORE, planetId), "StakeUtils: minting paused");
        uint256 debt = withdrawalPoolById(DATASTORE, planetId).getDebt();
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
            if (self.TELESCOPE._isOracleActive()) {
                bytes32 dailyBufferKey = DataStoreUtils.getKey(
                    block.timestamp -
                        (block.timestamp % OracleUtils.ORACLE_PERIOD),
                    "mintBuffer"
                );
                DATASTORE.addUintForId(planetId, dailyBufferKey, mintedgETH);
            }
            return boughtgETH + mintedgETH;
        }
    }

    /**
     * @notice                      ** WITHDRAWAL(user) functions **
     */

    /**
     * @notice figuring out how much of gETH and ETH should be donated in case of _burnSurplus
     * @dev Refering to improvement proposal, fees are donated to DWP when surplus
     * is being used as a withdrawal source. This is necessary to:
     * 1. create a financial cost for boostrap period
     */
    function _donateBalancedFees(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 poolId,
        uint256 burnSurplus,
        uint256 burnGeth
    ) internal returns (uint256 EthDonation, uint256 gEthDonation) {
        // find half of the fees to burn from surplus
        uint256 fee = withdrawalPoolById(DATASTORE, poolId).getSwapFee();
        EthDonation = (burnSurplus * fee) / PERCENTAGE_DENOMINATOR / 2;

        // find the remaining half as gETH with respect to PPS
        gEthDonation = (burnGeth * fee) / PERCENTAGE_DENOMINATOR / 2;

        //send both fees to DWP
        withdrawalPoolById(DATASTORE, poolId).donateBalancedFees{
            value: EthDonation
        }(EthDonation, gEthDonation);
    }

    /**
     * @dev Refering to improvement proposal, it is now allowed to use surplus to
     * * withdraw from public pools (after boostrap period).
     * * This means, "surplus" becomes a parameter of, freshly named, Dynamic Staking Pools
     * * which is the combination of DWP+public staking pools. Now, (assumed) there wont be
     * * surplus and debt at the same time.
     * @dev burnBuffer should be increased if the ORACLE is active, otherwise we can not
     * verify the legitacy of Telescope price calculations
     */
    function _burnSurplus(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 poolId,
        uint256 gEthToWithdraw
    ) internal returns (uint256, uint256) {
        uint256 pps = self.gETH.pricePerShare(poolId);

        uint256 spentGeth = gEthToWithdraw;
        uint256 spentSurplus = ((spentGeth * pps) / self.gETH.denominator());
        uint256 surplus = DATASTORE.readUintForId(poolId, "surplus");
        if (spentSurplus >= surplus) {
            spentSurplus = surplus;
            spentGeth = ((spentSurplus * self.gETH.denominator()) / pps);
        }

        (uint256 EthDonation, uint256 gEthDonation) = _donateBalancedFees(
            DATASTORE,
            poolId,
            spentSurplus,
            spentGeth
        );

        DATASTORE.subUintForId(poolId, "surplus", spentSurplus);
        self.gETH.burn(address(this), poolId, spentGeth - gEthDonation);

        if (self.TELESCOPE._isOracleActive()) {
            bytes32 dailyBufferKey = DataStoreUtils.getKey(
                block.timestamp - (block.timestamp % OracleUtils.ORACLE_PERIOD),
                "burnBuffer"
            );
            DATASTORE.addUintForId(
                poolId,
                dailyBufferKey,
                spentGeth - gEthDonation
            );
        }

        return (spentSurplus - (EthDonation * 2), gEthToWithdraw - spentGeth);
    }

    /**
     * @notice withdraw funds from Dynamic Staking Pool (Public Staking Pool + DWP)
     * * If not in Boostrap Period, first checks the surplus, than swaps from DWP to create debt
     * @param gEthToWithdraw amount of g-derivative that should be withdrawn
     * @param minETH TX is expected to revert by Swap.sol if not meet
     * @param deadline TX is expected to revert by Swap.sol if not meet
     */
    function withdrawPlanet(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 poolId,
        uint256 gEthToWithdraw,
        uint256 minETH,
        uint256 deadline
    ) external returns (uint256 EthToSend) {
        DATASTORE.authenticate(poolId, false, [false, true, false]);

        require(deadline > block.timestamp, "StakeUtils: deadline not met");
        {
            // transfer token first
            uint256 beforeBalance = self.gETH.balanceOf(address(this), poolId);

            self.gETH.safeTransferFrom(
                msg.sender,
                address(this),
                poolId,
                gEthToWithdraw,
                ""
            );
            // Use the transferred amount
            gEthToWithdraw =
                self.gETH.balanceOf(address(this), poolId) -
                beforeBalance;
        }

        if (
            block.timestamp >
            DATASTORE.readUintForId(poolId, "initiated") + self.BOOSTRAP_PERIOD
        ) {
            (EthToSend, gEthToWithdraw) = _burnSurplus(
                self,
                DATASTORE,
                poolId,
                gEthToWithdraw
            );
        }

        if (gEthToWithdraw > 0) {
            EthToSend += withdrawalPoolById(DATASTORE, poolId).swap(
                1,
                0,
                gEthToWithdraw,
                EthToSend >= minETH ? 0 : minETH - EthToSend,
                deadline
            );
        }
        (bool sent, ) = payable(msg.sender).call{value: EthToSend}("");
        require(sent, "StakeUtils: Failed to send Ether");
    }

    /**
     * @notice                      ** STAKE(operator) functions **
     */

    /**
     * @notice internal function that checks if validator is allowed
     * by Telescope and also not in isolationMode
     */
    function _canStake(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        bytes calldata pubkey,
        uint256 verificationIndex
    ) internal view returns (bool) {
        return
            self.TELESCOPE._canStake(pubkey, verificationIndex) &&
            !(
                miniGovernanceById(
                    DATASTORE,
                    self.TELESCOPE._validators[pubkey].poolId
                ).isolationMode()
            );
    }

    /**
     * @notice external function to check if a validator can use planet funds
     */
    function canStake(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        bytes calldata pubkey
    ) external view returns (bool) {
        return
            _canStake(
                self,
                DATASTORE,
                pubkey,
                self.TELESCOPE.VERIFICATION_INDEX
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
     * @param signatures Array of BLS12-381 signatures of the validators that will be proposed
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
        bytes[] calldata signatures
    ) external {
        DATASTORE.authenticate(operatorId, true, [true, false, false]);
        DATASTORE.authenticate(poolId, false, [false, true, true]);
        require(
            !OracleUtils.isPrisoned(DATASTORE, operatorId),
            "StakeUtils: operator is in prison, get in touch with governance"
        );

        require(
            pubkeys.length == signatures.length,
            "StakeUtils: pubkeys and signatures NOT same length"
        );
        require(
            pubkeys.length > 0 && pubkeys.length <= DCU.MAX_DEPOSITS_PER_CALL,
            "StakeUtils: MAX 64 nodes"
        );
        require(
            (DATASTORE.readUintForId(operatorId, "totalActiveValidators") +
                DATASTORE.readUintForId(operatorId, "totalProposedValidators") +
                pubkeys.length) <= self.TELESCOPE.MONOPOLY_THRESHOLD,
            "StakeUtils: IceBear does NOT like monopolies"
        );
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

        DATASTORE._decreaseMaintainerWallet(
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

        self.TELESCOPE.VALIDATORS_INDEX += pubkeys.length;
        {
            uint256[2] memory fees = [
                DATASTORE.getMaintainerFee(poolId),
                DATASTORE.getMaintainerFee(operatorId)
            ];
            bytes memory withdrawalCredential = DATASTORE.readBytesForId(
                poolId,
                "withdrawalCredential"
            );
            uint256 expectedExit = block.timestamp +
                DATASTORE.readUintForId(operatorId, "validatorPeriod");
            uint256 nextValidatorsIndex = self.TELESCOPE.VALIDATORS_INDEX;
            for (uint256 i; i < pubkeys.length; i++) {
                require(
                    self.TELESCOPE._validators[pubkeys[i]].state == 0,
                    "StakeUtils: Pubkey already used or alienated"
                );
                require(
                    pubkeys[i].length == DCU.PUBKEY_LENGTH,
                    "StakeUtils: PUBKEY_LENGTH ERROR"
                );
                require(
                    signatures[i].length == DCU.SIGNATURE_LENGTH,
                    "StakeUtils: SIGNATURE_LENGTH ERROR"
                );

                DCU.depositValidator(
                    pubkeys[i],
                    withdrawalCredential,
                    signatures[i],
                    DCU.DEPOSIT_AMOUNT_PRESTAKE
                );

                self.TELESCOPE._validators[pubkeys[i]] = OracleUtils.Validator(
                    1,
                    nextValidatorsIndex + i,
                    poolId,
                    operatorId,
                    fees[0],
                    fees[1],
                    block.timestamp,
                    expectedExit,
                    signatures[i]
                );
                emit ProposeStaked(pubkeys[i], poolId, operatorId);
            }
        }
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
        DATASTORE.authenticate(operatorId, true, [true, false, false]);

        require(
            !self.TELESCOPE._isOracleActive(),
            "StakeUtils: ORACLE is active"
        );
        require(
            pubkeys.length > 0 && pubkeys.length <= DCU.MAX_DEPOSITS_PER_CALL,
            "StakeUtils: MAX 64 nodes"
        );
        {
            uint256 verificationIndex = self.TELESCOPE.VERIFICATION_INDEX;
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

            uint256 planetId = self.TELESCOPE._validators[pubkeys[0]].poolId;
            bytes memory withdrawalCredential = DATASTORE.readBytesForId(
                planetId,
                "withdrawalCredential"
            );

            uint256 lastPlanetChange;
            for (uint256 i; i < pubkeys.length; i++) {
                if (planetId != self.TELESCOPE._validators[pubkeys[i]].poolId) {
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
                    planetId = self.TELESCOPE._validators[pubkeys[i]].poolId;
                    withdrawalCredential = DATASTORE.readBytesForId(
                        planetId,
                        "withdrawalCredential"
                    );
                }

                bytes memory signature = self
                    .TELESCOPE
                    ._validators[pubkeys[i]]
                    .signature;

                DCU.depositValidator(
                    pubkeys[i],
                    withdrawalCredential,
                    signature,
                    DCU.DEPOSIT_AMOUNT - DCU.DEPOSIT_AMOUNT_PRESTAKE
                );

                self.TELESCOPE._validators[pubkeys[i]].state = 2;
                emit BeaconStaked(pubkeys[i]);
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
        DATASTORE._increaseMaintainerWallet(
            operatorId,
            DCU.DEPOSIT_AMOUNT_PRESTAKE * pubkeys.length
        );
    }

    /**
     * @notice                      ** UNSTAKE(operator) functions **
     */

    /**
     * @notice allows improsening an Operator if the validator have not been exited until expectedExit
     * @dev anyone can call this function
     * @dev if operator has given enough allowence, they can rotate the validators to avoid being prisoned
     */
    function blameOperator(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        bytes calldata pk
    ) external {
        if (
            block.timestamp > self.TELESCOPE._validators[pk].expectedExit &&
            self.TELESCOPE._validators[pk].state == 2
        ) {
            OracleUtils.imprison(
                DATASTORE,
                self.TELESCOPE._validators[pk].operatorId
            );
        }
    }

    /**
     * @notice allows giving a unstake signal, meaning validator has been exited.
     * * And boost can be claimed upon arrival of the funds.
     * @dev to maintain the health of Geode Universe, we should protect the race conditions.
     * * opeators should know when others are unstaking so they don't spend money for no boost.
     */
    function signalUnstake(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        bytes[] calldata pubkeys
    ) external {
        uint256 expectedOperator = self
            .TELESCOPE
            ._validators[pubkeys[0]]
            .operatorId;

        DATASTORE.authenticate(expectedOperator, true, [true, false, false]);

        for (uint256 i = 0; i < pubkeys.length; i++) {
            require(self.TELESCOPE._validators[pubkeys[i]].state == 2);
            require(
                self.TELESCOPE._validators[pubkeys[i]].operatorId ==
                    expectedOperator
            );

            self.TELESCOPE._validators[pubkeys[i]].state = 3;

            emit UnstakeSignal(
                self.TELESCOPE._validators[pubkeys[i]].poolId,
                pubkeys[i]
            );
        }
    }

    /**
     * @notice Operator finalizing an Unstake event by calling Telescope's multisig:
     * * distributing fees + boost
     * * distributes rewards by burning the derivative
     * * does a buyback if necessary
     * * putting the extra within surplus.
     * @param isExit according to eip-4895, there can be multiple ways to distriute the rewards
     * * and not all of them requires exit. Even in such cases reward can be catched from
     * * withdrawal credential and distributed.
     *
     * @dev although OnlyOracle, logically this has nothing to do with Telescope.
     * * So we are keeping it here.
     * * @dev operator is prisoned if:
     * 1. withdrawn without signalled, being sneaky. in such case they also doesn't receive the boost
     * 2. signalled without withdrawal, deceiving other operators
     */
    function fetchUnstake(
        StakePool storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 poolId,
        uint256 operatorId,
        bytes[] calldata pubkeys,
        uint256[] calldata balances,
        bool[] calldata isExit
    ) external {
        require(
            msg.sender == self.TELESCOPE.ORACLE_POSITION,
            "StakeUtils: sender NOT ORACLE"
        );
        require(
            !self.TELESCOPE._isOracleActive(),
            "StakeUtils: ORACLE is active"
        );

        uint256 cumBal;
        uint256[2] memory fees;
        {
            uint256 exitCount;

            for (uint256 i = 0; i < pubkeys.length; i++) {
                uint256 balance = balances[i];
                cumBal += balances[i];

                if (isExit[i]) {
                    exitCount += 1;
                    if (balance > DCU.DEPOSIT_AMOUNT) {
                        balance -= DCU.DEPOSIT_AMOUNT;
                    } else {
                        balance = 0;
                    }
                }

                if (balance > 0) {
                    fees[0] += ((balance *
                        self.TELESCOPE._validators[pubkeys[i]].poolFee) /
                        PERCENTAGE_DENOMINATOR);

                    fees[1] += ((balance *
                        self.TELESCOPE._validators[pubkeys[i]].operatorFee) /
                        PERCENTAGE_DENOMINATOR);
                }
            }

            {
                bool success = miniGovernanceById(DATASTORE, poolId)
                    .claimUnstake(cumBal);
                require(success, "StakeUtils: Failed to claim");
            }

            // decrease the sum of isExit activeValidators and totalValidators
            DATASTORE.subUintForId(
                poolId,
                DataStoreUtils.getKey(operatorId, "activeValidators"),
                exitCount
            );
            DATASTORE.subUintForId(
                operatorId,
                "totalActiveValidators",
                exitCount
            );

            cumBal = cumBal - (fees[0] + fees[1]);
        }

        uint256 debt = withdrawalPoolById(DATASTORE, poolId).getDebt();
        if (debt > IGNORABLE_DEBT) {
            if (debt > cumBal) {
                debt = cumBal;
            }
            {
                uint256 boost = getWithdrawalBoost(DATASTORE, poolId);
                if (boost > 0) {
                    uint256 arb = withdrawalPoolById(DATASTORE, poolId)
                        .calculateSwap(0, 1, debt);
                    arb -=
                        (debt * self.gETH.denominator()) /
                        self.gETH.pricePerShare(poolId);
                    boost = (arb * boost) / PERCENTAGE_DENOMINATOR;

                    fees[1] += boost;
                    cumBal -= boost;
                }
            }

            _buyback(
                self,
                DATASTORE,
                address(0), // burn
                poolId,
                debt,
                0,
                type(uint256).max
            );
            cumBal -= debt;
        }

        if (cumBal > 0) {
            DATASTORE.addUintForId(poolId, "surplus", cumBal);
        }

        DATASTORE._increaseMaintainerWallet(poolId, fees[0]);
        DATASTORE._increaseMaintainerWallet(operatorId, fees[1]);
    }
}
