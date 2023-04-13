//   ██████╗ ███████╗ ██████╗ ██████╗ ███████╗    ██████╗  ██████╗ ██████╗ ████████╗ █████╗ ██╗
//  ██╔════╝ ██╔════╝██╔═══██╗██╔══██╗██╔════╝    ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██║
//  ██║  ███╗█████╗  ██║   ██║██║  ██║█████╗      ██████╔╝██║   ██║██████╔╝   ██║   ███████║██║
//  ██║   ██║██╔══╝  ██║   ██║██║  ██║██╔══╝      ██╔═══╝ ██║   ██║██╔══██╗   ██║   ██╔══██║██║
//  ╚██████╔╝███████╗╚██████╔╝██████╔╝███████╗    ██║     ╚██████╔╝██║  ██║   ██║   ██║  ██║███████╗
//   ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
//

// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {ID_TYPE} from "./globals/id_type.sol";

// interfaces
import {IGeodeModule} from "./interfaces/modules/IGeodeModule.sol";
import {IPortal} from "./interfaces/IPortal.sol";
import {IStakeModule} from "./interfaces/modules/IStakeModule.sol";
// libraries
import {DataStoreModuleLib as DSML} from "./modules/DataStoreModule/libs/DataStoreModuleLib.sol";
import {GeodeModuleLib as GML} from "./modules/GeodeModule/libs/GeodeModuleLib.sol";
import {StakeModuleLib as SML} from "./modules/StakeModule/libs/StakeModuleLib.sol";
// contracts
import {GeodeModule} from "./modules/GeodeModule/GeodeModule.sol";
import {StakeModule} from "./modules/StakeModule/StakeModule.sol";

// external

contract Portal is IPortal, StakeModule, GeodeModule {
  using DSML for DSML.IsolatedStorage;
  using GML for GML.DualGovernance;

  /**
   * @custom:section                           ** EVENTS **
   */
  event Released(uint256 operatorId);

  /**
   * @custom:section                           ** MODIFIERS **
   */
  modifier onlyGovernance() {
    require(msg.sender == GEODE.SENATE, "Portal:sender NOT governance");
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
    __ERC1155Holder_init_unchained();
    __ReentrancyGuard_init_unchained();
    __Pausable_init_unchained();
    __UUPSUpgradeable_init_unchained();
    __DataStoreModule_init_unchained();
    __GeodeModule_init_unchained(
      address(0),
      address(0),
      0,
      block.timestamp + GML.MAX_SENATE_PERIOD
    );
    __StakeModule_init_unchained(_gETH, _oracle_position);
    __Portal_init_unchained(_governance, _senate, versionName);
  }

  function __Portal_init_unchained(
    address _governance,
    address _senate,
    bytes calldata versionName
  ) internal onlyInitializing {
    GEODE.GOVERNANCE = msg.sender;
    GEODE.SENATE = msg.sender;

    uint256 portalVersion = GEODE.newProposal(
      DATASTORE,
      address(this),
      ID_TYPE.CONTRACT_UPGRADE,
      versionName,
      1 days
    );
    approveProposal(portalVersion);

    GEODE.GOVERNANCE = _governance;
    GEODE.SENATE = _senate;

    _setContractVersion(portalVersion);
  }

  function pause() external virtual override(StakeModule, IStakeModule) onlyGovernance {
    _pause();
  }

  function unpause() external virtual override(StakeModule, IStakeModule) onlyGovernance {
    _unpause();
  }

  function pausegETH() external virtual override onlyGovernance {
    STAKE.gETH.pause();
  }

  function unpausegETH() external virtual override onlyGovernance {
    STAKE.gETH.unpause();
  }

  /**
   * @notice releases an imprisoned operator immidately
   * @dev in different situations such as a faulty imprisonment or coordinated testing periods
   * * Governance can release the prisoners
   * @dev onlyGovernance SHOULD be checked in Portal
   */
  function releasePrisoned(uint256 operatorId) external virtual override onlyGovernance {
    DATASTORE.writeUint(operatorId, "released", block.timestamp);

    emit Released(operatorId);
  }

  function pushUpgrade(
    uint256 moduleType
  ) external virtual override whenNotPaused nonReentrant returns (uint256 moduleVersion) {
    moduleVersion = STAKE.packages[moduleType];
    (, bool success) = IGeodeModule(msg.sender).newProposal(
      DATASTORE.readAddress(moduleVersion, "CONTROLLER"),
      ID_TYPE.CONTRACT_UPGRADE,
      DATASTORE.readBytes(moduleVersion, "NAME"),
      3 weeks
    );

    require(success, "PORTAL: cannot push upgrade");
  }

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
    returns (uint256 _type, address _controller)
  {
    (_type, _controller) = GEODE.approveProposal(DATASTORE, id);

    if (_type > ID_TYPE.LIMIT_MIN_PACKAGE && _type < ID_TYPE.LIMIT_MAX_PACKAGE) {
      STAKE.packages[_type] = id;
    } else if (_type > ID_TYPE.LIMIT_MIN_MIDDLEWARE && _type < ID_TYPE.LIMIT_MAX_MIDDLEWARE) {
      STAKE.middlewares[_type][id] = true;
    }
  }

  function getProposedVersion()
    public
    view
    virtual
    override(GeodeModule, IGeodeModule)
    returns (uint256)
  {
    revert("Portal:check Upgrade proposal instead");
  }

  function pullUpgrade() external virtual override(GeodeModule, IGeodeModule) {
    revert("Portal:can not pull from itself");
  }

  /**
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
    return (paused() ||
      GEODE.APPROVED_UPGRADE != _getImplementation() ||
      block.timestamp > GEODE.SENATE_EXPIRY);
  }

  /**
   * @notice fallback functions
   */
  function Do_we_care() external pure virtual override returns (bool) {
    return true;
  }

  fallback() external payable {}

  receive() external payable {}

  /**
   * @notice keep the contract size at 50
   */
  uint256[50] private __gap;
}
