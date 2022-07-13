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
    return DATASTORE.readAddressForId(_id, "maintainer");
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

  function beController(uint256 _id) external {
    DATASTORE.writeAddressForId(_id, "CONTROLLER", msg.sender);
  }

  function Receive() external payable {}
}