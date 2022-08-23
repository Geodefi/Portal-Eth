// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DataStoreLib.sol";
import "../gETHInterfaces/ERC20InterfacePermitUpgradable.sol";
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
 * properties like staking pools - relates to params: stBalance, surplus, withdrawalPool - relates to debt -
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
    using DataStoreUtils for DataStoreUtils.DataStore;
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

    /**
     * @notice StakePool includes the parameters related to multiple Staking Pool Contracts.
     * @notice A staking pool works with a *bound* Withdrawal Pool (DWP) to create best pricing
     * for the staking derivative. Withdrawal Pools (DWP) uses StableSwap algorithm with Dynamic Pegs.
     * @dev  gETH should not be changed, ever!
     * @param ORACLE https://github.com/Geodefi/Telescope-Eth
     * @param gETH ERC1155 contract that keeps the totalSupply, pricePerShare and balances of all StakingPools by ID
     * @param DEFAULT_gETH_INTERFACE
     * @param DEFAULT_DWP Dynamic Withdrawal Pool, a STABLESWAP pool that will be cloned to be used for given ID
     * @param DEFAULT_LP_TOKEN LP token implementation that will be cloned to be used for DWP of given ID
     * @param DEFAULT_A DWP parameter
     * @param DEFAULT_FEE DWP parameter
     * @param DEFAULT_ADMIN_FEE DWP parameter
     * @param FEE_DENOMINATOR represents 100%, ALSO DWP parameter
     * @param MAX_MAINTAINER_FEE : limits fees, set by GOVERNANCE
     * @dev changing any of address parameters (gETH, ORACLE, DEFAULT_DWP, DEFAULT_LP_TOKEN) MUST require a contract upgrade to ensure security. We can change this in the future with a better GeodeUtils design.
     **/
    struct StakePool {
        address ORACLE;
        address gETH;
        address DEFAULT_gETH_INTERFACE;
        address DEFAULT_DWP;
        address DEFAULT_LP_TOKEN;
        uint256 DEFAULT_A;
        uint256 DEFAULT_FEE;
        uint256 DEFAULT_ADMIN_FEE;
        uint256 FEE_DENOMINATOR;
        uint256 PERIOD_PRICE_INCREASE_LIMIT;
        uint256 MAX_MAINTAINER_FEE;
    }

    modifier onlyMaintainer(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) {
        require(
            _DATASTORE.readAddressForId(_id, "maintainer") == msg.sender,
            "StakeUtils: sender is NOT maintainer"
        );
        _;
    }

    modifier initiator(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _type,
        uint256 _fee,
        address _maintainer
    ) {
        require(
            _DATASTORE.readAddressForId(_id, "CONTROLLER") == msg.sender,
            "StakeUtils: sender is NOT CONTROLLER"
        );

        require(
            _DATASTORE.readUintForId(_id, "TYPE") == _type,
            "StakeUtils: id should be Operator TYPE"
        );
        require(
            _DATASTORE.readUintForId(_id, "initiated") == 0,
            "StakeUtils: already initiated"
        );
        _DATASTORE.writeAddressForId(_id, "maintainer", _maintainer);

        _;

        _DATASTORE.writeUintForId(_id, "initiated", 1);
        emit IdInitiated(_id, _type);
    }

    function _clone(address target) public returns (address) {
        return Clones.clone(target);
    }

    function getgETH(StakePool storage self) public view returns (IgETH) {
        return IgETH(self.gETH);
    }

    /**
     *  @notice if a planet did not unset an old Interface, before setting a new one;
     *  & if new interface is unsetted, the old one will not be remembered!!
     *  use gETH.isInterface(interface,  id)
     * @param _Interface address of the new gETH ERC1155 interface for given ID
     * @param isSet true if new interface is going to be set, false if old interface is being unset
     */
    function _setInterface(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        address _Interface,
        bool isSet
    ) internal {
        getgETH(self).setInterface(_Interface, _id, isSet);
        if (isSet)
            _DATASTORE.writeAddressForId(_id, "currentInterface", _Interface);
        else if (
            _DATASTORE.readAddressForId(_id, "currentInterface") == _Interface
        ) _DATASTORE.writeAddressForId(_id, "currentInterface", address(0));
    }

    /**
     * @notice                      ** Initiate ID functions **
     */
    /**
     * @notice initiates ID as an node operator
     * @dev requires ID to be approved as a node operator with a specific CONTROLLER
     * @param _id operator ID
     */
    function initiateOperator(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer
    ) external initiator(_DATASTORE, _id, 4, _fee, _maintainer) {}

    /**
     * @notice initiates ID as a planet (public pool)
     * @dev requires ID to be approved as a planet with a specific CONTROLLER
     * @param _id planet ID to initiate
     */
    function initiatePlanet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        address _governance,
        string memory _interfaceName,
        string memory _interfaceSymbol
    ) external initiator(_DATASTORE, _id, 5, _fee, _maintainer) {
        {
            address currentInterface = _clone(self.DEFAULT_gETH_INTERFACE);
            address gEth = address(getgETH(self));
            ERC20InterfacePermitUpgradable(currentInterface).initialize(
                _id,
                _interfaceName,
                _interfaceSymbol,
                gEth
            );
            _setInterface(self, _DATASTORE, _id, currentInterface, true);
        }

        address WithdrawalPool = _deployWithdrawalPool(self, _DATASTORE, _id);
        // transfer ownership of DWP to GEODE.GOVERNANCE
        Ownable(WithdrawalPool).transferOwnership(_governance);
        // approve token so we can use it in buybacks
        getgETH(self).setApprovalForAll(WithdrawalPool, true);
        // initially 1 ETHER = 1 ETHER
        _setPricePerShare(self, 1 ether, _id);
    }

    /**
     * @notice initiates ID as a comet (private pool)
     * @dev requires ID to be approved as comet with a specific CONTROLLER
     * @param _id comet ID to initiate
     */
    function initiateComet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer
    ) external initiator(_DATASTORE, _id, 6, _fee, _maintainer) {}

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
            _DATASTORE.readAddressForId(_id, "CONTROLLER") == msg.sender,
            "StakeUtils: sender is NOT CONTROLLER"
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
        return
            _DATASTORE.readUintForId(_id, "fee") > self.MAX_MAINTAINER_FEE
                ? self.MAX_MAINTAINER_FEE
                : _DATASTORE.readUintForId(_id, "fee");
    }

    /**
     * @notice Changes the fee that is applied by distributeFee on Oracle Updates.
     * @dev to achieve 100% fee send FEE_DENOMINATOR
     * @param _id planet, comet or operator ID
     * @param _newFee new fee percentage in terms of FEE_DENOMINATOR,reverts if given more than MAX_MAINTAINER_FEE
     */
    function setMaintainerFee(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _newFee
    ) external onlyMaintainer(_DATASTORE, _id) {
        require(
            _newFee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        _DATASTORE.writeUintForId(_id, "fee", _newFee);
        emit MaintainerFeeUpdated(_id, _newFee);
    }

    /**
     * @notice Changes MAX_MAINTAINER_FEE, limits "fee" parameter of every ID.
     * @dev to achieve 100% fee send FEE_DENOMINATOR
     * @param _newMaxFee new fee percentage in terms of FEE_DENOMINATOR, reverts if more than FEE_DENOMINATOR
     * note onlyGovernance check should be handled in PORTAL.sol directly.
     */
    function setMaxMaintainerFee(StakePool storage self, uint256 _newMaxFee)
        external
    {
        require(
            _newMaxFee <= self.FEE_DENOMINATOR,
            "StakeUtils: fee more than 100%"
        );
        self.MAX_MAINTAINER_FEE = _newMaxFee;
        emit MaxMaintainerFeeUpdated(_newMaxFee);
    }

    /**
     * @notice                      ** Operator (TYPE 4) specific functions **
     */

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
            bytes32(keccak256(abi.encodePacked(_operatorId, "allowance")))
        );
    }

    /**
     * @notice To allow a Node Operator run validators for your Planet with Max number of validators.
     * This number can be set again at any given point in the future.
     *
     * @dev If planet decreases the approved validator count, below current running validator,
     * operator can only withdraw until to that count (until 1 below that count).
     * @dev only maintainer of _planetId can approve an Operator
     * @dev key for the allowance is: bytes32(keccak256(abi.encodePacked(_operatorId, "allowance")))
     * @param _planetId the gETH id of the Planet, only Maintainer can call this function
     * @param _operatorId the gETH id of the Operator to allow them create validators for a given Planet
     * @param _allowance the MAX number of validators that can be created by the Operator for a given Planet
     */
    function approveOperator(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _planetId,
        uint256 _operatorId,
        uint256 _allowance
    ) external onlyMaintainer(_DATASTORE, _planetId) returns (bool) {
        _DATASTORE.writeUintForId(
            _planetId,
            bytes32(keccak256(abi.encodePacked(_operatorId, "allowance"))),
            _allowance
        );
        emit OperatorApproval(_planetId, _operatorId, _allowance);
        return true;
    }

    /**
     * @notice Operator wallet keeps Ether put in Portal by Operator to make preStake easier, instead of sending n ETH to contract
     * while preStaking for n validator(s) for each time. Operator can put some ETHs to their wallet
     * and from there, ETHs can be used to preStake. Then when it is approved and staked, it will be
     * added back to the wallet to be used for other preStake calls.
     * @param _operatorId the gETH id of the Operator
     * @return walletBalance the balance of Operator with the given _operatorId has
     */
    function getOperatorWalletBalance(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) public view returns (uint256 walletBalance) {
        walletBalance = _DATASTORE.readUintForId(_operatorId, "wallet");
    }

    /**
     * @notice To increase the balance of an Operator's wallet
     * @dev only maintainer can increase the balance
     * @param _operatorId the id of the Operator
     * @param value Ether (in Wei) amount to increase the wallet balance.
     * @return success boolean value which is true if successful, should be used by Operator is Maintainer is a contract.
     */
    function increaseOperatorWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) external onlyMaintainer(_DATASTORE, _operatorId) returns (bool success) {
        require(value > 0, "StakeUtils: The value must be greater than 0");
        uint256 _wallet = _DATASTORE.readUintForId(_operatorId, "wallet");
        _wallet += value;
        _DATASTORE.writeUintForId(_operatorId, "wallet", _wallet);
        return true;
    }

    /**
     * @notice To decrease the balance of an Operator's wallet
     * @dev only maintainer can decrease the balance
     * @param _operatorId the id of the Operator
     * @param value Ether (in Wei) amount to decrease the wallet balance and send back to Maintainer.
     * @return success boolean value which is "sent", should be used by Operator is Maintainer is a contract.
     */
    function decreaseOperatorWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) external onlyMaintainer(_DATASTORE, _operatorId) returns (bool success) {
        require(
            address(this).balance >= value,
            "StakeUtils: Not enough resources in Portal"
        );
        uint256 _wallet = _DATASTORE.readUintForId(_operatorId, "wallet");
        require(
            _wallet >= value,
            "StakeUtils: Not enough resources in operatorWallet"
        );
        _wallet -= value;
        _DATASTORE.writeUintForId(_operatorId, "wallet", _wallet);
        (bool sent, ) = msg.sender.call{value: value}("");
        require(sent, "StakeUtils: Failed to send ETH");
        return sent;
    }

    /**
     * @notice                      ** WITHDRAWAL POOL specific functions **
     */

    /**
     * @notice deploys a new withdrawal pool using DEFAULT_DWP
     * @dev sets the withdrawal pool and LP token for id
     */
    function _deployWithdrawalPool(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) internal returns (address WithdrawalPool) {
        WithdrawalPool = _clone(self.DEFAULT_DWP);

        address _WPToken = ISwap(WithdrawalPool).initialize(
            address(getgETH(self)),
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
            self.DEFAULT_A,
            self.DEFAULT_FEE,
            self.DEFAULT_ADMIN_FEE,
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
    ) external onlyMaintainer(_DATASTORE, _id) {
        require(
            !isStakingPausedForPool(_DATASTORE, _id),
            "StakeUtils: staking is already paused for pool"
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
    ) external onlyMaintainer(_DATASTORE, _id) {
        require(
            isStakingPausedForPool(_DATASTORE, _id),
            "StakeUtils: staking is already NOT paused for pool"
        );
        _DATASTORE.writeUintForId(_id, "stakePaused", 0); // meaning false
        emit UnpausedPool(_id);
    }

    /**
     * @notice                      ** PLANET specific functions **
     */
    /**
     * @notice                      ** ORACLE specific functions **
     */

    /**
     * @notice sets pricePerShare parameter of gETH(id)
     * @dev only ORACLE should be able to reach this after sanity checks on a new price
     */
    function _setPricePerShare(
        StakePool storage self,
        uint256 pricePerShare_,
        uint256 _id
    ) internal {
        require(_id > 0, "StakeUtils: id should be > 0");
        getgETH(self).setPricePerShare(pricePerShare_, _id);
        emit PriceChanged(_id, pricePerShare_);
    }
}
