// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

// import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
// // structs
// import {DualGovernance} from "../../../modules/GeodeModule/structs/storage.sol";
// import {Swap} from "../../../modules/LiquidityModule/structs/storage.sol";
// // globals
// import {RESERVED_KEY_SPACE as rks} from "../../../globals/reserved_key_space.sol";
// import {PERCENTAGE_DENOMINATOR} from "../../../globals/macros.sol";
// import {ID_TYPE} from "../../../globals/id_type.sol";
// // interfaces
// import {IPortal} from "../../../interfaces/IPortal.sol";
// import {ILiquidityPackageV2_0_Mock} from "./interfaces/ILiquidityPackageV2_0_Mock.sol";
// import {IGeodeModule} from "../../../interfaces/modules/IGeodeModule.sol";
// import {ILiquidityModule} from "../../../interfaces/modules/ILiquidityModule.sol";
// // libraries
// import {GeodeModuleLib as GML} from "../../../modules/GeodeModule/libs/GeodeModuleLib.sol";
// import {AmplificationLib as AL} from "../../../modules/LiquidityModule/libs/AmplificationLib.sol";
// import {LiquidityModuleLib as LML} from "../../../modules/LiquidityModule/libs/LiquidityModuleLib.sol";
// // contracts
// import {GeodeModule} from "../../../modules/GeodeModule/GeodeModule.sol";
// import {LiquidityModule} from "../../../modules/LiquidityModule/LiquidityModule.sol";

// /**
//  * @title LP: Liquidity Package: Geode Module + Liquidity Module
//  *
//  * @notice LP is a package that provides a liquidity package for a staking pool created through Portal.
//  *
//  * @dev TYPE: PACKAGE_LIQUIDITY
//  * @dev Utilizing IGeodePackage interface, meaning initialize function takes 3 parameters:
//  * * * poolOwner: will be assigned as the senate of the package
//  * * * pooledTokenId: used internally on LM and LML.
//  * * * data: referances 1 parameter: name. Used to generate lpTokenName and lpTokenSymbol for __LM_init.
//  *
//  * @dev review: LM for StableSwap implementation. Also note:
//  * * initial and future A coefficients are set as 60 (LM)
//  * * trade fee set to 4 bips (LM)
//  * * owner fee is set to 0 (LM)
//  * * senate expiry is not effective (GM)
//  *
//  * @dev review: GM for The Limited Upgradability through Dual Governance:
//  * * Governance is the Portal, package version controller.
//  * * Senate is the Staking Pool Owner.
//  *
//  * @author Ice Bear & Crash Bandicoot
//  */
// contract LiquidityPackageV2_0_Mock is ILiquidityPackageV2_0_Mock, GeodeModule, LiquidityModule {
//   using GML for DualGovernance;
//   using AL for Swap;
//   using LML for Swap;

//   /**
//    * @custom:section                           ** VARIABLES **
//    *
//    * @dev Following immutable parameters are set when the referance library implementation is deployed.
//    * It is not desired to provide these package-specific not-changing parameters
//    * accross all instances of the packages.
//    * So, we will store them in the ref implementation contract of the package,
//    * and fetch when needed on initialization of an instance.
//    */
//   /// @notice gETH position
//   address internal immutable gETHPos;
//   /// @notice Portal position
//   address internal immutable portalPos;
//   /// @notice LPToken implementation referance, needs to be cloned
//   address internal immutable LPTokenRef;
//   /// @notice Liquidity package type, useful for Limited Upgradability

//   uint256 freshSlot;
//   /**
//    * @custom:section                           ** MODIFIERS **
//    */

//   modifier onlyOwner() {
//     require(msg.sender == GEODE.SENATE, "LP:sender not owner");
//     _;
//   }

//   /**
//    * @custom:section                           ** INITIALIZING **
//    */

//   /**
//    * @custom:oz-upgrades-unsafe-allow constructor
//    */
//   constructor(address _gETHPos, address _portalPos, address _LPTokenRef) {
//     require(_gETHPos != address(0), "LP:_gETHPos cannot be zero");
//     require(_portalPos != address(0), "LP:_portalPos cannot be zero");
//     require(_LPTokenRef != address(0), "LP:_LPTokenRef cannot be zero");

//     gETHPos = _gETHPos;
//     portalPos = _portalPos;
//     LPTokenRef = _LPTokenRef;

//     _disableInitializers();
//   }

//   /**
//    * @param data only poolName is required from Portal
//    */
//   function initialize(
//     uint256 pooledTokenId,
//     address poolOwner,
//     bytes calldata versionName,
//     bytes calldata data
//   ) public virtual override initializer {
//     __LiquidityPackage_init(pooledTokenId, poolOwner, versionName, data);
//   }

//   function initializeV2_0_Mock(uint256 _freshSlot) public virtual override reinitializer(2) {
//     setFreshSlot(_freshSlot);
//   }

//   function __LiquidityPackage_init(
//     uint256 pooledTokenId,
//     address poolOwner,
//     bytes calldata versionName,
//     bytes calldata data
//   ) internal onlyInitializing {
//     __GeodeModule_init(
//       portalPos,
//       poolOwner,
//       type(uint256).max,
//       ID_TYPE.PACKAGE_LIQUIDITY,
//       versionName
//     );
//     __LiquidityModule_init(
//       gETHPos,
//       LPTokenRef,
//       pooledTokenId,
//       60,
//       (4 * PERCENTAGE_DENOMINATOR) / 10000,
//       string(data)
//     );
//     __LiquidityPackage_init_unchained();
//   }

//   function __LiquidityPackage_init_unchained() internal onlyInitializing {}

//   function setFreshSlot(uint256 value) public virtual override {
//     freshSlot = value;
//   }

//   function getFreshSlot() external view virtual override returns (uint256) {
//     return freshSlot;
//   }

//   /**
//    * @custom:section                           ** GETTER FUNCTIONS **
//    *
//    * @custom:visibility -> view-public
//    */

//   /**
//    * @notice get the gETH ID of the corresponding staking pool
//    */
//   function getPoolId() public view override returns (uint256) {
//     return LIQUIDITY.pooledTokenId;
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
//    *
//    * @custom:visibility -> view
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
//     require(!(getPortal().isolationMode()), "LP:Portal is isolated");
//     require(getProposedVersion() != getContractVersion(), "LP:no upgrades");

//     uint256 id = getPortal().pushUpgrade(GEODE.PACKAGE_TYPE);
//     approveProposal(id);
//   }

//   /**
//    * @custom:subsection                           ** PAUSABILITY FUNCTIONS **
//    */

//   /**
//    * @notice pausing the contract activates the isolationMode
//    */
//   function pause() external virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
//     _pause();
//   }

//   /**
//    * @notice unpausing the contract deactivates the isolationMode
//    */
//   function unpause() external virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
//     _unpause();
//   }

//   /**
//    * @custom:subsection                           ** LIQUIDITY PACKAGE **
//    *
//    * @dev LM override
//    */

//   function setSwapFee(
//     uint256 newSwapFee
//   ) public virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
//     LIQUIDITY.setSwapFee(newSwapFee);
//   }

//   function setAdminFee(
//     uint256 newAdminFee
//   ) public virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
//     LIQUIDITY.setAdminFee(newAdminFee);
//   }

//   function withdrawAdminFees(
//     address receiver
//   ) public virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
//     LIQUIDITY.withdrawAdminFees(receiver);
//   }

//   function rampA(
//     uint256 futureA,
//     uint256 futureTime
//   ) public virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
//     LIQUIDITY.rampA(futureA, futureTime);
//   }

//   function stopRampA() external virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
//     LIQUIDITY.stopRampA();
//   }

//   /**
//    * @notice fallback functions
//    */

//   receive() external payable {}

//   /**
//    * @notice keep the total number of variables at 50
//    */
//   uint256[49] private __gap;
// }
