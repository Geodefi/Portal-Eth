// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "../../utils/DataStoreLib.sol";
import "../../utils/StakeUtilsLib.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../../../interfaces/IgETH.sol";

contract TestStakeUtils is ERC1155Holder {
    using DataStoreUtils for DataStoreUtils.DataStore;
    using StakeUtils for StakeUtils.StakePool;
    DataStoreUtils.DataStore private DATASTORE;
    StakeUtils.StakePool private STAKEPOOL;

    constructor(
        address _gETH,
        address _ORACLE,
        address _DEFAULT_DWP,
        address _DEFAULT_LP_TOKEN
    ) {
        STAKEPOOL.ORACLE = _ORACLE;
        STAKEPOOL.gETH = _gETH;
        STAKEPOOL.FEE_DENOMINATOR = 10**10;
        STAKEPOOL.DEFAULT_DWP = _DEFAULT_DWP;
        STAKEPOOL.DEFAULT_LP_TOKEN = _DEFAULT_LP_TOKEN;
        STAKEPOOL.DEFAULT_A = 60;
        STAKEPOOL.DEFAULT_FEE = 4e6;
        STAKEPOOL.DEFAULT_ADMIN_FEE = 5e9;
        STAKEPOOL.PERIOD_PRICE_INCREASE_LIMIT =
            (5 * STAKEPOOL.FEE_DENOMINATOR) /
            1e3;
        STAKEPOOL.MAX_MAINTAINER_FEE = (10 * STAKEPOOL.FEE_DENOMINATOR) / 1e2; //10%
    }

    function getStakePoolParams()
        external
        view
        virtual
        returns (StakeUtils.StakePool memory)
    {
        return STAKEPOOL;
    }

    function getgETH() public view virtual returns (IgETH) {
        return STAKEPOOL.getgETH();
    }

    /**
  * Maintainer

  */
    function getMaintainerFromId(uint256 _id)
        external
        view
        virtual
        returns (address)
    {
        return StakeUtils.getMaintainerFromId(DATASTORE, _id);
    }

    function beController(uint256 _id) external {
        DATASTORE.writeAddressForId(_id, "CONTROLLER", msg.sender);
    }

    function changeIdMaintainer(uint256 _id, address _newMaintainer)
        external
        virtual
    {
        StakeUtils.changeMaintainer(DATASTORE, _id, _newMaintainer);
    }

    function setMaintainerFee(uint256 _id, uint256 _newFee) external virtual {
        STAKEPOOL.setMaintainerFee(DATASTORE, _id, _newFee);
    }

    function setMaxMaintainerFee(uint256 _newMaxFee) external virtual {
        STAKEPOOL.setMaxMaintainerFee(_newMaxFee);
    }

    function getMaintainerFee(uint256 _id)
        external
        view
        virtual
        returns (uint256)
    {
        return STAKEPOOL.getMaintainerFee(DATASTORE, _id);
    }

    function operatorAllowance(uint256 _planetId, uint256 _operatorId)
        external
        view
        returns (uint256 allowence)
    {
        allowence = StakeUtils.operatorAllowance(
            DATASTORE,
            _planetId,
            _operatorId
        );
    }

    function approveOperator(
        uint256 _planetId,
        uint256 _operatorId,
        uint256 _allowance
    ) external returns (bool success) {
        success = StakeUtils.approveOperator(
            DATASTORE,
            _planetId,
            _operatorId,
            _allowance
        );
    }

    function getOperatorWalletBalance(uint256 id)
        external
        view
        returns (uint256 balance)
    {
        balance = StakeUtils.getOperatorWalletBalance(DATASTORE, id);
    }

    function increaseOperatorWallet(uint256 id)
        external
        payable
        returns (bool success)
    {
        success = StakeUtils.increaseOperatorWallet(DATASTORE, id, msg.value);
    }

    function decreaseOperatorWallet(uint256 id, uint256 value)
        external
        returns (bool success)
    {
        success = StakeUtils.decreaseOperatorWallet(DATASTORE, id, value);
    }

    function isStakingPausedForPool(uint256 id) external view returns (bool) {
        return StakeUtils.isStakingPausedForPool(DATASTORE, id);
    }

    function pauseStakingForPool(uint256 id) external {
        StakeUtils.pauseStakingForPool(DATASTORE, id);
    }

    function unpauseStakingForPool(uint256 id) external {
        StakeUtils.unpauseStakingForPool(DATASTORE, id);
    }

    function Receive() external payable {}
}
