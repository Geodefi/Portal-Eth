// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {PERCENTAGE_DENOMINATOR} from "../globals/macros.sol";
import {ID_TYPE} from "../globals/id_type.sol";
// interfaces
import {IgETH} from "../interfaces/IgETH.sol";
import {IPortal} from "../interfaces/IPortal.sol";
import {IGeodePackage} from "../interfaces/packages/IGeodePackage.sol";
import {ILiquidityPool} from "../interfaces/packages/ILiquidityPool.sol";
import {ILPToken} from "../interfaces/helpers/ILPToken.sol";
import {IGeodeModule} from "../interfaces/modules/IGeodeModule.sol";
import {ILiquidityModule} from "../interfaces/modules/ILiquidityModule.sol";
// libraries
import {DataStoreModuleLib as DSML} from "../modules/DataStoreModule/libs/DataStoreModuleLib.sol";
import {GeodeModuleLib as GML} from "../modules/GeodeModule/libs/GeodeModuleLib.sol";
import {AmplificationLib as AL} from "../modules/LiquidityModule/libs/AmplificationLib.sol";
// contracts
import {GeodeModule} from "../modules/GeodeModule/GeodeModule.sol";
import {LiquidityModule} from "../modules/LiquidityModule/LiquidityModule.sol";

/**
 * @title Liquidity Pool Package - LPP
 *
 * @notice LPP is a package that provides a liquidity pool for a staking pool created through Portal.
 *
 * @dev Refer to LiquidityModule for StableSwap implementation. Also note:
 * * initial and future A coefficients are set as 60 (LM)
 * * trade fee set to 4 bips (LM)
 * * owner fee is set to 0 (LM)
 * * governance fee is set to 0 (GM)
 * * senate expiry is not effective (GM)
 *
 * @dev  As a Package, it utilizes geodeModule: The Limited Upgradability through Dual Governance:
 * * Governance is the Portal, package version controller.
 * * Senate is the Staking Pool Owner.
 *
 * @dev As a Package, it utilizes IGeodePackage interface, meaning initialize function takes 3 parameters:
 * * * poolOwner: will be assigned as the senate of the package
 * * * pooledTokenId: used internally on LM and LML.
 * * * data: referances 1 parameter: name. Used to generate lpTokenName and lpTokenSymbol for __LM_init.
 *
 * @author Ice Bear & Crash Bandicoot
 *
 */
contract LiquidityPool is ILiquidityPool, LiquidityModule, GeodeModule {
  using GML for GML.DualGovernance;

  /**
   * @custom:section                           ** VARIABLES **
   * Following immutable parameters are set when the referance library implementation is deployed.
   * Making necessary data for initialization reachable for all instances of LP package.
   */
  /// @notice gETH position
  address internal immutable gETHPos;
  /// @notice Portal position
  address internal immutable portalPos;
  /// @notice LPToken implementation referance, needs to be cloned
  address internal immutable LPTokenRef;
  /// @notice LPP package type, useful for Limited Upgradability
  uint256 internal immutable PACKAGE_TYPE;

  /**
   * @custom:section                           ** MODIFIERS **
   */

  modifier onlyOwner() {
    require(msg.sender == GEODE.SENATE, "LPP:sender NOT owner");
    _;
  }

  /**
   * @custom:section                           ** INITIALIZING **
   */
  /**
   * @custom:oz-upgrades-unsafe-allow constructor
   *
   * @dev we don't want to provide these package-specific not-changing parameters
   * accross all instances of the packages.
   * So we will store them in the ref implementation contract of the package,
   * and fetch when needed on initialization.
   */
  constructor(address _gETHPos, address _portalPos, address _LPTokenRef) {
    require(_gETHPos != address(0), "LPP:_gETHPos can not be zero");
    require(_portalPos != address(0), "LPP:_portalPos can not be zero");
    require(_LPTokenRef != address(0), "LPP:_LPTokenRef can not be zero");

    gETHPos = _gETHPos;
    portalPos = _portalPos;
    LPTokenRef = _LPTokenRef;
    PACKAGE_TYPE = ID_TYPE.PACKAGE_LIQUIDITY_POOL;

    _disableInitializers();
  }

  /// @param data only poolName is required from Portal
  function initialize(
    uint256 versionId,
    uint256 pooledTokenId,
    address poolOwner,
    bytes memory data
  ) public virtual override initializer returns (bool success) {
    __LiquidityPool_init(versionId, pooledTokenId, poolOwner, data);
    success = true;
  }

  function __LiquidityPool_init(
    uint256 versionId,
    uint256 pooledTokenId,
    address poolOwner,
    bytes memory data
  ) internal onlyInitializing {
    __GeodeModule_init(portalPos, poolOwner, 0, type(uint256).max);
    string memory poolName = string(data);
    __LiquidityModule_init(
      gETHPos,
      LPTokenRef,
      pooledTokenId,
      60 * AL.A_PRECISION,
      60 * AL.A_PRECISION,
      (4 * PERCENTAGE_DENOMINATOR) / 10000,
      poolName
    );
    __LiquidityPool_init_unchained(versionId);
  }

  function __LiquidityPool_init_unchained(uint256 versionId) internal onlyInitializing {
    _setContractVersion(versionId);
  }

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   */
  /**
   * @dev -> public view: all
   */

  /**
   * @notice get the gETH ID of the corresponding staking pool
   */
  function getPoolId() public view override returns (uint256) {
    return LIQUIDITY.pooledTokenId;
  }

  /**
   * @notice get Portal as a contract
   */
  function getPortal() public view override returns (IPortal) {
    return IPortal(GEODE.GOVERNANCE);
  }

  /**
   * @dev GeodeModule override
   */
  function getProposedVersion()
    public
    view
    virtual
    override(GeodeModule, IGeodeModule)
    returns (uint256)
  {
    return getPortal().getPackageVersion(PACKAGE_TYPE);
  }

  /**
   * @custom:section                           ** ADMIN FUNCTIONS **
   */
  /**
   * @dev -> external: all
   */

  /**
   * @custom:section                           ** PAUSABILITY FUNCTIONS **
   */

  /**
   * @notice pausing the contract activates the isolationMode
   */
  function pause() external virtual override onlyOwner {
    _pause();
  }

  /**
   * @notice unpausing the contract deactivates the isolationMode
   */
  function unpause() external virtual override onlyOwner {
    _unpause();
  }

  /**
   * @custom:section                           ** UPGRADABILITY FUNCTIONS **
   */

  /**
   * @dev -> external
   */
  /**
   * @dev GeodeModule override
   */
  function pullUpgrade() external virtual override(GeodeModule, IGeodeModule) onlyOwner {
    require(!(getPortal().isolationMode()), "LPP:Portal is isolated");
    require(getProposedVersion() != getContractVersion(), "LPP:no upgrades");

    uint256 proposedVersion = getPortal().pushUpgrade(PACKAGE_TYPE);
    require(proposedVersion != 0, "LPP:PROPOSED_VERSION ERROR");

    approveProposal(proposedVersion);
    _authorizeUpgrade(GEODE.APPROVED_UPGRADE);
    _upgradeToAndCallUUPS(GEODE.APPROVED_UPGRADE, new bytes(0), false);
    _setContractVersion(proposedVersion);
  }

  /**
   * @dev GeodeModule override
   */
  function isolationMode()
    external
    view
    virtual
    override(GeodeModule, IGeodeModule)
    returns (bool)
  {
    if (paused()) return true;
    if (getContractVersion() != getProposedVersion()) return true;
    if (GEODE.APPROVED_UPGRADE != _getImplementation()) return true;
    if (getPortal().readAddress(getPoolId(), "CONTROLLER") != GEODE.SENATE) return true;
    return false;
  }

  /**
   * @custom:section                           ** LIQUIDITY POOL ADMIN **
   */

  function withdrawAdminFees(
    address receiver
  ) public virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
    super.withdrawAdminFees(receiver);
  }

  function setAdminFee(
    uint256 newAdminFee
  ) public virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
    super.setAdminFee(newAdminFee);
  }

  function setSwapFee(
    uint256 newSwapFee
  ) public virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
    super.setSwapFee(newSwapFee);
  }

  function rampA(
    uint256 futureA,
    uint256 futureTime
  ) public virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
    super.rampA(futureA, futureTime);
  }

  function stopRampA() public virtual override(LiquidityModule, ILiquidityModule) onlyOwner {
    super.stopRampA();
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
  uint256[46] private __gap;
}
