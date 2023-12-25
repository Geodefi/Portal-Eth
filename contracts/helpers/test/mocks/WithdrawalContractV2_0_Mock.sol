// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
// // structs
// import {WithdrawalModuleStorage} from "../../../modules/WithdrawalModule/structs/storage.sol";
// // globals
// import {ID_TYPE} from "../../../globals/id_type.sol";
// import {RESERVED_KEY_SPACE as rks} from "../../../globals/reserved_key_space.sol";
// // interfaces
// import {IPortal} from "../../../interfaces/IPortal.sol";
// import {IGeodeModule} from "../../../interfaces/modules/IGeodeModule.sol";
// import {IWithdrawalContractV2_0_Mock} from "./interfaces/IWithdrawalContractV2_0_Mock.sol";
// import {IWithdrawalModule} from "../../../interfaces/modules/IWithdrawalModule.sol";
// // libraries
// import {WithdrawalModuleLib as WML} from "../../../modules/WithdrawalModule/libs/WithdrawalModuleLib.sol";
// // contracts
// import {GeodeModule} from "../../../modules/GeodeModule/GeodeModule.sol";
// import {WithdrawalModule} from "../../../modules/WithdrawalModule/WithdrawalModule.sol";

// contract WithdrawalContractV2_0_Mock is
//   IWithdrawalContractV2_0_Mock,
//   GeodeModule,
//   WithdrawalModule
// {
//   using WML for WithdrawalModuleStorage;
//   /**
//    * @custom:section                           ** VARIABLES **
//    * Following immutable parameters are set when the referance library implementation is deployed.
//    * Making necessary data for initialization reachable for all instances of LP package.
//    */
//   /// @notice gETH position
//   address internal immutable gETHPos;
//   /// @notice Portal position
//   address internal immutable portalPos;

//   uint256 freshSlot;

//   /**
//    * @custom:section                           ** MODIFIERS **
//    */

//   modifier onlyOwner() {
//     require(msg.sender == GEODE.SENATE, "WCP:sender not owner");
//     _;
//   }

//   /**
//    * @custom:section                           ** INITIALIZING **
//    */
//   /**
//    * @custom:oz-upgrades-unsafe-allow constructor
//    *
//    * @dev we don't want to provide these package-specific not-changing parameters
//    * accross all instances of the packages.
//    * So we will store them in the ref implementation contract of the package,
//    * and fetch when needed on initialization.
//    */
//   constructor(address _gETHPos, address _portalPos) {
//     require(_gETHPos != address(0), "WCP:_gETHPos cannot be zero");
//     require(_portalPos != address(0), "WCP:_portalPos cannot be zero");

//     gETHPos = _gETHPos;
//     portalPos = _portalPos;

//     _disableInitializers();
//   }

//   /**
//    * @dev While 'data' parameter is not currently used it is a standarized approach on all
//    * * GeodePackages have the same function signature on 'initialize'.
//    */
//   function initialize(
//     uint256 poolId,
//     address poolOwner,
//     bytes calldata versionName,
//     bytes calldata data
//   ) public virtual override initializer {
//     __WithdrawalContract_init(poolId, poolOwner, versionName);
//   }

//   function initializeV2_0_Mock(uint256 _freshSlot) public virtual override reinitializer(2) {
//     setFreshSlot(_freshSlot);
//   }

//   function __WithdrawalContract_init(
//     uint256 poolId,
//     address poolOwner,
//     bytes calldata versionName
//   ) internal onlyInitializing {
//     __GeodeModule_init(
//       portalPos,
//       poolOwner,
//       type(uint256).max,
//       ID_TYPE.PACKAGE_WITHDRAWAL_CONTRACT,
//       versionName
//     );
//     __WithdrawalModule_init(gETHPos, portalPos, poolId);
//     __WithdrawalContract_init_unchained();
//   }

//   function __WithdrawalContract_init_unchained() internal onlyInitializing {}

//   function setFreshSlot(uint256 value) public virtual override {
//     freshSlot = value;
//   }

//   function getFreshSlot() external view virtual override returns (uint256) {
//     return freshSlot;
//   }

//   function getPoolId() public view override returns (uint256) {
//     return WITHDRAWAL.POOL_ID;
//   }

//   /**
//    * @notice get Portal as a contract
//    */
//   function getPortal() public view override returns (IPortal) {
//     return IPortal(GEODE.GOVERNANCE);
//   }

//   /**
//    * @dev GeodeModule override
//    */
//   function getProposedVersion() public view virtual override returns (uint256) {
//     return getPortal().getPackageVersion(GEODE.PACKAGE_TYPE);
//   }

//   /**
//    * @dev GeodeModule override
//    */
//   function isolationMode()
//     external
//     view
//     virtual
//     override(GeodeModule, IGeodeModule)
//     returns (bool)
//   {
//     if (paused()) {
//       return true;
//     }

//     if (getContractVersion() != getProposedVersion()) {
//       return true;
//     }

//     if (GEODE.APPROVED_UPGRADE != ERC1967Utils.getImplementation()) {
//       return true;
//     }

//     if (getPortal().readAddress(getPoolId(), rks.CONTROLLER) != GEODE.SENATE) {
//       return true;
//     }

//     return false;
//   }

//   /**
//    * @custom:section                           ** ADMIN FUNCTIONS **
//    *
//    * @custom:visibility -> external
//    */

//   /**
//    * @custom:subsection                           ** UPGRADABILITY FUNCTIONS **
//    */

//   /**
//    * @dev IGeodePackage override
//    */
//   function pullUpgrade() external virtual override onlyOwner {
//     require(!(getPortal().isolationMode()), "WCP:Portal is isolated");
//     require(getProposedVersion() != getContractVersion(), "WCP:no upgrades");

//     uint256 id = getPortal().pushUpgrade(GEODE.PACKAGE_TYPE);
//     approveProposal(id);
//   }

//   /**
//    * @custom:subsection                           ** PAUSABILITY FUNCTIONS **
//    */

//   /**
//    * @notice pausing the contract activates the isolationMode
//    */
//   function pause() external virtual override(WithdrawalModule, IWithdrawalModule) onlyOwner {
//     _pause();
//   }

//   /**
//    * @notice unpausing the contract deactivates the isolationMode
//    */
//   function unpause() external virtual override(WithdrawalModule, IWithdrawalModule) onlyOwner {
//     _unpause();
//   }

//   /**
//    * @custom:subsection                           ** WITHDRAWAL QUEUE **
//    *
//    * @dev WM override
//    */
//   function setExitThreshold(
//     uint256 newThreshold
//   ) external virtual override(WithdrawalModule, IWithdrawalModule) onlyOwner {
//     WITHDRAWAL.setExitThreshold(newThreshold);
//   }

//   /**
//    * @notice keep the total number of variables at 50
//    */
//   uint256[49] private __gap;
// }
