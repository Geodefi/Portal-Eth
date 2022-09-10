// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./DataStoreLib.sol";
import "./OracleUtilsLib.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";
import {IERC20InterfacePermitUpgradable as IgETHInterface} from "../../interfaces/IERC20InterfacePermitUpgradable.sol";
import "../../interfaces/IgETH.sol";
import "../../interfaces/ISwap.sol";
import "../../interfaces/ILPToken.sol";

/**
 * @title StakeUtils library
 * @notice Exclusively contains functions related to ETH Liquid Staking designed by Geode Finance
 * @notice biggest part of the functionality is related to Withdrawal Pools
 * which relies on continuous buybacks for price peg with DEBT/SURPLUS calculations
 * @dev Contracts relying on this library must initialize StakeUtils.StakePool
 * @dev ALL "fee" variables are limited by FEE_DENOMINATOR. For ex, when fee is equal to FEE_DENOMINATOR/2, it means 50% fee
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
    event IdInitiated(uint256 id, uint256 _type);
    event PriceChanged(uint256 id, uint256 pricePerShare);
    event MaintainerFeeUpdated(uint256 id, uint256 fee);
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
        uint256 PERIOD_PRICE_DECREASE_LIMIT_
    );

    using DataStoreUtils for DataStoreUtils.DataStore;
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
        uint256 MAX_MAINTAINER_FEE;
        uint256 BOOSTRAP_PERIOD;
        uint256 WITHDRAWAL_DELAY;
    }

    /// @notice FEE_DENOMINATOR represents 100%
    uint256 public constant FEE_DENOMINATOR = 10**10;

    uint256 public constant IGNORABLE_DEBT = 1 ether;

    /// @notice comments here
    uint256 public constant FEE_SWITCH_LATENCY = 7 days;

    /// @notice default DWP parameters
    uint256 public constant DEFAULT_A = 60;
    uint256 public constant DEFAULT_FEE = (4 * FEE_DENOMINATOR) / 10000;
    uint256 public constant DEFAULT_ADMIN_FEE = (5 * FEE_DENOMINATOR) / 10;

    modifier onlyGovernance(StakePool storage self) {
        require(
            msg.sender == self.GOVERNANCE,
            "StakeUtils: sender NOT GOVERNANCE"
        );
        _;
    }

    modifier initiator(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _type,
        uint256 _id,
        address _maintainer
    ) {
        require(
            msg.sender == _DATASTORE.readAddressForId(_id, "CONTROLLER"),
            "StakeUtils: sender NOT CONTROLLER"
        );

        require(
            _DATASTORE.readUintForId(_id, "TYPE") == _type,
            "StakeUtils: id NOT correct TYPE"
        );
        require(
            _DATASTORE.readUintForId(_id, "initiated") == 0,
            "StakeUtils: already initiated"
        );

        _DATASTORE.writeAddressForId(_id, "maintainer", _maintainer);

        _;

        _DATASTORE.writeUintForId(_id, "initiated", block.timestamp);
        emit IdInitiated(_id, _type);
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

    function _authenticate(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        bool expectMaintainer,
        bool[3] memory restrictionMap
    ) internal view {
        if (expectMaintainer) {
            require(
                msg.sender == _DATASTORE.readAddressForId(_id, "maintainer"),
                "StakeUtils: sender NOT maintainer"
            );
        }

        uint256 typeOfId = _DATASTORE.readUintForId(_id, "TYPE");
        if (typeOfId == 4) {
            require(restrictionMap[0] == true, "StakeUtils: TYPE NOT allowed");
            require(
                !isPrisoned(_DATASTORE, _id),
                "StakeUtils: operator is in prison, get in touch with governance"
            );
        } else if (typeOfId == 5) {
            require(restrictionMap[1] == true, "StakeUtils: TYPE NOT allowed");
        } else if (typeOfId == 6) {
            require(restrictionMap[2] == true, "StakeUtils: TYPE NOT allowed");
        } else revert("StakeUtils: invalid TYPE");
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
     * @notice                      ** Initiate ID functions **
     */
    /**
     * @notice initiates ID as an node operator
     * @dev requires ID to be approved as a node operator with a specific CONTROLLER
     * @param _id --
     * @param _cometPeriod --
     */
    function initiateOperator(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        uint256 _cometPeriod
    ) external initiator(_DATASTORE, 4, _id, _maintainer) {
        require(
            _fee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        _DATASTORE.writeUintForId(_id, "fee", _fee);
        _DATASTORE.writeUintForId(_id, "cometPeriod", _cometPeriod);
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
    ) external initiator(_DATASTORE, 5, _id, _maintainer) {
        require(
            _fee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        require(
            _withdrawalBoost <= FEE_DENOMINATOR,
            "StakeUtils: withdrawalBoost > 100%"
        );
        _DATASTORE.writeUintForId(_id, "fee", _fee);
        _DATASTORE.writeUintForId(_id, "withdrawalBoost", _withdrawalBoost);
        {
            IgETH gEth = self.gETH;
            IgETHInterface gInterface = IgETHInterface(
                Clones.clone(self.DEFAULT_gETH_INTERFACE)
            );
            gInterface.initialize(
                _id,
                _interfaceSpecs[0],
                _interfaceSpecs[1],
                gEth
            );
            setInterface(self, _DATASTORE, _id, address(gInterface));
        }
        address WithdrawalPool = _deployWithdrawalPool(self, _DATASTORE, _id);
        // transfer ownership of DWP to GEODE.GOVERNANCE
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
    ) external initiator(_DATASTORE, 6, _id, _maintainer) {
        require(
            _fee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        _DATASTORE.writeUintForId(_id, "fee", _fee);
    }

    /**
     * @notice                      ** Governance specific functions **
     */

    function updateGovernanceParams(
        StakePool storage self,
        address _DEFAULT_gETH_INTERFACE, // contract?
        address _DEFAULT_DWP, // contract?
        address _DEFAULT_LP_TOKEN, // contract?
        uint256 _MAX_MAINTAINER_FEE, // < 100
        uint256 _BOOSTRAP_PERIOD,
        uint256 _PERIOD_PRICE_INCREASE_LIMIT,
        uint256 _PERIOD_PRICE_DECREASE_LIMIT
    ) external onlyGovernance(self) {
        require(
            _DEFAULT_gETH_INTERFACE.code.length > 0,
            "StakeUtils: DEFAULT_gETH_INTERFACE NOT contract"
        );
        require(
            _DEFAULT_DWP.code.length > 0,
            "StakeUtils: DEFAULT_DWP NOT contract"
        );
        require(
            _DEFAULT_LP_TOKEN.code.length > 0,
            "StakeUtils: DEFAULT_LP_TOKEN NOT contract"
        );
        require(
            _PERIOD_PRICE_INCREASE_LIMIT > 0,
            "StakeUtils: incorrect PERIOD_PRICE_INCREASE_LIMIT"
        );
        require(
            _PERIOD_PRICE_DECREASE_LIMIT > 0,
            "StakeUtils: incorrect PERIOD_PRICE_DECREASE_LIMIT"
        );
        require(
            _MAX_MAINTAINER_FEE > 0 && _MAX_MAINTAINER_FEE <= FEE_DENOMINATOR,
            "StakeUtils: incorrect MAX_MAINTAINER_FEE"
        );

        self.DEFAULT_gETH_INTERFACE = _DEFAULT_gETH_INTERFACE;
        self.DEFAULT_DWP = _DEFAULT_DWP;
        self.DEFAULT_LP_TOKEN = _DEFAULT_LP_TOKEN;
        self.MAX_MAINTAINER_FEE = _MAX_MAINTAINER_FEE;
        self.BOOSTRAP_PERIOD = _BOOSTRAP_PERIOD;
        self
            .TELESCOPE
            .PERIOD_PRICE_INCREASE_LIMIT = _PERIOD_PRICE_INCREASE_LIMIT;
        self
            .TELESCOPE
            .PERIOD_PRICE_DECREASE_LIMIT = _PERIOD_PRICE_DECREASE_LIMIT;

        emit governanceParamsUpdated(
            _DEFAULT_gETH_INTERFACE,
            _DEFAULT_DWP,
            _DEFAULT_LP_TOKEN,
            _MAX_MAINTAINER_FEE,
            _BOOSTRAP_PERIOD,
            _PERIOD_PRICE_INCREASE_LIMIT,
            _PERIOD_PRICE_DECREASE_LIMIT
        );
    }

    /**
     * note onlyGovernance check
     */
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

    /**
     * @notice "Maintainer" is a shared logic (like "name") by both operators and private or public pools.
     * Maintainers have permissiones to maintain the given id like setting a new fee or interface as
     * well as creating validators etc. for operators.
     * @dev every ID has 1 maintainer that is set by CONTROLLER
     */
    function getMaintainerFromId(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) external view returns (address maintainer) {
        maintainer = _DATASTORE.readAddressForId(_id, "maintainer");
    }

    /**
     * @notice CONTROLLER of the ID can change the maintainer to any address other than ZERO_ADDRESS
     * @dev it is wise to change the CONTROLLER before the maintainer, in case of any migration
     * @dev handle with care
     * note, intended (suggested) usage is to set a contract address that will govern the id for maintainer,
     * while keeping the controller as a multisig or provide smt like 0x000000000000000000000000000000000000dEaD
     */
    function changeMaintainer(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        address _newMaintainer
    ) external {
        require(
            msg.sender == _DATASTORE.readAddressForId(_id, "CONTROLLER"),
            "StakeUtils: sender NOT CONTROLLER"
        );

        require(
            _newMaintainer != address(0),
            "StakeUtils: maintainer can NOT be zero"
        );

        _DATASTORE.writeAddressForId(_id, "maintainer", _newMaintainer);
    }

    /**
     * @notice Gets fee percentage in terms of FEE_DENOMINATOR.
     * @dev even if MAX_MAINTAINER_FEE is decreased later, it returns limited maximum.
     * @param _id planet, comet or operator ID
     * @return fee = percentage * FEE_DENOMINATOR / 100
     */
    function getMaintainerFee(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (uint256 fee) {
        fee = _DATASTORE.readUintForId(_id, "fee");
        if (_DATASTORE.readUintForId(_id, "feeSwitch") >= block.timestamp) {
            fee = _DATASTORE.readUintForId(_id, "priorFee");
        }
        if (fee > self.MAX_MAINTAINER_FEE) {
            fee = self.MAX_MAINTAINER_FEE;
        }
    }

    /**
     * @notice Changes the fee that is applied by distributeFee on Oracle Updates.
     * @dev to achieve 100% fee send FEE_DENOMINATOR
     * @param _id planet, comet or operator ID
     * @param _newFee new fee percentage in terms of FEE_DENOMINATOR,reverts if given more than MAX_MAINTAINER_FEE
     */
    function _switchMaintainerFee(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _newFee
    ) internal {
        require(
            _newFee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        _DATASTORE.writeUintForId(
            _id,
            "priorFee",
            _DATASTORE.readUintForId(_id, "fee")
        );
        _DATASTORE.writeUintForId(
            _id,
            "feeSwitch",
            block.timestamp + FEE_SWITCH_LATENCY
        );
        _DATASTORE.writeUintForId(_id, "fee", _newFee);
        emit MaintainerFeeUpdated(_id, _newFee);
    }

    function switchMaintainerFee(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _newFee
    ) external {
        _authenticate(_DATASTORE, _id, true, [true, true, true]);
        _switchMaintainerFee(self, _DATASTORE, _id, _newFee);
    }

    /**
     * @notice Operator wallet keeps Ether put in Portal by Operator to make proposeStake easier, instead of sending n ETH to contract
     * while preStaking for n validator(s) for each time. Operator can put some ETHs to their wallet
     * and from there, ETHs can be used to proposeStake. Then when it is approved and staked, it will be
     * added back to the wallet to be used for other proposeStake calls.
     * @param _operatorId the id of the Operator
     * @return walletBalance the balance of Operator with the given _operatorId has
     */
    function getMaintainerWalletBalance(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) external view returns (uint256 walletBalance) {
        walletBalance = _DATASTORE.readUintForId(_operatorId, "wallet");
    }

    /**
     * @notice To increase the balance of an Operator's wallet
     * @dev only maintainer can increase the balance
     * @param _operatorId the id of the Operator
     * @param value Ether (in Wei) amount to increase the wallet balance.
     * @return success boolean value which is true if successful, should be used by Operator is Maintainer is a contract.
     */
    function _increaseMaintainerWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) internal returns (bool success) {
        _DATASTORE.addUintForId(_operatorId, "wallet", value);
        return true;
    }

    /**
     * @notice external version of _increaseMaintainerWallet()
     */
    function increaseMaintainerWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) external returns (bool success) {
        _authenticate(_DATASTORE, _operatorId, true, [true, true, true]);

        return _increaseMaintainerWallet(_DATASTORE, _operatorId, msg.value);
    }

    /**
     * @notice To decrease the balance of an Operator's wallet
     * @dev only maintainer can decrease the balance
     * @param _operatorId the id of the Operator
     * @param value Ether (in Wei) amount to decrease the wallet balance and send back to Maintainer.
     * @return success boolean value which is "sent", should be used by Operator is Maintainer is a contract.
     */
    function _decreaseMaintainerWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) internal returns (bool success) {
        require(
            _DATASTORE.readUintForId(_operatorId, "wallet") >= value,
            "StakeUtils: NOT enough balance in wallet"
        );
        _DATASTORE.subUintForId(_operatorId, "wallet", value);
        return true;
    }

    /**
     * @notice external version of _decreaseMaintainerWallet()
     */
    function decreaseMaintainerWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) external returns (bool success) {
        _authenticate(_DATASTORE, _operatorId, true, [true, true, true]);

        require(
            address(this).balance >= value,
            "StakeUtils: not enough balance in Portal (?)"
        );

        bool decreased = _decreaseMaintainerWallet(
            _DATASTORE,
            _operatorId,
            value
        );

        (bool sent, ) = msg.sender.call{value: value}("");
        require(decreased && sent, "StakeUtils: Failed to send ETH");
        return sent;
    }

    /**
     * @notice                ** Operator and Planet (TYPE 4 and 5) specific functions **
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
        _authenticate(_DATASTORE, _planetId, true, [false, true, true]);
        _authenticate(_DATASTORE, _operatorId, false, [true, true, false]);

        _DATASTORE.writeUintForId(
            _planetId,
            _getKey(_operatorId, "allowance"),
            _allowance
        );

        emit OperatorApproval(_planetId, _operatorId, _allowance);
        return true;
    }

    function getCometPeriod(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) external view returns (uint256) {
        return _DATASTORE.readUintForId(_operatorId, "cometPeriod");
    }

    function updateCometPeriod(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 _newPeriod
    ) external {
        _authenticate(_DATASTORE, _operatorId, true, [true, true, false]);
        _DATASTORE.writeUintForId(_operatorId, "cometPeriod", _newPeriod);
    }

    /**
     * @notice                      ** WITHDRAWAL POOL specific functions **
     */

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
     * @notice deploys a new withdrawal pool using DEFAULT_DWP
     * @dev sets the withdrawal pool and LP token for id
     */
    function _deployWithdrawalPool(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) internal returns (address WithdrawalPool) {
        WithdrawalPool = Clones.clone(self.DEFAULT_DWP);

        address _WPToken = ISwap(WithdrawalPool).initialize(
            self.gETH,
            _id,
            string(
                abi.encodePacked(
                    _DATASTORE.readBytesForId(_id, "name"),
                    "-Geode WP Token"
                )
            ),
            string(
                abi.encodePacked(_DATASTORE.readBytesForId(_id, "name"), "-WP")
            ),
            DEFAULT_A,
            DEFAULT_FEE,
            DEFAULT_ADMIN_FEE,
            self.DEFAULT_LP_TOKEN
        );
        _DATASTORE.writeAddressForId(_id, "withdrawalPool", WithdrawalPool);
        _DATASTORE.writeAddressForId(_id, "LPToken", _WPToken);
    }

    /**
     * @notice pausing only prevents new staking operations.
     * when a pool is paused for staking there are NO new funds to be minted, NO surplus.
     * @dev minting is paused when stakePaused != 0
     */
    function isStakingPausedForPool(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (bool) {
        return _DATASTORE.readUintForId(_id, "stakePaused") != 0;
    }

    /**
     * @dev pausing requires pool to be NOT paused
     */
    function pauseStakingForPool(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) external {
        _authenticate(_DATASTORE, _id, true, [false, true, true]);

        require(
            !isStakingPausedForPool(_DATASTORE, _id),
            "StakeUtils: staking already paused"
        );

        _DATASTORE.writeUintForId(_id, "stakePaused", 1); // meaning true
        emit PausedPool(_id);
    }

    /**
     * @dev pausing requires pool to be NOT paused
     */
    function unpauseStakingForPool(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) external {
        _authenticate(_DATASTORE, _id, true, [false, true, true]);

        require(
            isStakingPausedForPool(_DATASTORE, _id),
            "StakeUtils: staking already NOT paused"
        );

        _DATASTORE.writeUintForId(_id, "stakePaused", 0); // meaning false
        emit UnpausedPool(_id);
    }

    /**
     * @notice                      ** ORACLE specific functions **
     */

    /**
     * @notice Batch validator verification
     */

    /**
     * @notice Updating VERIFICATION_INDEX, signaling that it is safe to allow
     * validators with lower index than VERIFICATION_INDEX to stake with staking pool funds.
     * @param newVerificationIndex index of the highest validator that is verified to be activated
     * @param regulatedPubkeys array of validator pubkeys that are lower than new_index which also
     * either frontrunned proposeStake function thus alienated OR proven to be mistakenly alienated.
     */
    function regulateOperators(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 allValidatorsCount,
        uint256 newVerificationIndex,
        bytes[][] calldata regulatedPubkeys,
        uint256[] calldata prisonedIds
    ) external {
        self.TELESCOPE.regulateOperators(
            _DATASTORE,
            allValidatorsCount,
            newVerificationIndex,
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
     * @notice                      * STAKING functions *
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
        _authenticate(_DATASTORE, poolId, false, [false, true, false]);

        require(msg.value > 1e15, "StakeUtils: at least 0.001 eth ");
        require(deadline > block.timestamp, "StakeUtils: deadline not met");
        require(
            !isStakingPausedForPool(_DATASTORE, poolId),
            "StakeUtils: minting paused"
        );
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

    function _donateBalancedFees(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 poolId,
        uint256 burnSurplus,
        uint256 burnGeth
    ) internal returns (uint256 EthDonation, uint256 gEthDonation) {
        // find half of the fees to burn from surplus
        uint256 fee = withdrawalPoolById(_DATASTORE, poolId).getSwapFee();
        EthDonation = (burnSurplus * fee) / FEE_DENOMINATOR / 2;

        // find the remaining half as gETH with respect to PPS
        gEthDonation = (burnGeth * fee) / FEE_DENOMINATOR / 2;

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
        _authenticate(_DATASTORE, poolId, false, [false, true, false]);

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

    /**
     * @notice                      ** Validator Creation functions **
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
        _authenticate(_DATASTORE, operatorId, true, [true, true, false]);
        _authenticate(_DATASTORE, poolId, false, [false, true, true]);

        require(
            pubkeys.length == signatures.length,
            "StakeUtils: pubkeys and signatures NOT same length"
        );
        require(
            pubkeys.length > 0 && pubkeys.length <= DCU.MAX_DEPOSITS_PER_CALL,
            "StakeUtils: MAX 64 nodes"
        );
        require(
            (_DATASTORE.readUintForId(operatorId, "totalProposedValidators") +
                pubkeys.length) <= self.TELESCOPE.MONOPOLY_THRESHOLD,
            "StakeUtils: IceBear does NOT like monopolies"
        );
        require(
            (_DATASTORE.readUintForId(
                poolId,
                _getKey(operatorId, "proposedValidators")
            ) + pubkeys.length) <=
                operatorAllowance(_DATASTORE, poolId, operatorId),
            "StakeUtils: NOT enough allowance"
        );

        require(
            _DATASTORE.readUintForId(poolId, "surplus") >=
                DCU.DEPOSIT_AMOUNT * pubkeys.length,
            "StakeUtils: NOT enough surplus"
        );

        _decreaseMaintainerWallet(
            _DATASTORE,
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
                getMaintainerFee(self, _DATASTORE, poolId),
                getMaintainerFee(self, _DATASTORE, operatorId)
            ];
            // bytes memory withdrawalCredential = _DATASTORE.readBytesForId(
            //     poolId,
            //     "withdrawalCredential"
            // );
            uint256 nextValidatorsIndex = self.TELESCOPE.VALIDATORS_INDEX + 1;
            for (uint256 i; i < pubkeys.length; i++) {
                require(
                    self.TELESCOPE.Validators[pubkeys[i]].state == 0,
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

                self.TELESCOPE.Validators[pubkeys[i]] = OracleUtils.Validator(
                    1,
                    nextValidatorsIndex + i,
                    poolId,
                    operatorId,
                    fees[0],
                    fees[1],
                    // withdrawalContract(),
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
            operatorId,
            "totalProposedValidators",
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
        _authenticate(_DATASTORE, operatorId, true, [true, true, false]);

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

            uint256 planetId = self.TELESCOPE.Validators[pubkeys[0]].poolId;
            bytes memory withdrawalCredential = _DATASTORE.readBytesForId(
                planetId,
                "withdrawalCredential"
            );

            uint256 lastPlanetChange;
            for (uint256 i; i < pubkeys.length; i++) {
                if (planetId != self.TELESCOPE.Validators[pubkeys[i]].poolId) {
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

                    lastPlanetChange = i;
                    planetId = self.TELESCOPE.Validators[pubkeys[i]].poolId;
                    withdrawalCredential = _DATASTORE.readBytesForId(
                        planetId,
                        "withdrawalCredential"
                    );
                }

                // bytes memory signature = self.TELESCOPE.Validators[pubkeys[i]].signature;
                // TODO: there is no deposit contract, solve and open this comment
                // DCU.depositValidator(
                //     pubkeys[i],
                //     withdrawalCredential,
                //     signature,
                //     DCU.DEPOSIT_AMOUNT - DCU.DEPOSIT_AMOUNT_PRESTAKE
                // );

                self.TELESCOPE.Validators[pubkeys[i]].state = 2;
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
                pubkeys.length - lastPlanetChange
            );
        }

        _increaseMaintainerWallet(
            _DATASTORE,
            operatorId,
            DCU.DEPOSIT_AMOUNT_PRESTAKE * pubkeys.length
        );
    }
}
