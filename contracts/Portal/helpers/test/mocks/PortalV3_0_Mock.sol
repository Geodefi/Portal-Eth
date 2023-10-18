// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

// globals
import {ID_TYPE} from "../../../globals/id_type.sol";
// interfaces
import {IPortalV3_0_Mock} from "./interfaces/IPortalV3_0_Mock.sol";
import {IGeodeModuleV3_0_Mock} from "./interfaces/IGeodeModuleV3_0_Mock.sol";
import {IStakeModule} from "../../../interfaces/modules/IStakeModule.sol";
// libraries
import {DataStoreModuleLib as DSML, IsolatedStorage} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";
import {GeodeModuleLib as GML, DualGovernance} from "../../../modules/GeodeModule/libs/GeodeModuleLib.sol";
// import {GeodeModuleLibV3_0_Mock as GML, DualGovernance} from "./GeodeModuleLibV3_0_Mock.sol";
import {StakeModuleLib as SML, PooledStaking} from "../../../modules/StakeModule/libs/StakeModuleLib.sol";
// contracts
import {GeodeModuleV3_0_Mock} from "./GeodeModuleV3_0_Mock.sol";
import {StakeModule} from "../../../modules/StakeModule/StakeModule.sol";

contract PortalV3_0_Mock is IPortalV3_0_Mock, GeodeModuleV3_0_Mock, StakeModule {
  using DSML for IsolatedStorage;
  using GML for DualGovernance;
  using SML for PooledStaking;

  /**
   * @custom:section                           ** EVENTS **
   */
  event Released(uint256 operatorId);
  event GovernanceFeeSet(uint256 fee);

  /**
   * @custom:section                           ** MODIFIERS **
   */
  modifier onlyGovernance() {
    require(msg.sender == GEODE.GOVERNANCE, "PORTAL:sender NOT governance");
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

  /**
   * if you are going to need a reinitializer: bump the version. otherwise keep increasing the x in v2_x.
   */
  function initializeV3_0_Mock(uint256 value) external virtual override reinitializer(2) {
    __GeodeModule_initV3_0_Mock(value);
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
    override(GeodeModuleV3_0_Mock, IGeodeModuleV3_0_Mock)
    returns (bool)
  {
    return (paused() ||
      GEODE.APPROVED_UPGRADE != _getImplementation() ||
      block.timestamp > GEODE.SENATE_EXPIRY);
  }

  /**
   * @custom:section                           ** GOVERNANCE FUNCTIONS **
   *
   * @custom:visibility -> external
   */

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
   * @notice releases an imprisoned operator immediately
   * @dev in different situations such as a faulty imprisonment or coordinated testing periods
   * * Governance can release the prisoners
   * @dev onlyGovernance SHOULD be checked in Portal
   */
  function releasePrisoned(uint256 operatorId) external virtual override onlyGovernance {
    DATASTORE.writeUint(operatorId, "release", block.timestamp);

    emit Released(operatorId);
  }

  function setGovernanceFee(uint256 newFee) external virtual override onlyGovernance {
    require(newFee <= SML.MAX_GOVERNANCE_FEE, "PORTAL:> MAX_GOVERNANCE_FEE");
    require(block.timestamp > SML.GOVERNANCE_FEE_COMMENCEMENT, "PORTAL:not yet.");

    STAKE.GOVERNANCE_FEE = newFee;

    emit GovernanceFeeSet(newFee);
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
    override(GeodeModuleV3_0_Mock, IGeodeModuleV3_0_Mock)
    returns (address _controller, uint256 _type, bytes memory _name)
  {
    (_controller, _type, _name) = super.approveProposal(id);

    if (_type > ID_TYPE.LIMIT_MIN_PACKAGE && _type < ID_TYPE.LIMIT_MAX_PACKAGE) {
      STAKE.packages[_type] = id;
    } else if (_type > ID_TYPE.LIMIT_MIN_MIDDLEWARE && _type < ID_TYPE.LIMIT_MAX_MIDDLEWARE) {
      STAKE.middlewares[_type][id] = true;
    }
  }

  function pushUpgrade(
    uint256 packageType
  ) external virtual override nonReentrant whenNotPaused returns (uint256 id) {
    require(
      packageType > ID_TYPE.LIMIT_MIN_PACKAGE && packageType < ID_TYPE.LIMIT_MAX_PACKAGE,
      "PORTAL:invalid package type"
    );

    uint256 currentPackageVersion = STAKE.packages[packageType];

    id = IGeodeModuleV3_0_Mock(msg.sender).propose(
      DATASTORE.readAddress(currentPackageVersion, "CONTROLLER"),
      packageType,
      DATASTORE.readBytes(currentPackageVersion, "NAME"),
      GML.MAX_PROPOSAL_DURATION
    );

    require(id > 0, "PORTAL:cannot push upgrade");
  }

  /**
   * @notice fallback functions
   */

  receive() external payable {}

  /**
   * @notice keep the total number of variables at 50
   */
  uint256[49] private __gap;
}
