// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./DataStoreLib.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";
import "./MaintainerUtilsLib.sol";
import "./OracleUtilsLib.sol";
import "../../interfaces/IgETH.sol";
import "../../interfaces/IMiniGovernance.sol";
import "../../interfaces/ISwap.sol";
import "../../interfaces/ILPToken.sol";

/**
 * @title StakeUtils library
 * @notice Exclusively contains functions related to ETH Liquid Staking designed by Geode Finance
 * @notice biggest part of the functionality is related to Withdrawal Pools
 * which relies on continuous buybacks for price peg with DEBT/SURPLUS calculations
 * @dev Contracts relying on this library must initialize StakeUtils.StakePool
 * @dev ALL "fee" variables are limited by PERCENTAGE_DENOMINATOR. For ex, when fee is equal to PERCENTAGE_DENOMINATOR/2, it means 50% fee
 * Note refer to DataStoreUtils before reviewing
 * Note *suggested* refer to GeodeUtils before reviewing
 * Note beware of the staking pool and operator implementations:
 *
 *
 * Type 4 stand for Operators, they maintain Beacon Chain Validators on behalf of Planets and Comets.
 * Operators have properties like fee(as a percentage), maintainer.
 *
 * Type 5 stand for Public Staking Pool (Planets).
 * Every Planet is also an Operator by design.
 * Planets inherits Operator functionalities and parameters, with additional
 * properties like staking pools - relates to params: stBalance, surplus, secured, withdrawalPool - relates to debt -
 * and liquid asset ID(gETH).
 * Everyone can stake and unstake using public pools.
 *
 * Type 6 stands for Private Staking Pools (Comets).
 * It is permissionless, one can directly create a Comet by simply choosing a name.
 * Portal adds -comet to the end the selected name, so if one sends my-amazing-DAO as name parameter,
 * its name will be my-amazing-DAO-comet.
 * Only Comet's maintainer can stake but everyone can unstake.
 * In Comets, there is a Withdrawal Queue instead of DWT.
 */

library StakeUtils {
    event PriceChanged(uint256 id, uint256 pricePerShare);
    event MaxMaintainerFeeUpdated(uint256 newMaxFee);
    event PausedPool(uint256 id);
    event UnpausedPool(uint256 id);
    event OperatorApproval(
        uint256 planetId,
        uint256 operatorId,
        uint256 allowance
    );
    event PreStaked(bytes pubkey, uint256 planetId, uint256 operatorId);
    event BeaconStaked(bytes pubkey);
    event governanceParamsUpdated(
        address DEFAULT_gETH_INTERFACE_,
        address DEFAULT_DWP_,
        address DEFAULT_LP_TOKEN_,
        uint256 MAX_MAINTAINER_FEE_,
        uint256 BOOSTRAP_PERIOD_,
        uint256 PERIOD_PRICE_INCREASE_LIMIT_,
        uint256 PERIOD_PRICE_DECREASE_LIMIT_,
        uint256 WITHDRAWAL_DELAY_
    );

    using DataStoreUtils for DataStoreUtils.DataStore;
    using MaintainerUtils for DataStoreUtils.DataStore;
    using OracleUtils for OracleUtils.Oracle;

    /**
     * @notice StakePool includes the parameters related to multiple Staking Pool Contracts.
     * @notice Dynamic Staking Pool contains a staking pool that works with a *bound* Withdrawal Pool (DWP) to create best pricing
     * for the staking derivative. Withdrawal Pools (DWP) uses StableSwap algorithm with Dynamic Pegs.
     * @dev  gETH should not be changed, ever!
     * @param gETH ERC1155 contract that keeps the totalSupply, pricePerShare and balances of all StakingPools by ID
     * @param DEFAULT_gETH_INTERFACE
     * @param DEFAULT_DWP Dynamic Withdrawal Pool, a STABLESWAP pool that will be cloned to be used for given ID
     * @param DEFAULT_LP_TOKEN LP token implementation that will be cloned to be used for DWP of given ID
     * @param MAX_MAINTAINER_FEE : limits fees, set by GOVERNANCE
     * @param Validators : pubKey to Validator
     * @dev changing any of address parameters (gETH, ORACLE) MUST require a contract upgrade to ensure security. We can change this in the future with a better GeodeUtils design.
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
        uint256 COMET_TAX; //
    }

    /// @notice PERCENTAGE_DENOMINATOR represents 100%
    uint256 public constant PERCENTAGE_DENOMINATOR = 10**10;

    uint256 public constant IGNORABLE_DEBT = 1 ether;

    modifier onlyGovernance(StakePool storage self) {
        require(
            msg.sender == self.GOVERNANCE,
            "StakeUtils: sender NOT GOVERNANCE"
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
     * @notice                      ** gETH functions **
     */

    /**
     *  @notice if a planet did not unset an old Interface, before setting a new one;
     * @param _Interface address of the new gETH ERC1155 interface for given ID
     */
    function setInterface(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        address _Interface
    ) public {
        uint256 IL = _DATASTORE.readUintForId(_id, "interfacesLength");
        require(
            !self.gETH.isInterface(_Interface, _id),
            "StakeUtils: already interface"
        );
        _DATASTORE.writeAddressForId(
            _id,
            _getKey(IL, "interfaces"),
            _Interface
        );
        _DATASTORE.addUintForId(_id, "interfacesLength", 1);
        self.gETH.setInterface(_Interface, _id, true);
    }

    function unsetInterface(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _index
    ) external {
        address _Interface = _DATASTORE.readAddressForId(
            _id,
            _getKey(_index, "interfaces")
        );
        require(
            _Interface != address(0) && self.gETH.isInterface(_Interface, _id),
            "StakeUtils: already NOT interface"
        );
        _DATASTORE.writeAddressForId(
            _id,
            _getKey(_index, "interfaces"),
            address(0)
        );
        self.gETH.setInterface(_Interface, _id, false);
    }

    function allInterfaces(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) external view returns (address[] memory) {
        uint256 IL = _DATASTORE.readUintForId(_id, "interfacesLength");
        address[] memory interfaces = new address[](IL);
        for (uint256 i = 0; i < IL; i++) {
            interfaces[i] = _DATASTORE.readAddressForId(
                _id,
                _getKey(i, "interfaces")
            );
        }
        return interfaces;
    }

    /**
     * @notice                      ** ID functions **
     */
    /**
     * @notice initiates ID as an node operator
     * @dev requires ID to be approved as a node operator with a specific CONTROLLER
     * @param _id --
     * @param _validatorPeriod --
     */
    function initiateOperator(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        uint256 _validatorPeriod
    ) external {
        require(
            _fee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        _DATASTORE.initiateOperator(_id, _fee, _maintainer, _validatorPeriod);
    }

    /**
     * @notice initiates ID as a planet (public pool)
     * @dev requires ID to be approved as a planet with a specific CONTROLLER
     * @param _id --
     */
    function initiatePlanet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        uint256 _withdrawalBoost,
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
        uint256[4] memory uintSpecs = [
            _id,
            _fee,
            _withdrawalBoost,
            self.MINI_GOVERNANCE_VERSION
        ];
        (address miniGovernance, address gInterface, address WithdrawalPool) = _DATASTORE
            .initiatePlanet(
                // self.gETH,
                uintSpecs,
                addressSpecs,
                _interfaceSpecs
            );

        _DATASTORE.writeBytesForId(
            _id,
            "withdrawalCredential",
            DCU.addressToWC(miniGovernance)
        );

        setInterface(self, _DATASTORE, _id, gInterface);

        // transfer ownership of DWP to GOVERNANCE
        Ownable(WithdrawalPool).transferOwnership(self.GOVERNANCE);
        // approve token so we can use it in buybacks
        self.gETH.setApprovalForAll(WithdrawalPool, true);
        // initially 1 ETHER = 1 ETHER
        self.gETH.setPricePerShare(1 ether, _id);
    }

    /**
     * @notice initiates ID as a comet (private pool)
     * @dev requires ID to be approved as comet with a specific CONTROLLER
     * @param _id --
     */
    function initiateComet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer
    ) external {
        require(
            _fee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        _DATASTORE.initiateComet(_id, _fee, _maintainer);
    }

    /**
     * @notice                      ** Governance specific functions **
     */

    // if proposal is accepted, it should call this function
    function setMiniGovernanceVersion(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) external onlyGovernance(self) {
        require(_DATASTORE.readUintForId(_id, "TYPE") == 11);
        self.MINI_GOVERNANCE_VERSION = _id;
    }

    // function updateGovernanceParams(
    //     StakePool storage self,
    //     address _DEFAULT_gETH_INTERFACE, // contract?
    //     address _DEFAULT_DWP, // contract?
    //     address _DEFAULT_LP_TOKEN, // contract?
    //     uint256 _MAX_MAINTAINER_FEE, // < 100
    //     uint256 _BOOSTRAP_PERIOD,
    //     uint256 _PERIOD_PRICE_INCREASE_LIMIT,
    //     uint256 _PERIOD_PRICE_DECREASE_LIMIT,
    //     uint256 _WITHDRAWAL_DELAY,
    //     uint256 _COMET_TAX
    // ) external onlyGovernance(self) {
    //     require(
    //         _DEFAULT_gETH_INTERFACE.code.length > 0,
    //         "StakeUtils: DEFAULT_gETH_INTERFACE NOT contract"
    //     );
    //     require(
    //         _DEFAULT_DWP.code.length > 0,
    //         "StakeUtils: DEFAULT_DWP NOT contract"
    //     );
    //     require(
    //         _DEFAULT_LP_TOKEN.code.length > 0,
    //         "StakeUtils: DEFAULT_LP_TOKEN NOT contract"
    //     );
    //     require(
    //         _PERIOD_PRICE_INCREASE_LIMIT > 0,
    //         "StakeUtils: incorrect PERIOD_PRICE_INCREASE_LIMIT"
    //     );
    //     require(
    //         _PERIOD_PRICE_DECREASE_LIMIT > 0,
    //         "StakeUtils: incorrect PERIOD_PRICE_DECREASE_LIMIT"
    //     );
    //     require(
    //         _MAX_MAINTAINER_FEE > 0 &&
    //             _MAX_MAINTAINER_FEE <= PERCENTAGE_DENOMINATOR,
    //         "StakeUtils: incorrect MAX_MAINTAINER_FEE"
    //     );
    //     self.DEFAULT_gETH_INTERFACE = _DEFAULT_gETH_INTERFACE;
    //     self.DEFAULT_DWP = _DEFAULT_DWP;
    //     self.DEFAULT_LP_TOKEN = _DEFAULT_LP_TOKEN;
    //     self.MAX_MAINTAINER_FEE = _MAX_MAINTAINER_FEE;
    //     self.BOOSTRAP_PERIOD = _BOOSTRAP_PERIOD;
    //     self
    //         .TELESCOPE
    //         .PERIOD_PRICE_INCREASE_LIMIT = _PERIOD_PRICE_INCREASE_LIMIT;
    //     self
    //         .TELESCOPE
    //         .PERIOD_PRICE_DECREASE_LIMIT = _PERIOD_PRICE_DECREASE_LIMIT;
    //     self.TELESCOPE.WITHDRAWAL_DELAY = _WITHDRAWAL_DELAY;

    //     emit governanceParamsUpdated(
    //         _DEFAULT_gETH_INTERFACE,
    //         _DEFAULT_DWP,
    //         _DEFAULT_LP_TOKEN,
    //         _MAX_MAINTAINER_FEE,
    //         _BOOSTRAP_PERIOD,
    //         _PERIOD_PRICE_INCREASE_LIMIT,
    //         _PERIOD_PRICE_DECREASE_LIMIT,
    //         _WITHDRAWAL_DELAY
    //     );
    // }

    function releasePrisoned(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 operatorId
    ) external onlyGovernance(self) {
        require(
            isPrisoned(_DATASTORE, operatorId),
            "StakeUtils: NOT in prison"
        );
        _DATASTORE.writeUintForId(operatorId, "released", block.timestamp);
    }

    /**
     * @notice                      ** Maintainer specific functions **
     */

    function changeOperatorMaintainer(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        address _newMaintainer
    ) external {
        _DATASTORE._changeMaintainer(_id, _newMaintainer);
    }

    function changePoolMaintainer(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        bytes calldata password,
        bytes32 newPasswordHash,
        address newMaintainer
    ) external {
        miniGovernanceById(_DATASTORE, _id).changeMaintainer(
            password,
            newPasswordHash,
            newMaintainer
        );

        _DATASTORE._changeMaintainer(_id, newMaintainer);
    }

    function switchMaintainerFee(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _newFee
    ) external {
        _DATASTORE._authenticate(_id, true, [true, true, true]);
        require(
            _newFee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        _DATASTORE._switchMaintainerFee(_id, _newFee);
    }

    /**
     * @notice external version of _increaseMaintainerWallet()
     */
    function increaseMaintainerWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) external returns (bool success) {
        _DATASTORE._authenticate(_operatorId, true, [true, true, true]);

        return _DATASTORE._increaseMaintainerWallet(_operatorId, msg.value);
    }

    /**
     * @notice external version of _decreaseMaintainerWallet()
     */
    function decreaseMaintainerWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) external returns (bool success) {
        _DATASTORE._authenticate(_operatorId, true, [true, true, true]);

        require(
            !isPrisoned(_DATASTORE, _operatorId),
            "StakeUtils: you are in prison, get in touch with governance"
        );

        require(
            address(this).balance >= value,
            "StakeUtils: not enough balance in Portal (?)"
        );

        bool decreased = _DATASTORE._decreaseMaintainerWallet(
            _operatorId,
            value
        );

        (bool sent, ) = msg.sender.call{value: value}("");
        require(decreased && sent, "StakeUtils: Failed to send ETH");
        return sent;
    }

    /**
     * @notice                ** Operator (TYPE 4 and 5) specific functions **
     */

    function isPrisoned(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) public view returns (bool _isPrisoned) {
        _isPrisoned =
            block.timestamp <=
            _DATASTORE.readUintForId(_operatorId, "released");
    }

    /** *
     * @notice operatorAllowence is the number of validators that the given Operator is allowed to create on behalf of the Planet
     * @dev an operator can not create new validators if,
     * allowence is 0 (zero) OR lower than the current number of validators.
     * But if operator withdraws a validator,then able to create a new one.
     * @dev prestake checks the approved validator count to make sure the number of validators are not bigger than allowence.
     * @dev allowence doesn't change when new validators created or old ones are unstaked.
     * @return allowance
     */
    function operatorAllowance(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _planetId,
        uint256 _operatorId
    ) public view returns (uint256 allowance) {
        allowance = _DATASTORE.readUintForId(
            _planetId,
            _getKey(_operatorId, "allowance")
        );
    }

    /**
     * @notice To allow a Node Operator run validators for your Planet with Max number of validators.
     * This number can be set again at any given point in the future.
     *
     * @dev If planet decreases the approved validator count, below current running validator,
     * operator can only withdraw until to that count (until 1 below that count).
     * @dev only maintainer of _planetId can approve an Operator
     * @param _planetId the gETH id of the Planet, only Maintainer can call this function
     * @param _operatorId the id of the Operator to allow them create validators for a given Planet
     * @param _allowance the MAX number of validators that can be created by the Operator for a given Planet
     */
    function approveOperator(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _planetId,
        uint256 _operatorId,
        uint256 _allowance
    ) external returns (bool) {
        _DATASTORE._authenticate(_planetId, true, [false, true, true]);
        _DATASTORE._authenticate(_operatorId, false, [true, true, false]);

        _DATASTORE.writeUintForId(
            _planetId,
            _getKey(_operatorId, "allowance"),
            _allowance
        );

        emit OperatorApproval(_planetId, _operatorId, _allowance);
        return true;
    }

    // DELETE THIS AND PUT IN PORTAL GEToPERATORPARAMS
    function getValidatorPeriod(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) external view returns (uint256) {
        return _DATASTORE.readUintForId(_operatorId, "validatorPeriod");
    }

    function updateValidatorPeriod(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 _newPeriod
    ) external {
        _DATASTORE._authenticate(_operatorId, true, [true, true, false]);
        _DATASTORE.writeUintForId(_operatorId, "validatorPeriod", _newPeriod);
    }

    /**
     * @notice                      ** STAKING POOL (TYPE 5 and 6)  specific functions **
     */

    function miniGovernanceById(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (IMiniGovernance) {
        return
            IMiniGovernance(_DATASTORE.readAddressForId(_id, "miniGovernance"));
    }

    function withdrawalPoolById(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (ISwap) {
        return ISwap(_DATASTORE.readAddressForId(_id, "withdrawalPool"));
    }

    function LPTokenById(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (ILPToken) {
        return ILPToken(_DATASTORE.readAddressForId(_id, "LPToken"));
    }

    /**
     * @notice pausing only prevents new staking operations.
     * when a pool is paused for staking there are NO new funds to be minted, NO surplus.
     * @dev minting is paused when stakePaused != 0
     */
    function canDeposit(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (bool) {
        return
            _DATASTORE.readUintForId(_id, "stakePaused") == 0 &&
            !(miniGovernanceById(_DATASTORE, _id).isolationMode());
    }

    /**
     * @dev pausing requires pool to be NOT paused already
     */
    function pauseStakingForPool(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) external {
        _DATASTORE._authenticate(_id, true, [false, true, true]);

        require(
            _DATASTORE.readUintForId(_id, "stakePaused") == 0,
            "StakeUtils: staking already paused"
        );

        _DATASTORE.writeUintForId(_id, "stakePaused", 1); // meaning true
        emit PausedPool(_id);
    }

    /**
     * @dev unpausing requires pool to be paused already
     */
    function unpauseStakingForPool(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) external {
        _DATASTORE._authenticate(_id, true, [false, true, true]);

        require(
            _DATASTORE.readUintForId(_id, "stakePaused") == 1,
            "StakeUtils: staking already NOT paused"
        );

        _DATASTORE.writeUintForId(_id, "stakePaused", 0); // meaning false
        emit UnpausedPool(_id);
    }

    /**
     * @notice                      ** ORACLE functions **
     */

    /**
     * @notice Batch validator verification
     */

    /**
     * @notice Updating VERIFICATION_INDEX, signaling that it is safe to allow
     * validators with lower index than VERIFICATION_INDEX to stake with staking pool funds.
     * @param validatorVerificationIndex index of the highest validator that is verified to be activated
     * @param regulatedPubkeys array of validator pubkeys that are lower than new_index which also
     * either frontrunned proposeStake function thus alienated OR proven to be mistakenly alienated.
     */
    function regulateOperators(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 allValidatorsCount,
        uint256 validatorVerificationIndex,
        uint256 unstakeVerificationIndex,
        bytes[][] calldata regulatedPubkeys,
        uint256[] calldata prisonedIds
    ) external {
        self.TELESCOPE.regulateOperators(
            _DATASTORE,
            allValidatorsCount,
            validatorVerificationIndex,
            unstakeVerificationIndex,
            regulatedPubkeys,
            prisonedIds
        );
    }

    /**
     * @notice Updating PricePerShare
     */

    function reportOracle(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        bytes32 merkleRoot,
        uint256[] calldata beaconBalances,
        bytes32[][] calldata priceProofs
    ) external {
        self.TELESCOPE.reportOracle(
            _DATASTORE,
            merkleRoot,
            beaconBalances,
            priceProofs
        );
    }

    /**
     * @notice                      ** DEPOSIT functions **
     */

    /**
     * @notice conducts a buyback using the given withdrawal pool,
     * @param to address to send bought gETH(id). burns the tokens if to=address(0), transfers if not
     * @param poolId id of the gETH that will be bought
     * @param sellEth ETH amount to sell
     * @param minToBuy TX is expected to revert by Swap.sol if not meet
     * @param deadline TX is expected to revert by Swap.sol if deadline has past
     * @dev this function assumes that pool is deployed by deployWithdrawalPool
     * as index 0 is eth and index 1 is Geth
     */
    function _buyback(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        address to,
        uint256 poolId,
        uint256 sellEth,
        uint256 minToBuy,
        uint256 deadline
    ) internal returns (uint256 outAmount) {
        // SWAP in WP
        outAmount = withdrawalPoolById(_DATASTORE, poolId).swap{value: sellEth}(
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
     * @notice staking function. buys if price is low, mints new tokens if a surplus is sent (extra ETH through msg.value)
     * @param poolId id of the staking pool, withdrawal pool and gETH to be used.
     * @param mingETH withdrawal pool parameter
     * @param deadline withdrawal pool parameter
     * // d  m.v
     * // 100 10 => buyback
     * // 100 100  => buyback
     * // 10 100  =>  buyback + mint
     * // 0 x => mint
     */
    function depositPlanet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 poolId,
        uint256 mingETH,
        uint256 deadline
    ) external returns (uint256 totalgETH) {
        _DATASTORE._authenticate(poolId, false, [false, true, false]);

        require(msg.value > 1e15, "StakeUtils: at least 0.001 eth ");
        require(deadline > block.timestamp, "StakeUtils: deadline not met");
        require(canDeposit(_DATASTORE, poolId), "StakeUtils: minting paused");
        uint256 debt = withdrawalPoolById(_DATASTORE, poolId).getDebt();
        if (debt >= msg.value) {
            return
                _buyback(
                    self,
                    _DATASTORE,
                    msg.sender,
                    poolId,
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
                    _DATASTORE,
                    msg.sender,
                    poolId,
                    debt,
                    0,
                    deadline
                );
                remEth -= debt;
            }
            uint256 mintedgETH = (
                ((remEth * self.gETH.denominator()) /
                    self.gETH.pricePerShare(poolId))
            );
            self.gETH.mint(msg.sender, poolId, mintedgETH, "");
            _DATASTORE.addUintForId(poolId, "surplus", remEth);

            require(
                boughtgETH + mintedgETH >= mingETH,
                "StakeUtils: less than mingETH"
            );
            if (self.TELESCOPE._isOracleActive()) {
                bytes32 dailyBufferKey = _getKey(
                    block.timestamp -
                        (block.timestamp % OracleUtils.ORACLE_PERIOD),
                    "mintBuffer"
                );
                _DATASTORE.addUintForId(poolId, dailyBufferKey, mintedgETH);
            }
            return boughtgETH + mintedgETH;
        }
    }

    function depositComet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 poolId
    ) external returns (uint256 totalgETH) {
        _DATASTORE._authenticate(poolId, true, [false, false, true]);
        require(false, "StakeUtils: NOT implemented");
    }

    /**
     * @notice                      ** WITHDRAWAL functions **
     */

    function _donateBalancedFees(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 poolId,
        uint256 burnSurplus,
        uint256 burnGeth
    ) internal returns (uint256 EthDonation, uint256 gEthDonation) {
        // find half of the fees to burn from surplus
        uint256 fee = withdrawalPoolById(_DATASTORE, poolId).getSwapFee();
        EthDonation = (burnSurplus * fee) / PERCENTAGE_DENOMINATOR / 2;

        // find the remaining half as gETH with respect to PPS
        gEthDonation = (burnGeth * fee) / PERCENTAGE_DENOMINATOR / 2;

        //send both fees to DWP
        withdrawalPoolById(_DATASTORE, poolId).donateBalancedFees{
            value: EthDonation
        }(EthDonation, gEthDonation);
    }

    // surplus >= ethtoburn => surplus -=ethtoburn
    // surplus < ethtoburn => surplus -= surplus
    function _burnSurplus(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 poolId,
        uint256 gEthToWithdraw
    ) internal returns (uint256, uint256) {
        uint256 pps = self.gETH.pricePerShare(poolId);

        uint256 spentGeth = gEthToWithdraw;
        uint256 spentSurplus = ((spentGeth * pps) / self.gETH.denominator());
        uint256 surplus = _DATASTORE.readUintForId(poolId, "surplus");
        if (spentSurplus >= surplus) {
            spentSurplus = surplus;
            spentGeth = ((spentSurplus * self.gETH.denominator()) / pps);
        }

        (uint256 EthDonation, uint256 gEthDonation) = _donateBalancedFees(
            _DATASTORE,
            poolId,
            spentSurplus,
            spentGeth
        );

        _DATASTORE.subUintForId(poolId, "surplus", spentSurplus);
        self.gETH.burn(address(this), poolId, spentGeth - gEthDonation);

        if (self.TELESCOPE._isOracleActive()) {
            bytes32 dailyBufferKey = _getKey(
                block.timestamp - (block.timestamp % OracleUtils.ORACLE_PERIOD),
                "burnBuffer"
            );
            _DATASTORE.addUintForId(poolId, dailyBufferKey, spentGeth);
        }

        return (spentSurplus - (EthDonation * 2), gEthToWithdraw - spentGeth);
    }

    function withdrawPlanet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 poolId,
        uint256 gEthToWithdraw,
        uint256 minETH,
        uint256 deadline
    ) external returns (uint256 EthToSend) {
        _DATASTORE._authenticate(poolId, false, [false, true, false]);

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
            _DATASTORE.readUintForId(poolId, "initiated") + self.BOOSTRAP_PERIOD
        ) {
            (EthToSend, gEthToWithdraw) = _burnSurplus(
                self,
                _DATASTORE,
                poolId,
                gEthToWithdraw
            );
        }

        if (gEthToWithdraw > 0) {
            EthToSend += withdrawalPoolById(_DATASTORE, poolId).swap(
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

    function withdrawComet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 poolId,
        uint256 gEthToWithdraw,
        uint256 minETH,
        uint256 deadline
    ) external returns (uint256 EthToSend) {
        _DATASTORE._authenticate(poolId, true, [false, false, true]);
        require(false, "StakeUtils: NOT implemented");
    }

    /**
     * @notice                      ** STAKE functions **
     */

    /**
     *  @notice Validator Credentials Proposal function, first step of crating validators. Once a pubKey is proposed and not alienated for some time,
     *  it is optimistically allowed to take funds from staking pools.
     *  @param poolId the id of the staking pool whose TYPE can be 5 or 6.
     *  @param operatorId the id of the Operator whose maintainer calling this function
     *  @param pubkeys  Array of BLS12-381 public keys of the validators that will be proposed
     *  @param signatures Array of BLS12-381 signatures of the validators that will be proposed
     *
     *  @dev DEPOSIT_AMOUNT_PRESTAKE = 1 ether, which is the minimum number to create validator.
     *  31 Ether will be staked after verification of oracles. 32 in total.
     *  1 ether will e sent back to Node Operator when finalized deposit is successful.
     *  @dev Prestake requires enough allowance from Staking Pools to Operators.
     *  @dev Prestake requires enough funds within maintainerWallet.
     *  @dev Max number of validators to propose is MAX_DEPOSITS_PER_CALL (currently 64)
     */
    function proposeStake(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 poolId,
        uint256 operatorId,
        bytes[] calldata pubkeys,
        bytes[] calldata signatures
    ) external {
        _DATASTORE._authenticate(operatorId, true, [true, true, false]);
        _DATASTORE._authenticate(poolId, false, [false, true, true]);
        require(
            !isPrisoned(_DATASTORE, operatorId),
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
            (_DATASTORE.readUintForId(operatorId, "totalActiveValidators") +
                pubkeys.length) <= self.TELESCOPE.MONOPOLY_THRESHOLD,
            "StakeUtils: IceBear does NOT like monopolies"
        );
        require(
            (_DATASTORE.readUintForId(
                poolId,
                _getKey(operatorId, "proposedValidators")
            ) +
                _DATASTORE.readUintForId(
                    poolId,
                    _getKey(operatorId, "activeValidators")
                ) +
                pubkeys.length) <=
                operatorAllowance(_DATASTORE, poolId, operatorId),
            "StakeUtils: NOT enough allowance"
        );

        require(
            _DATASTORE.readUintForId(poolId, "surplus") >=
                DCU.DEPOSIT_AMOUNT * pubkeys.length,
            "StakeUtils: NOT enough surplus"
        );

        _DATASTORE._decreaseMaintainerWallet(
            operatorId,
            pubkeys.length * DCU.DEPOSIT_AMOUNT_PRESTAKE
        );

        _DATASTORE.subUintForId(
            poolId,
            "surplus",
            (DCU.DEPOSIT_AMOUNT * pubkeys.length)
        );

        {
            uint256[2] memory fees = [
                _DATASTORE.getMaintainerFee(poolId),
                _DATASTORE.getMaintainerFee(operatorId)
            ];
            bytes memory withdrawalCredential = _DATASTORE.readBytesForId(
                poolId,
                "withdrawalCredential"
            );
            uint256 nextValidatorsIndex = self.TELESCOPE.VALIDATORS_INDEX + 1;
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
                // TODO: there is no deposit contract, solve and open this comment
                // DCU.depositValidator(
                //     pubkeys[i],
                //     withdrawalCredential,
                //     signatures[i],
                //     DCU.DEPOSIT_AMOUNT_PRESTAKE
                // );

                self.TELESCOPE._validators[pubkeys[i]] = OracleUtils.Validator(
                    1,
                    nextValidatorsIndex + i,
                    poolId,
                    operatorId,
                    fees[0],
                    fees[1],
                    signatures[i]
                );
                emit PreStaked(pubkeys[i], poolId, operatorId);
            }
        }

        _DATASTORE.addUintForId(
            poolId,
            _getKey(operatorId, "proposedValidators"),
            pubkeys.length
        );
        _DATASTORE.addUintForId(
            poolId,
            "secured",
            (DCU.DEPOSIT_AMOUNT * pubkeys.length)
        );

        self.TELESCOPE.VALIDATORS_INDEX += pubkeys.length;
    }

    /**
     *  @notice Sends 31 Eth from staking pool to validators that are previously created with PreStake.
     *  1 Eth per successful validator boostraping is returned back to MaintainerWallet.
     *
     *  @param operatorId the id of the Operator whose maintainer calling this function
     *  @param pubkeys  Array of BLS12-381 public keys of the validators that are already proposed with PreStake.
     *
     *  @dev To save gas cost, pubkeys should be arranged by planedIds.
     *  ex: [pk1, pk2, pk3, pk4, pk5, pk6, pk7]
     *  pk1, pk2, pk3 from planet1
     *  pk4, pk5 from planet2
     *  pk6 from planet3
     *  seperate them in similar groups as much as possible.
     *  @dev Max number of validators to boostrap is MAX_DEPOSITS_PER_CALL (currently 64)
     *  @dev A pubkey that is alienated will not get through. Do not frontrun during PreStake.
     */
    function beaconStake(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 operatorId,
        bytes[] calldata pubkeys
    ) external {
        _DATASTORE._authenticate(operatorId, true, [true, true, false]);

        require(
            !self.TELESCOPE._isOracleActive(),
            "StakeUtils: oracle is active"
        );
        require(
            pubkeys.length > 0 && pubkeys.length <= DCU.MAX_DEPOSITS_PER_CALL,
            "StakeUtils: MAX 64 nodes"
        );

        for (uint256 j; j < pubkeys.length; ++j) {
            require(
                self.TELESCOPE.canStake(pubkeys[j]),
                "StakeUtils: NOT all pubkeys are stakeable"
            );
        }
        {
            bytes32 activeValKey = _getKey(operatorId, "activeValidators");
            bytes32 proposedValKey = _getKey(operatorId, "proposedValidators");

            uint256 planetId = self.TELESCOPE._validators[pubkeys[0]].poolId;
            bytes memory withdrawalCredential = _DATASTORE.readBytesForId(
                planetId,
                "withdrawalCredential"
            );

            uint256 lastPlanetChange;
            for (uint256 i; i < pubkeys.length; i++) {
                if (planetId != self.TELESCOPE._validators[pubkeys[i]].poolId) {
                    _DATASTORE.subUintForId(
                        planetId,
                        "secured",
                        (DCU.DEPOSIT_AMOUNT * (i - lastPlanetChange))
                    );
                    _DATASTORE.addUintForId(
                        planetId,
                        activeValKey,
                        (i - lastPlanetChange)
                    );
                    _DATASTORE.subUintForId(
                        planetId,
                        proposedValKey,
                        (i - lastPlanetChange)
                    );
                    lastPlanetChange = i;
                    planetId = self.TELESCOPE._validators[pubkeys[i]].poolId;
                    withdrawalCredential = _DATASTORE.readBytesForId(
                        planetId,
                        "withdrawalCredential"
                    );
                }

                bytes memory signature = self
                    .TELESCOPE
                    ._validators[pubkeys[i]]
                    .signature;
                // TODO: there is no deposit contract, solve and open this comment
                // DCU.depositValidator(
                //     pubkeys[i],
                //     withdrawalCredential,
                //     signature,
                //     DCU.DEPOSIT_AMOUNT - DCU.DEPOSIT_AMOUNT_PRESTAKE
                // );

                self.TELESCOPE._validators[pubkeys[i]].state = 2;
                emit BeaconStaked(pubkeys[i]);
            }

            _DATASTORE.subUintForId(
                planetId,
                "secured",
                DCU.DEPOSIT_AMOUNT * (pubkeys.length - lastPlanetChange)
            );
            _DATASTORE.addUintForId(
                planetId,
                activeValKey,
                (pubkeys.length - lastPlanetChange)
            );
            _DATASTORE.subUintForId(
                planetId,
                proposedValKey,
                (pubkeys.length - lastPlanetChange)
            );
            _DATASTORE.addUintForId(
                operatorId,
                "totalActiveValidators",
                pubkeys.length
            );
        }
        _DATASTORE._increaseMaintainerWallet(
            operatorId,
            DCU.DEPOSIT_AMOUNT_PRESTAKE * pubkeys.length
        );
    }

    /**
     * @notice                      ** UNSTAKE functions **
     */
    function signalUnstake(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 operatorId,
        bytes calldata pk,
        uint256 balance,
        uint256 GOVERNANCE_TAX
    ) external {
        _DATASTORE._authenticate(operatorId, true, [true, true, false]);
        require(
            !self.TELESCOPE._isOracleActive(),
            "StakeUtils: oracle is active"
        );
        require(self.TELESCOPE._validators[pk].state == 2);
        self.TELESCOPE._validators[pk].state == 3;

        uint256 reward = balance - DCU.DEPOSIT_AMOUNT;

        uint256 tax = (reward * GOVERNANCE_TAX) / PERCENTAGE_DENOMINATOR;
        uint256 poolFee = (reward * self.TELESCOPE._validators[pk].poolFee) /
            PERCENTAGE_DENOMINATOR;
        uint256 operatorFee = (reward *
            self.TELESCOPE._validators[pk].operatorFee) /
            PERCENTAGE_DENOMINATOR;

        self.TELESCOPE.UNSTAKES_INDEX += 1;
        self.TELESCOPE._unstakeSignals[pk] = OracleUtils.Signal(
            self.TELESCOPE.UNSTAKES_INDEX,
            block.timestamp,
            _DATASTORE.readUintForId(
                self.TELESCOPE._validators[pk].poolId,
                "withdrawalBoost"
            ),
            balance,
            [tax, poolFee, operatorFee]
        );
        _DATASTORE.addUintForId(
            self.TELESCOPE._validators[pk].poolId,
            "signaled",
            (balance - (tax + poolFee + operatorFee))
        );
    }

    function claimUnstake(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 operatorId,
        bytes calldata pk,
        uint256 deadline
    ) external returns (uint256 tax) {
        _DATASTORE._authenticate(operatorId, true, [true, true, false]);
        require(self.TELESCOPE.canUnstake(pk), "StakeUtils: can NOT unstake");

        uint256 balance = self.TELESCOPE._unstakeSignals[pk].balance;
        uint256 poolId = self.TELESCOPE._validators[pk].poolId;

        bool success = miniGovernanceById(_DATASTORE, poolId).claimUnstake(
            balance
        );
        require(success, "StakeUtils: Failed to claim ");

        uint256[3] memory fees = self.TELESCOPE._unstakeSignals[pk].fees;

        _DATASTORE.subUintForId(poolId, "signaled", balance);

        tax = fees[0];
        balance -= tax;

        _DATASTORE._increaseMaintainerWallet(poolId, fees[1]);
        balance -= fees[1];

        {
            uint256 expectedgETH = ((balance * self.gETH.denominator()) /
                self.gETH.pricePerShare(poolId));
            uint256 boughtgETH = withdrawalPoolById(_DATASTORE, poolId)
                .calculateSwap(0, 1, balance);

            uint256 boost = (((boughtgETH - expectedgETH) *
                self.TELESCOPE._unstakeSignals[pk].withdrawalBoost) /
                PERCENTAGE_DENOMINATOR);

            _DATASTORE._increaseMaintainerWallet(
                self.TELESCOPE._validators[pk].operatorId,
                fees[2] + boost
            );
            balance -= boost;

            _buyback(
                self,
                _DATASTORE,
                address(0),
                poolId,
                balance,
                0,
                deadline
            );
        }

        _DATASTORE.addUintForId(poolId, "surplus", balance);

        _DATASTORE.subUintForId(
            poolId,
            _getKey(operatorId, "activeValidators"),
            1
        );
        _DATASTORE.subUintForId(operatorId, "totalActiveValidators", 1);
    }
}
