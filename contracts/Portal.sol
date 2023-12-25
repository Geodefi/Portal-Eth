// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

//   ██████╗ ███████╗ ██████╗ ██████╗ ███████╗    ██████╗  ██████╗ ██████╗ ████████╗ █████╗ ██╗
//  ██╔════╝ ██╔════╝██╔═══██╗██╔══██╗██╔════╝    ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██║
//  ██║  ███╗█████╗  ██║   ██║██║  ██║█████╗      ██████╔╝██║   ██║██████╔╝   ██║   ███████║██║
//  ██║   ██║██╔══╝  ██║   ██║██║  ██║██╔══╝      ██╔═══╝ ██║   ██║██╔══██╗   ██║   ██╔══██║██║
//  ╚██████╔╝███████╗╚██████╔╝██████╔╝███████╗    ██║     ╚██████╔╝██║  ██║   ██║   ██║  ██║███████╗
//   ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
//

// external - library
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
// internal - globals
import {ID_TYPE} from "./globals/id_type.sol";
// internal - interfaces
import {IGeodeModule} from "./interfaces/modules/IGeodeModule.sol";
import {IStakeModule} from "./interfaces/modules/IStakeModule.sol";
import {IPortal} from "./interfaces/IPortal.sol";
// internal - structs
import {DataStoreModuleStorage} from "./modules/DataStoreModule/structs/storage.sol";
import {GeodeModuleStorage} from "./modules/GeodeModule/structs/storage.sol";
import {StakeModuleStorage} from "./modules/StakeModule/structs/storage.sol";
// internal - libraries
import {DataStoreModuleLib as DSML} from "./modules/DataStoreModule/libs/DataStoreModuleLib.sol";
import {GeodeModuleLib as GML} from "./modules/GeodeModule/libs/GeodeModuleLib.sol";
import {StakeModuleLib as SML} from "./modules/StakeModule/libs/StakeModuleLib.sol";
// internal - contracts
import {GeodeModule} from "./modules/GeodeModule/GeodeModule.sol";
import {StakeModule} from "./modules/StakeModule/StakeModule.sol";

/**
 * @title Geode Portal: Geode Module + Stake Module
 *
 * @notice Global standard for staking with on chain delegation and customizable staking pools.
 * Management of the state of the protocol governance through dual governance and proposals.
 * Version management and distribution of packages used by the staking pools.
 *
 * @dev TYPE: PACKAGE_PORTAL
 * @dev Portal is a special package that is deployed once. Does not utilize IGeodePackage interface.
 *
 * @dev review: GM for The Limited Upgradability through Dual Governance:
 * * Governance is a governance token.
 * * Senate is a multisig, planned to be a contract that allows pool CONTROLLERs to maintain power.
 * * Senate expiry is effective.
 *
 * @dev review: SM for Staking logic.
 *
 * @dev There are 2 functionalities that are implemented here:
 * * Special Governance functions for Portal:
 * * * Pausing gETH, pausing Portal, releasing prisoned operators,and seting a governance fee.
 * * Push end of the version management logic via pull->push.
 * * * approveProposal changes the package version or allows specified middleware.
 * * * pushUpgrade creates a package type proposal on the package to upgrade the contract, and requires package owner to approve it.
 *
 * @dev authentication:
 * * GeodeModule has OnlyGovernance, OnlySenate and OnlyController checks with modifiers.
 * * StakeModuleLib has "authenticate()" function which checks for Maintainers, Controllers, and TYPE.
 * * OracleModuleLib has OnlyOracle checks with a modifier.
 * * Portal has an OnlyGovernance check on : pause, unpause, pausegETH, unpausegETH, setInfrastructureFee, releasePrisoned.
 *
 * @author Ice Bear & Crash Bandicoot
 */
contract Portal is IPortal, GeodeModule, StakeModule {
  using DSML for DataStoreModuleStorage;
  using GML for GeodeModuleStorage;
  using SML for StakeModuleStorage;

  /**
   * @custom:section                           ** EVENTS **
   */
  event Released(uint256 operatorId);
  event InfrastructureFeeSet(uint256 _type, uint256 fee);

  /**
   * @custom:section                           ** MODIFIERS **
   */
  modifier onlyGovernance() {
    require(msg.sender == _getGeodeModuleStorage().GOVERNANCE, "PORTAL:sender not governance");
    _;
  }

  /**
   * @custom:section                           ** INITIALIZING **
   */

  ///@custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _governance,
    address _senate,
    address _gETH,
    address _oracle_position,
    bytes calldata versionName
  ) public virtual initializer {
    __Portal_init(_governance, _senate, _gETH, _oracle_position, versionName);
  }

  function __Portal_init(
    address _governance,
    address _senate,
    address _gETH,
    address _oracle_position,
    bytes calldata versionName
  ) internal onlyInitializing {
    __GeodeModule_init(
      _governance,
      _senate,
      block.timestamp + GML.MAX_SENATE_PERIOD,
      ID_TYPE.PACKAGE_PORTAL,
      versionName
    );
    __StakeModule_init(_gETH, _oracle_position);
    __Portal_init_unchained();
  }

  function __Portal_init_unchained() internal onlyInitializing {}

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   *
   * @custom:visibility -> view-external
   */

  /**
   * @dev GeodeModule override
   *
   * @notice Isolation Mode is an external view function signaling other contracts
   * * to isolate themselves from Portal. For example, withdrawalContract will not fetch upgrades.
   * @return isRecovering true if isolationMode is active:
   * * 1. Portal is paused
   * * 2. Portal needs to be upgraded
   * * 3. Senate expired
   */
  function isolationMode()
    external
    view
    virtual
    override(GeodeModule, IGeodeModule)
    returns (bool)
  {
    GeodeModuleStorage storage GMStorage = _getGeodeModuleStorage();
    return (paused() ||
      GMStorage.APPROVED_UPGRADE != ERC1967Utils.getImplementation() ||
      block.timestamp > GMStorage.SENATE_EXPIRY);
  }

  /**
   * @custom:section                           ** GOVERNANCE FUNCTIONS **
   *
   * @custom:visibility -> external
   */

  function pausegETH() external virtual override onlyGovernance {
    _getStakeModuleStorage().gETH.pause();
  }

  function unpausegETH() external virtual override onlyGovernance {
    _getStakeModuleStorage().gETH.unpause();
  }

  function pause() external virtual override(StakeModule, IStakeModule) onlyGovernance {
    _pause();
  }

  function unpause() external virtual override(StakeModule, IStakeModule) onlyGovernance {
    _unpause();
  }

  function setInfrastructureFee(
    uint256 _type,
    uint256 fee
  ) external virtual override(StakeModule, IStakeModule) onlyGovernance {
    if (_type == ID_TYPE.POOL) {
      require(fee <= SML.MAX_POOL_INFRASTRUCTURE_FEE, "PORTAL:> MAX");
    }

    _getStakeModuleStorage().setInfrastructureFee(_type, fee);

    emit InfrastructureFeeSet(_type, fee);
  }

  /**
   * @notice releases an imprisoned operator immediately
   * @dev in different situations such as a faulty imprisonment or coordinated testing periods
   * * Governance can release the prisoners
   * @dev onlyGovernance SHOULD be checked in Portal
   */
  function releasePrisoned(uint256 operatorId) external virtual override onlyGovernance {
    _getDataStoreModuleStorage().writeUint(operatorId, "release", block.timestamp);

    emit Released(operatorId);
  }

  /**
   * @custom:section                           ** PACKAGE VERSION MANAGEMENT **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice approves a specific proposal
   * @dev OnlySenate is checked inside the GeodeModule
   */
  function approveProposal(
    uint256 id
  )
    public
    virtual
    override(GeodeModule, IGeodeModule)
    returns (address _controller, uint256 _type, bytes memory _name)
  {
    (_controller, _type, _name) = super.approveProposal(id);

    if (_type > ID_TYPE.LIMIT_MIN_PACKAGE && _type < ID_TYPE.LIMIT_MAX_PACKAGE) {
      _getStakeModuleStorage().packages[_type] = id;
    } else if (_type > ID_TYPE.LIMIT_MIN_MIDDLEWARE && _type < ID_TYPE.LIMIT_MAX_MIDDLEWARE) {
      _getStakeModuleStorage().middlewares[_type][id] = true;
    }
  }

  function pushUpgrade(
    uint256 packageType
  ) external virtual override nonReentrant whenNotPaused returns (uint256 id) {
    require(
      packageType > ID_TYPE.LIMIT_MIN_PACKAGE && packageType < ID_TYPE.LIMIT_MAX_PACKAGE,
      "PORTAL:invalid package type"
    );

    uint256 currentPackageVersion = _getStakeModuleStorage().packages[packageType];

    DataStoreModuleStorage storage DSMStorage = _getDataStoreModuleStorage();

    id = IGeodeModule(msg.sender).propose(
      DSMStorage.readAddress(currentPackageVersion, "CONTROLLER"),
      packageType,
      DSMStorage.readBytes(currentPackageVersion, "NAME"),
      GML.MAX_PROPOSAL_DURATION
    );

    require(id > 0, "PORTAL:cannot push upgrade");
  }

  /**
   * @notice fallback functions: receive
   */

  receive() external payable {}
}
