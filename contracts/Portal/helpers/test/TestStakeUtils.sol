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
        address _DEFAULT_LP_TOKEN,
        address _DEFAULT_gETH_INTERFACE
    ) {
        STAKEPOOL.ORACLE = _ORACLE;
        STAKEPOOL.gETH = _gETH;
        STAKEPOOL.FEE_DENOMINATOR = 10**10;
        STAKEPOOL.DEFAULT_DWP = _DEFAULT_DWP;
        STAKEPOOL.DEFAULT_LP_TOKEN = _DEFAULT_LP_TOKEN;
        STAKEPOOL.DEFAULT_gETH_INTERFACE = _DEFAULT_gETH_INTERFACE;
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

    function setType(uint256 _id, uint256 _type) external {
        DATASTORE.writeUintForId(_id, "TYPE", _type);
    }

    function getERC1155() external view virtual returns (IgETH) {
        return STAKEPOOL.getgETH();
    }

    function mintgETH(
        address _to,
        uint256 _id,
        uint256 _amount
    ) external virtual {
        StakeUtils._mint(address(STAKEPOOL.getgETH()), _to, _id, _amount);
    }

    function buyback(
        address to,
        uint256 poolId,
        uint256 sellEth,
        uint256 minToBuy,
        uint256 deadline
    ) external returns (uint256 outAmount) {
        outAmount = STAKEPOOL._buyback(
            DATASTORE,
            to,
            poolId,
            sellEth,
            minToBuy,
            deadline
        );
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

    function setInterface(
        uint256 _planetId,
        address _interface,
        bool isSet
    ) external {
        STAKEPOOL._setInterface(DATASTORE, _planetId, _interface, isSet);
    }

    function currentInterface(uint256 _id)
        external
        view
        virtual
        returns (address)
    {
        return DATASTORE.readAddressForId(_id, "currentInterface");
    }

    function isInitiated(uint256 _planetId)
        external
        view
        virtual
        returns (uint256)
    {
        return DATASTORE.readUintForId(_planetId, "initiated");
    }

    function initiateOperator(
        uint256 _planetId,
        uint256 _fee,
        address _maintainer
    ) external {
        STAKEPOOL.initiateOperator(DATASTORE, _planetId, _fee, _maintainer);
    }

    function initiatePlanet(
        uint256 _planetId,
        uint256 _fee,
        address _maintainer,
        address _governance,
        string memory _interfaceName,
        string memory _interfaceSymbol
    ) external {
        STAKEPOOL.initiatePlanet(
            DATASTORE,
            _planetId,
            _fee,
            _maintainer,
            _governance,
            _interfaceName,
            _interfaceSymbol
        );
    }

    function initiateComet(
        uint256 _planetId,
        uint256 _fee,
        address _maintainer
    ) external {
        STAKEPOOL.initiateComet(DATASTORE, _planetId, _fee, _maintainer);
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

    function deployWithdrawalPool(uint256 _id)
        external
        returns (address WithdrawalPool)
    {
        WithdrawalPool = STAKEPOOL._deployWithdrawalPool(DATASTORE, _id);
    }

    function withdrawalPoolById(uint256 _id)
        external
        view
        virtual
        returns (address)
    {
        return address(StakeUtils.withdrawalPoolById(DATASTORE, _id));
    }

    function LPTokenById(uint256 _id) external view virtual returns (address) {
        return address(StakeUtils.LPTokenById(DATASTORE, _id));
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
