// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
// internal - globals
import {ID_TYPE} from "../globals/id_type.sol";
import {RESERVED_KEY_SPACE as rks} from "../globals/reserved_key_space.sol";
// internal - interfaces
import {IGeodeModule} from "../interfaces/modules/IGeodeModule.sol";
import {IWithdrawalModule} from "../interfaces/modules/IWithdrawalModule.sol";
import {IWithdrawalPackage} from "../interfaces/packages/IWithdrawalPackage.sol";
import {IPortal} from "../interfaces/IPortal.sol";
// internal - structs
import {GeodeModuleStorage} from "../modules/GeodeModule/structs/storage.sol";
import {WithdrawalModuleStorage} from "../modules/WithdrawalModule/structs/storage.sol";
// internal - libraries
import {WithdrawalModuleLib as WML} from "../modules/WithdrawalModule/libs/WithdrawalModuleLib.sol";
// internal - contracts
import {GeodeModule} from "../modules/GeodeModule/GeodeModule.sol";
import {WithdrawalModule} from "../modules/WithdrawalModule/WithdrawalModule.sol";

contract WithdrawalPackage is IWithdrawalPackage, GeodeModule, WithdrawalModule {
  using WML for WithdrawalModuleStorage;
  /**
   * @custom:section                           ** VARIABLES **
   * Following immutable parameters are set when the referance library implementation is deployed.
   * Making necessary data for initialization reachable for all instances of LP package.
   */
  /// @notice gETH position
  address internal immutable gETHPos;
  /// @notice Portal position
  address internal immutable portalPos;

  /**
   * @custom:section                           ** MODIFIERS **
   */

  modifier onlyOwner() {
    require(msg.sender == _getGeodeModuleStorage().SENATE, "WCP:sender not owner");
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
  constructor(address _gETHPos, address _portalPos) {
    require(_gETHPos != address(0), "WCP:_gETHPos cannot be zero");
    require(_portalPos != address(0), "WCP:_portalPos cannot be zero");

    gETHPos = _gETHPos;
    portalPos = _portalPos;

    _disableInitializers();
  }

  /**
   * @dev While 'data' parameter is not currently used it is a standarized approach on all
   * * GeodePackages have the same function signature on 'initialize'.
   */
  function initialize(
    uint256 poolId,
    address poolOwner,
    bytes calldata versionName,
    bytes calldata data
  ) public virtual override initializer {
    __WithdrawalPackage_init(poolId, poolOwner, versionName);
  }

  function __WithdrawalPackage_init(
    uint256 poolId,
    address poolOwner,
    bytes calldata versionName
  ) internal onlyInitializing {
    __GeodeModule_init(
      portalPos,
      poolOwner,
      type(uint256).max,
      ID_TYPE.PACKAGE_WITHDRAWAL_CONTRACT,
      versionName
    );
    __WithdrawalModule_init(gETHPos, portalPos, poolId);
    __WithdrawalPackage_init_unchained();
  }

  function __WithdrawalPackage_init_unchained() internal onlyInitializing {}

  function getPoolId() public view override returns (uint256) {
    return _getWithdrawalModuleStorage().POOL_ID;
  }

  /**
   * @dev GeodeModule override
   */
  function getProposedVersion() public view virtual override returns (uint256) {
    GeodeModuleStorage storage GMStorage = _getGeodeModuleStorage();

    return IPortal(GMStorage.GOVERNANCE).getPackageVersion(GMStorage.PACKAGE_TYPE);
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
    if (paused()) {
      return true;
    }

    GeodeModuleStorage storage GMStorage = _getGeodeModuleStorage();

    if (
      GMStorage.CONTRACT_VERSION !=
      IPortal(GMStorage.GOVERNANCE).getPackageVersion(GMStorage.PACKAGE_TYPE)
    ) {
      return true;
    }

    if (GMStorage.APPROVED_UPGRADE != ERC1967Utils.getImplementation()) {
      return true;
    }

    if (
      IPortal(GMStorage.GOVERNANCE).readAddress(getPoolId(), rks.CONTROLLER) != GMStorage.SENATE
    ) {
      return true;
    }

    return false;
  }

  /**
   * @custom:section                           ** ADMIN FUNCTIONS **
   *
   * @custom:visibility -> external
   */

  /**
   * @custom:subsection                           ** UPGRADABILITY FUNCTIONS **
   */

  /**
   * @dev IGeodePackage override
   */
  function pullUpgrade() external virtual override onlyOwner {
    GeodeModuleStorage storage GMStorage = _getGeodeModuleStorage();
    IPortal Portal = IPortal(GMStorage.GOVERNANCE);

    require(!Portal.isolationMode(), "WCP:Portal is isolated");
    require(
      GMStorage.CONTRACT_VERSION != Portal.getPackageVersion(GMStorage.PACKAGE_TYPE),
      "WCP:no upgrades"
    );

    uint256 id = Portal.pushUpgrade(GMStorage.PACKAGE_TYPE);
    approveProposal(id);
  }

  /**
   * @custom:subsection                           ** PAUSABILITY FUNCTIONS **
   */

  /**
   * @notice pausing the contract activates the isolationMode
   */
  function pause() external virtual override(WithdrawalModule, IWithdrawalModule) onlyOwner {
    _pause();
  }

  /**
   * @notice unpausing the contract deactivates the isolationMode
   */
  function unpause() external virtual override(WithdrawalModule, IWithdrawalModule) onlyOwner {
    _unpause();
  }

  /**
   * @custom:subsection                           ** WITHDRAWAL QUEUE **
   *
   * @dev WM override
   */
  function setExitThreshold(
    uint256 newThreshold
  ) external virtual override(WithdrawalModule, IWithdrawalModule) onlyOwner {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    $.setExitThreshold(newThreshold);
  }

  /**
   * @custom:subsection                           ** INFRASTRUCTURE FEE **
   *
   * @dev WM override
   */
  function claimInfrastructureFees(
    address receiver
  ) external virtual override(WithdrawalModule, IWithdrawalModule) returns (bool success) {
    require(msg.sender == IPortal(_getGeodeModuleStorage().GOVERNANCE).getGovernance());

    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    uint256 claimable = $.gatheredInfrastructureFees;

    (success, ) = payable(receiver).call{value: claimable}("");
    require(success, "WCP:Failed to send ETH");
  }

  /**
   * @notice fallback functions: receive
   */

  receive() external payable {}
}
