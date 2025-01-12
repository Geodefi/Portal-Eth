// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

// import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
// // structs
// import {Proposal} from "../../../modules/GeodeModule/structs/utils.sol";
// // globals
// import {ID_TYPE} from "../../../globals/id_type.sol";
// // interfaces
// import {IGeodeModuleV3_0_Mock} from "./interfaces/IGeodeModuleV3_0_Mock.sol";
// // libraries
// import {GeodeModuleLibV3_0_Mock as GML, DualGovernanceV3_0_Mock} from "./GeodeModuleLibV3_0_Mock.sol";
// import {DataStoreModuleLib as DSML} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";
// // contracts
// import {DataStoreModule} from "../../../modules/DataStoreModule/DataStoreModule.sol";
// // external
// import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// /**
//  * @title GM: Geode Module
//  *
//  * @notice Base logic for Upgradable Packages:
//  * * Dual Governance with Senate+Governance: Governance proposes, Senate approves.
//  * * Limited Upgradability built on top of UUPS via Dual Governance.
//  *
//  * @dev review: this module delegates its functionality to GML (GeodeModuleLib):
//  * GML has onlyGovernance, onlySenate, onlyController modifiers for access control.
//  *
//  * @dev There is 1 additional functionality implemented apart from the library:
//  * Mutating UUPS pattern to fit Limited Upgradability:
//  * 1. New implementation contract is proposed with its own package type within the limits, refer to globals/id_type.sol.
//  * 2. Proposal is approved by the contract owner, Senate.
//  * 3. approveProposal calls _handleUpgrade which mimics UUPS.upgradeTo:
//  * 3.1. Checks the implementation address with _authorizeUpgrade, also preventing any UUPS upgrades.
//  * 3.2. Upgrades the contract with no function to call afterwards.
//  * 3.3. Sets contract version. Note that it does not increase linearly like one might expect.
//  *
//  * @dev 1 function needs to be overriden when inherited: isolationMode. (also refer to approveProposal)
//  *
//  * @dev __GeodeModule_init (or _unchained) call is NECESSARY when inherited.
//  * However, deployer MUST call initializer after upgradeTo call,
//  * should not call initializer on upgradeToAndCall or new ERC1967Proxy calls.
//  *
//  * @dev This module inherits DataStoreModule.
//  *
//  * @author Ice Bear & Crash Bandicoot
//  */
// abstract contract GeodeModuleV3_0_Mock is IGeodeModuleV3_0_Mock, UUPSUpgradeable, DataStoreModule {
//   using GML for DualGovernanceV3_0_Mock;

//   /**
//    * @custom:section                           ** VARIABLES **
//    *
//    * @dev Do not add any other variables here. Modules do not have a gap.
//    * Library's main struct has a gap, providing up to 16 storage slots for this module.
//    */
//   DualGovernanceV3_0_Mock internal GEODE;

//   /**
//    * @custom:section                           ** EVENTS **
//    */
//   event ContractVersionSet(uint256 version);

//   event ControllerChanged(uint256 indexed ID, address CONTROLLER);
//   event Proposed(uint256 indexed TYPE, uint256 ID, address CONTROLLER, uint256 deadline);
//   event Approved(uint256 ID);
//   event NewSenate(address senate, uint256 expiry);

//   /**
//    * @custom:section                           ** ABSTRACT FUNCTIONS **
//    */
//   function isolationMode() external view virtual override returns (bool);

//   /**
//    * @custom:section                           ** INITIALIZING **
//    */

//   function __GeodeModule_init(
//     address governance,
//     address senate,
//     uint256 senateExpiry,
//     uint256 packageType,
//     bytes calldata initVersionName
//   ) internal onlyInitializing {
//     __UUPSUpgradeable_init();
//     __DataStoreModule_init();
//     __GeodeModule_init_unchained(governance, senate, senateExpiry, packageType, initVersionName);
//   }

//   /**
//    * @dev This function uses _getImplementation(), clearly deployer should not call initializer on
//    * upgradeToAndCall or new ERC1967Proxy calls. _getImplementation() returns 0 then.
//    * @dev GOVERNANCE and SENATE set to msg.sender at beginning, cannot propose+approve otherwise.
//    * @dev native approveProposal(public) is not used here. Because it has an _handleUpgrade,
//    * however initialization does not require UUPS.upgradeTo.
//    */
//   function __GeodeModule_init_unchained(
//     address governance,
//     address senate,
//     uint256 senateExpiry,
//     uint256 packageType,
//     bytes calldata initVersionName
//   ) internal onlyInitializing {
//     require(governance != address(0), "GM:governance cannot be zero");
//     require(senate != address(0), "GM:senate cannot be zero");
//     require(senateExpiry > block.timestamp, "GM:low senateExpiry");
//     require(packageType != 0, "GM:packageType cannot be zero");
//     require(initVersionName.length != 0, "GM:initVersionName cannot be empty");

//     GEODE.GOVERNANCE = msg.sender;
//     GEODE.SENATE = msg.sender;

//     GEODE.SENATE_EXPIRY = senateExpiry;
//     GEODE.PACKAGE_TYPE = packageType;

//     uint256 initVersion = GEODE.propose(
//       DATASTORE,
//       ERC1967Utils.getImplementation(),
//       packageType,
//       initVersionName,
//       1 days
//     );

//     GEODE.approveProposal(DATASTORE, initVersion);

//     _setContractVersion(DSML.generateId(initVersionName, GEODE.PACKAGE_TYPE));

//     GEODE.GOVERNANCE = governance;
//     GEODE.SENATE = senate;
//   }

//   function __GeodeModule_initV3_0_Mock(uint256 value) internal onlyInitializing {
//     GEODE.setFreshSlot(value);
//   }

//   function setFreshSlot(uint256 value) public virtual override {
//     GEODE.setFreshSlot(value);
//   }

//   function getFreshSlot() external view virtual override returns (uint256) {
//     return GEODE.getFreshSlot();
//   }

//   /**
//    * @custom:section                           ** LIMITED UUPS VERSION CONTROL **
//    *
//    * @custom:visibility -> internal
//    */

//   /**
//    * @dev required by the OZ UUPS module, improved by the Geode Module.
//    */
//   function _authorizeUpgrade(address proposed_implementation) internal virtual override {
//     require(
//       GEODE.isUpgradeAllowed(proposed_implementation, ERC1967Utils.getImplementation()),
//       "GM:not allowed to upgrade"
//     );
//   }

//   function _setContractVersion(uint256 id) internal virtual {
//     GEODE.CONTRACT_VERSION = id;
//     emit ContractVersionSet(id);
//   }

//   /**
//    * @dev Would use the public upgradeTo() call, which does _authorizeUpgrade and _upgradeToAndCallUUPS,
//    * but it is external, OZ have not made it public yet.
//    */
//   function _handleUpgrade(address proposed_implementation, uint256 id) internal virtual {
//     upgradeToAndCall(proposed_implementation, "");
//     _setContractVersion(id);
//   }

//   /**
//    * @custom:section                           ** GETTER FUNCTIONS **
//    *
//    * @custom:visibility -> view-external
//    */

//   function GeodeParams()
//     external
//     view
//     virtual
//     override
//     returns (
//       address governance,
//       address senate,
//       address approvedUpgrade,
//       uint256 senateExpiry,
//       uint256 packageType
//     )
//   {
//     governance = GEODE.GOVERNANCE;
//     senate = GEODE.SENATE;
//     approvedUpgrade = GEODE.APPROVED_UPGRADE;
//     senateExpiry = GEODE.SENATE_EXPIRY;
//     packageType = GEODE.PACKAGE_TYPE;
//   }

//   function getContractVersion() public view virtual override returns (uint256) {
//     return GEODE.CONTRACT_VERSION;
//   }

//   function getProposal(
//     uint256 id
//   ) external view virtual override returns (Proposal memory proposal) {
//     proposal = GEODE.getProposal(id);
//   }

//   /**
//    * @custom:section                           ** SETTER FUNCTIONS **
//    *
//    * @custom:visibility -> public/external
//    */

//   /**
//    * @custom:subsection                        ** ONLY GOVERNANCE **
//    *
//    */

//   function propose(
//     address _CONTROLLER,
//     uint256 _TYPE,
//     bytes calldata _NAME,
//     uint256 duration
//   ) public virtual override returns (uint256 id) {
//     id = GEODE.propose(DATASTORE, _CONTROLLER, _TYPE, _NAME, duration);
//   }

//   function rescueSenate(address _newSenate) external virtual override {
//     GEODE.rescueSenate(_newSenate);
//   }

//   /**
//    * @custom:subsection                        ** ONLY SENATE **
//    */

//   /**
//    * @dev handles PACKAGE_TYPE proposals by upgrading the contract immediately.
//    */
//   function approveProposal(
//     uint256 id
//   ) public virtual override returns (address _controller, uint256 _type, bytes memory _name) {
//     (_controller, _type, _name) = GEODE.approveProposal(DATASTORE, id);

//     if (_type == GEODE.PACKAGE_TYPE) {
//       _handleUpgrade(_controller, id);
//     }
//   }

//   function changeSenate(address _newSenate) external virtual override {
//     GEODE.changeSenate(_newSenate);
//   }

//   /**
//    * @custom:subsection                        ** ONLY CONTROLLER **
//    */

//   function changeIdCONTROLLER(uint256 id, address newCONTROLLER) external virtual override {
//     GML.changeIdCONTROLLER(DATASTORE, id, newCONTROLLER);
//   }
// }
