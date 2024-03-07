// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {GeodeModuleMock} from "./GeodeModuleMock.sol";
import {GeodeModuleLib} from "../../../modules/GeodeModule/libs/GeodeModuleLib.sol";
import {Proposal} from "../../../modules/GeodeModule/structs/utils.sol";

contract GeodeUpgradedMock is GeodeModuleMock {
  ///  @custom:storage-location erc7201:geode.storage.GeodeModule
  struct GeodeModuleUpgradedStorage {
    address GOVERNANCE;
    address SENATE;
    address APPROVED_UPGRADE;
    uint256 SENATE_EXPIRY;
    uint256 PACKAGE_TYPE;
    uint256 CONTRACT_VERSION;
    mapping(uint256 => Proposal) proposals;
    uint256 dumbStorageSlot;
  }

  using GeodeModuleLib for GeodeModuleUpgradedStorage;

  bytes32 private constant GeodeModuleUpgradedStorageLocation =
    0x121584cf2b7b1dee51ceaabc76cdefc72f829ce42dd8cc5282d8e9f009b04200;

  function _getGeodeModuleUpgradedStorage()
    internal
    pure
    returns (GeodeModuleUpgradedStorage storage $)
  {
    assembly {
      $.slot := GeodeModuleUpgradedStorageLocation
    }
  }

  function GeodeParamsV2()
    external
    view
    virtual
    returns (
      address governance,
      address senate,
      address approvedUpgrade,
      uint256 senateExpiry,
      uint256 packageType,
      uint256 dumbStorageSlot
    )
  {
    GeodeModuleUpgradedStorage storage $ = _getGeodeModuleUpgradedStorage();

    governance = $.GOVERNANCE;
    senate = $.SENATE;
    approvedUpgrade = $.APPROVED_UPGRADE;
    senateExpiry = $.SENATE_EXPIRY;
    packageType = $.PACKAGE_TYPE;
    dumbStorageSlot = $.dumbStorageSlot;
  }

  function initialize2(uint value) external reinitializer(2) {
    GeodeModuleUpgradedStorage storage $ = _getGeodeModuleUpgradedStorage();
    $.dumbStorageSlot = value;
  }

  function setDumb(uint value) external {
    GeodeModuleUpgradedStorage storage $ = _getGeodeModuleUpgradedStorage();
    $.dumbStorageSlot = value;
  }

  function getDumb() external view returns (uint256) {
    GeodeModuleUpgradedStorage storage $ = _getGeodeModuleUpgradedStorage();
    return $.dumbStorageSlot;
  }

  function propose(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) public virtual override returns (uint256 id) {
    require(0 == 1, "This function is overriden!");
    return 0;
  }
}
