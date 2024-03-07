// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

// import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
// // structs
// import {DataStoreModuleStorage} from "../../../modules/DataStoreModule/structs/storage.sol";
// import {DualGovernance} from "../../../modules/GeodeModule/structs/storage.sol";
// import {StakeModuleStorage} from "../../../modules/StakeModule/structs/storage.sol";
// // globals
// import {ID_TYPE} from "../../../globals/id_type.sol";
// // interfaces
// import {IPortalV4_0_Mock} from "./interfaces/IPortalV4_0_Mock.sol";
// import {IGeodeModule} from "../../../interfaces/modules/IGeodeModule.sol";
// import {IStakeModule} from "../../../interfaces/modules/IStakeModule.sol";
// // libraries
// import {DataStoreModuleLib as DSML} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";
// import {GeodeModuleLib as GML} from "../../../modules/GeodeModule/libs/GeodeModuleLib.sol";
// import {StakeModuleLib as SML} from "../../../modules/StakeModule/libs/StakeModuleLib.sol";
// import {FreshSlotModuleLib as FSL, FreshSlotStruct} from "./FreshSlotModuleLib.sol";

// // contracts
// import {GeodeModule} from "../../../modules/GeodeModule/GeodeModule.sol";
// import {StakeModule} from "../../../modules/StakeModule/StakeModule.sol";
// import {FreshSlotModule} from "./FreshSlotModule.sol";

// contract PortalV4_0_Mock is IPortalV4_0_Mock, GeodeModule, StakeModule, FreshSlotModule {
//   using DSML for DataStoreModuleStorage;
//   using GML for DualGovernance;
//   using SML for StakeModuleStorage;
//   using FSL for FreshSlotStruct;

//   /**
//    * @custom:section                           ** EVENTS **
//    */
//   event Released(uint256 operatorId);
//   event GovernanceFeeSet(uint256 fee);

//   /**
//    * @custom:section                           ** MODIFIERS **
//    */
//   modifier onlyGovernance() {
//     require(msg.sender == GEODE.GOVERNANCE, "PORTAL:sender not governance");
//     _;
//   }

//   /**
//    * @custom:section                           ** INITIALIZING **
//    */

//   ///@custom:oz-upgrades-unsafe-allow constructor
//   constructor() {
//     _disableInitializers();
//   }

//   function initialize(
//     address _governance,
//     address _senate,
//     address _gETH,
//     address _oracle_position,
//     bytes calldata versionName
//   ) public virtual initializer {
//     __Portal_init(_governance, _senate, _gETH, _oracle_position, versionName);
//   }

//   /**
//    * if you are going to need a reinitializer: bump the version. otherwise keep increasing the x in v2_x.
//    */
//   function initializeV4_0_Mock(uint256 value) external virtual override reinitializer(2) {
//     __FreshSlotModule_init(value);
//   }

//   function __Portal_init(
//     address _governance,
//     address _senate,
//     address _gETH,
//     address _oracle_position,
//     bytes calldata versionName
//   ) internal onlyInitializing {
//     __GeodeModule_init(
//       _governance,
//       _senate,
//       block.timestamp + GML.MAX_SENATE_PERIOD,
//       ID_TYPE.PACKAGE_PORTAL,
//       versionName
//     );
//     __StakeModule_init(_gETH, _oracle_position);
//     __Portal_init_unchained();
//   }

//   function __Portal_init_unchained() internal onlyInitializing {}

//   /**
//    * @custom:section                           ** GETTER FUNCTIONS **
//    *
//    * @custom:visibility -> view-external
//    */

//   /**
//    * @dev GeodeModule override
//    *
//    * @notice Isolation Mode is an external view function signaling other contracts
//    * * to isolate themselves from Portal. For example, withdrawalContract will not fetch upgrades.
//    * @return isRecovering true if isolationMode is active:
//    * * 1. Portal is paused
//    * * 2. Portal needs to be upgraded
//    * * 3. Senate expired
//    */
//   function isolationMode()
//     external
//     view
//     virtual
//     override(GeodeModule, IGeodeModule)
//     returns (bool)
//   {
//     return (paused() ||
//       GEODE.APPROVED_UPGRADE != ERC1967Utils.getImplementation() ||
//       block.timestamp > GEODE.SENATE_EXPIRY);
//   }

//   /**
//    * @custom:section                           ** GOVERNANCE FUNCTIONS **
//    *
//    * @custom:visibility -> external
//    */

//   function pause() external virtual override(StakeModule, IStakeModule) onlyGovernance {
//     _pause();
//   }

//   function unpause() external virtual override(StakeModule, IStakeModule) onlyGovernance {
//     _unpause();
//   }

//   function pausegETH() external virtual override onlyGovernance {
//     STAKE.gETH.pause();
//   }

//   function unpausegETH() external virtual override onlyGovernance {
//     STAKE.gETH.unpause();
//   }

//   /**
//    * @notice releases an imprisoned operator immediately
//    * @dev in different situations such as a faulty imprisonment or coordinated testing periods
//    * * Governance can release the prisoners
//    * @dev onlyGovernance SHOULD be checked in Portal
//    */
//   function releasePrisoned(uint256 operatorId) external virtual override onlyGovernance {
//     DATASTORE.writeUint(operatorId, "release", block.timestamp);

//     emit Released(operatorId);
//   }

//   function setGovernanceFee(uint256 newFee) external virtual override onlyGovernance {
//     require(newFee <= SML.MAX_GOVERNANCE_FEE, "PORTAL:> MAX_GOVERNANCE_FEE");
//     require(block.timestamp > SML.GOVERNANCE_FEE_COMMENCEMENT, "PORTAL:not yet.");

//     STAKE.GOVERNANCE_FEE = newFee;

//     emit GovernanceFeeSet(newFee);
//   }

//   /**
//    * @custom:section                           ** PACKAGE VERSION MANAGEMENT **
//    *
//    * @custom:visibility -> external
//    */

//   /**
//    * @notice approves a specific proposal
//    * @dev OnlySenate is checked inside the GeodeModule
//    */
//   function approveProposal(
//     uint256 id
//   )
//     public
//     virtual
//     override(GeodeModule, IGeodeModule)
//     returns (address _controller, uint256 _type, bytes memory _name)
//   {
//     (_controller, _type, _name) = super.approveProposal(id);

//     if (_type > ID_TYPE.LIMIT_MIN_PACKAGE && _type < ID_TYPE.LIMIT_MAX_PACKAGE) {
//       STAKE.packages[_type] = id;
//     } else if (_type > ID_TYPE.LIMIT_MIN_MIDDLEWARE && _type < ID_TYPE.LIMIT_MAX_MIDDLEWARE) {
//       STAKE.middlewares[_type][id] = true;
//     }
//   }

//   function pushUpgrade(
//     uint256 packageType
//   ) external virtual override nonReentrant whenNotPaused returns (uint256 id) {
//     require(
//       packageType > ID_TYPE.LIMIT_MIN_PACKAGE && packageType < ID_TYPE.LIMIT_MAX_PACKAGE,
//       "PORTAL:invalid package type"
//     );

//     uint256 currentPackageVersion = STAKE.packages[packageType];

//     id = IGeodeModule(msg.sender).propose(
//       DATASTORE.readAddress(currentPackageVersion, "CONTROLLER"),
//       packageType,
//       DATASTORE.readBytes(currentPackageVersion, "NAME"),
//       GML.MAX_PROPOSAL_DURATION
//     );

//     require(id > 0, "PORTAL:cannot push upgrade");
//   }

//   /**
//    * @notice fallback functions
//    */

//   receive() external payable {}

//   /**
//    * @notice keep the total number of variables at 50
//    * @dev structs are storage sluts :)
//    */
//   uint256[40] private __gap;
//   // IMPORTANT NOTE: For upgrade to work need to rearrange the gap variable.
//   // It may be possible that we are using wrong gap initially
// }
