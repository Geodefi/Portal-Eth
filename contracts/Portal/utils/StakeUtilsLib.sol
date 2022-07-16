// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./DataStoreLib.sol";
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
     * @param gETH ERC1155 contract that keeps the totalSupply, pricePerShare and balances of all StakingPools by ID
     * @param ORACLE https://github.com/Geodefi/Telescope-Eth
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
        address gETH;
        address ORACLE;
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

    function _clone(address target) public returns (address) {
        return Clones.clone(target);
    }

    function getgETH(StakePool storage self) public view returns (IgETH) {
        return IgETH(self.gETH);
    }

    /**
     * @notice                      ** Maintainer specific functions **
     *
     * @note "Maintainer" is a shared logic like "fee" by both operators and private or public pools.
     * Maintainers have permissiones to maintain the given id like setting a new fee or interface as
     * well as paying debt etc. for operators.
     * @dev maintainer is set by CONTROLLER of given id
     */

    /// @notice even if MAX_MAINTAINER_FEE is decreased later, it returns limited maximum
    function getMaintainerFee(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (uint256) {
        return
            _DATASTORE.readUintForId(_id, "fee") > self.MAX_MAINTAINER_FEE
                ? self.MAX_MAINTAINER_FEE
                : _DATASTORE.readUintForId(_id, "fee");
    }

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

    function changeMaintainer(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        address _newMaintainer
    ) external {
        require(
            _DATASTORE.readAddressForId(_id, "CONTROLLER") == msg.sender,
            "StakeUtils: msgSender is NOT CONTROLLER of given id"
        );
        require(
            _newMaintainer != address(0),
            "StakeUtils: maintainer can NOT be zero"
        );

        _DATASTORE.writeAddressForId(_id, "maintainer", _newMaintainer);
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
}
