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
     * @dev changing any of address parameters (gETH, ORACLE, DEFAULT_SWAP_POOL, DEFAULT_LP_TOKEN) MUST require a contract upgrade to ensure security. We can change this in the future with a better GeodeUtils design.
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
            "StakeUtils: sender not maintainer"
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
            "StakeUtils: not CONTROLLER of given id"
        );
        require(
            _newMaintainer != address(0),
            "StakeUtils: maintainer can not be zero"
        );

        _DATASTORE.writeAddressForId(_id, "maintainer", _newMaintainer);
    }
}
