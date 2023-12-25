// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// external - library
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
// external - contracts
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// internal - globals
import {ID_TYPE} from "../../globals/id_type.sol";
// internal - interfaces
import {IGeodeModule} from "../../interfaces/modules/IGeodeModule.sol";
// internal - structs
import {DataStoreModuleStorage} from "../DataStoreModule/structs/storage.sol";
import {GeodeModuleStorage} from "./structs/storage.sol";
import {Proposal} from "./structs/utils.sol";
// internal - libraries
import {GeodeModuleLib as GML} from "./libs/GeodeModuleLib.sol";
import {DataStoreModuleLib as DSML} from "../DataStoreModule/libs/DataStoreModuleLib.sol";
// internal - contracts
import {DataStoreModule} from "../DataStoreModule/DataStoreModule.sol";

/**
 * @title GM: Geode Module
 *
 * @notice Base logic for Upgradable Packages:
 * * Dual Governance with Senate+Governance: Governance proposes, Senate approves.
 * * Limited Upgradability built on top of UUPS via Dual Governance.
 *
 * @dev review: this module delegates its functionality to GML (GeodeModuleLib):
 * GML has onlyGovernance, onlySenate, onlyController modifiers for access control.
 *
 * @dev There is 1 additional functionality implemented apart from the library:
 * Mutating UUPS pattern to fit Limited Upgradability:
 * 1. New implementation contract is proposed with its own package type within the limits, refer to globals/id_type.sol.
 * 2. Proposal is approved by the contract owner, Senate.
 * 3. approveProposal calls _handleUpgrade which mimics UUPS.upgradeTo:
 * 3.1. Checks the implementation address with _authorizeUpgrade, also preventing any UUPS upgrades.
 * 3.2. Upgrades the contract with no function to call afterwards.
 * 3.3. Sets contract version. Note that it does not increase linearly like one might expect.
 *
 * @dev 1 function needs to be overriden when inherited: isolationMode. (also refer to approveProposal)
 *
 * @dev __GeodeModule_init (or _unchained) call is NECESSARY when inherited.
 * However, deployer MUST call initializer after upgradeTo call,
 * should not call initializer on upgradeToAndCall or new ERC1967Proxy calls.
 *
 * @dev This module inherits DataStoreModule.
 *
 * @author Ice Bear & Crash Bandicoot
 */
abstract contract GeodeModule is IGeodeModule, UUPSUpgradeable, DataStoreModule {
  using GML for GeodeModuleStorage;

  /**
   * @custom:section                           ** VARIABLES **
   *
   * @dev Do not add any other variables here. Modules do not have a gap.
   * Library's main struct has a gap, providing up to 16 storage slots for this module.
   */

  // keccak256(abi.encode(uint256(keccak256("geode.storage.GeodeModuleStorage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant GeodeModuleStorageLocation =
    0x121584cf2b7b1dee51ceaabc76cdefc72f829ce42dd8cc5282d8e9f009b04200;

  function _getGeodeModuleStorage() internal pure returns (GeodeModuleStorage storage $) {
    assembly {
      $.slot := GeodeModuleStorageLocation
    }
  }

  /**
   * @custom:section                           ** EVENTS **
   */
  event ContractVersionSet(uint256 version);

  event ControllerChanged(uint256 indexed ID, address CONTROLLER);
  event Proposed(uint256 indexed TYPE, uint256 ID, address CONTROLLER, uint256 deadline);
  event Approved(uint256 ID);
  event NewSenate(address senate, uint256 expiry);

  /**
   * @custom:section                           ** ABSTRACT FUNCTIONS **
   */
  function isolationMode() external view virtual override returns (bool);

  /**
   * @custom:section                           ** INITIALIZING **
   */

  function __GeodeModule_init(
    address governance,
    address senate,
    uint256 senateExpiry,
    uint256 packageType,
    bytes calldata initVersionName
  ) internal onlyInitializing {
    __UUPSUpgradeable_init();
    __DataStoreModule_init();
    __GeodeModule_init_unchained(governance, senate, senateExpiry, packageType, initVersionName);
  }

  /**
   * @dev This function uses _getImplementation(), clearly deployer should not call initializer on
   * upgradeToAndCall or new ERC1967Proxy calls. _getImplementation() returns 0 then.
   * @dev GOVERNANCE and SENATE set to msg.sender at beginning, cannot propose+approve otherwise.
   * @dev native approveProposal(public) is not used here. Because it has an _handleUpgrade,
   * however initialization does not require UUPS.upgradeTo.
   */
  function __GeodeModule_init_unchained(
    address governance,
    address senate,
    uint256 senateExpiry,
    uint256 packageType,
    bytes calldata initVersionName
  ) internal onlyInitializing {
    require(governance != address(0), "GM:governance cannot be zero");
    require(senate != address(0), "GM:senate cannot be zero");
    require(senateExpiry > block.timestamp, "GM:low senateExpiry");
    require(packageType != 0, "GM:packageType cannot be zero");
    require(initVersionName.length != 0, "GM:initVersionName cannot be empty");

    GeodeModuleStorage storage $ = _getGeodeModuleStorage();
    $.GOVERNANCE = msg.sender;
    $.SENATE = msg.sender;

    $.SENATE_EXPIRY = senateExpiry;
    $.PACKAGE_TYPE = packageType;

    DataStoreModuleStorage storage DSMStorage = _getDataStoreModuleStorage();

    uint256 initVersion = $.propose(
      DSMStorage,
      ERC1967Utils.getImplementation(),
      packageType,
      initVersionName,
      1 days
    );

    $.approveProposal(DSMStorage, initVersion);

    _setContractVersion(DSML.generateId(initVersionName, $.PACKAGE_TYPE));

    $.GOVERNANCE = governance;
    $.SENATE = senate;
  }

  /**
   * @custom:section                           ** LIMITED UUPS VERSION CONTROL **
   *
   * @custom:visibility -> internal
   */

  /**
   * @dev required by the OZ UUPS module, improved by the Geode Module.
   */
  function _authorizeUpgrade(address proposed_implementation) internal virtual override {
    GeodeModuleStorage storage $ = _getGeodeModuleStorage();
    require(
      $.isUpgradeAllowed(proposed_implementation, ERC1967Utils.getImplementation()),
      "GM:not allowed to upgrade"
    );
  }

  function _setContractVersion(uint256 id) internal virtual {
    GeodeModuleStorage storage $ = _getGeodeModuleStorage();
    $.CONTRACT_VERSION = id;
    emit ContractVersionSet(id);
  }

  /**
   * @dev Would use the public upgradeTo() call, which does _authorizeUpgrade and _upgradeToAndCallUUPS,
   * but it is external, OZ have not made it public yet.
   */
  function _handleUpgrade(address proposed_implementation, uint256 id) internal virtual {
    UUPSUpgradeable.upgradeToAndCall(proposed_implementation, "");
    _setContractVersion(id);
  }

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   *
   * @custom:visibility -> view-external
   */

  function GeodeParams()
    external
    view
    virtual
    override
    returns (
      address governance,
      address senate,
      address approvedUpgrade,
      uint256 senateExpiry,
      uint256 packageType
    )
  {
    GeodeModuleStorage storage $ = _getGeodeModuleStorage();

    governance = $.GOVERNANCE;
    senate = $.SENATE;
    approvedUpgrade = $.APPROVED_UPGRADE;
    senateExpiry = $.SENATE_EXPIRY;
    packageType = $.PACKAGE_TYPE;
  }

  function getGovernance() external view virtual override returns (address) {
    GeodeModuleStorage storage $ = _getGeodeModuleStorage();
    return $.GOVERNANCE;
  }

  function getContractVersion() public view virtual override returns (uint256) {
    GeodeModuleStorage storage $ = _getGeodeModuleStorage();
    return $.CONTRACT_VERSION;
  }

  function getProposal(
    uint256 id
  ) external view virtual override returns (Proposal memory proposal) {
    GeodeModuleStorage storage $ = _getGeodeModuleStorage();
    proposal = $.getProposal(id);
  }

  /**
   * @custom:section                           ** SETTER FUNCTIONS **
   *
   * @custom:visibility -> public/external
   */

  /**
   * @custom:subsection                        ** ONLY GOVERNANCE **
   *
   */

  function propose(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) public virtual override returns (uint256 id) {
    GeodeModuleStorage storage $ = _getGeodeModuleStorage();
    id = $.propose(_getDataStoreModuleStorage(), _CONTROLLER, _TYPE, _NAME, duration);
  }

  function rescueSenate(address _newSenate) external virtual override {
    GeodeModuleStorage storage $ = _getGeodeModuleStorage();
    $.rescueSenate(_newSenate);
  }

  /**
   * @custom:subsection                        ** ONLY SENATE **
   */

  /**
   * @dev handles PACKAGE_TYPE proposals by upgrading the contract immediately.
   * @dev onlySenate is checked inside GML.approveProposal
   */
  function approveProposal(
    uint256 id
  ) public virtual override returns (address _controller, uint256 _type, bytes memory _name) {
    GeodeModuleStorage storage $ = _getGeodeModuleStorage();
    (_controller, _type, _name) = $.approveProposal(_getDataStoreModuleStorage(), id);

    if (_type == $.PACKAGE_TYPE) {
      _handleUpgrade(_controller, id);
    }
  }

  function changeSenate(address _newSenate) external virtual override {
    GeodeModuleStorage storage $ = _getGeodeModuleStorage();
    $.changeSenate(_newSenate);
  }

  /**
   * @custom:subsection                        ** ONLY CONTROLLER **
   */

  function changeIdCONTROLLER(uint256 id, address newCONTROLLER) external virtual override {
    GML.changeIdCONTROLLER(_getDataStoreModuleStorage(), id, newCONTROLLER);
  }
}
