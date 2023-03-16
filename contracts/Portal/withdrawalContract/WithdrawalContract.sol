// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {ID_TYPE} from "../utils/globals.sol";
import {DataStoreUtils} from "../utils/DataStoreUtilsLib.sol";
import {GeodeUtils} from "../utils/GeodeUtilsLib.sol";

import {IgETH} from "../../interfaces/IgETH.sol";
import {IPortal} from "../../interfaces/IPortal.sol";
import {IGeodeModule} from "../../interfaces/IGeodeModule.sol";
import {IWithdrawalContract} from "../../interfaces/IWithdrawalContract.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title WithdrawalContract: Saviour of Trustless Staking Derivatives
 * @notice This is a simple contract:
 * - used as the withdrawal credential of the validators.
 * - accrues fees and rewards from validators over time.
 * - handles the withdrawal queue for stakers.
 * - manages its own versioning without trusting Portal.
 * @dev This contract utilizes Dual Governance between Portal (GOVERNANCE) and 
 the Pool Owner (SENATE) to empower the Limited Upgradability.
 *
 * @dev Recovery Mode stops pool operations while allowing withdrawal queue to operate as usual
 *
 * @dev todo: Withdrawal Queue
 */

contract WithdrawalContract is
  IWithdrawalContract,
  IGeodeModule,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  UUPSUpgradeable
{
  using DataStoreUtils for DataStoreUtils.IsolatedStorage;
  using GeodeUtils for GeodeUtils.DualGovernance;

  ///@notice Events
  event ControllerChanged(uint256 id, address newCONTROLLER);
  event Proposed(
    uint256 id,
    address CONTROLLER,
    uint256 TYPE,
    uint256 deadline
  );
  event ProposalApproved(uint256 id);
  event NewSenate(address senate, uint256 senateExpiry);

  event ContractVersionSet(uint256 version);

  ///@notice Variables
  DataStoreUtils.IsolatedStorage private DATASTORE;
  GeodeUtils.DualGovernance private GEM;
  address internal gETH;
  uint256 internal POOL_ID;
  uint256 internal CONTRACT_VERSION;

  ///@custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    uint256 _VERSION,
    uint256 _ID,
    address _gETH,
    address _PORTAL,
    address _OWNER
  ) public virtual override initializer returns (bool) {
    __ReentrancyGuard_init();
    __Pausable_init();
    __UUPSUpgradeable_init();

    gETH = _gETH;
    POOL_ID = _ID;

    GEM.GOVERNANCE = _PORTAL;
    GEM.SENATE = _OWNER;
    GEM.SENATE_EXPIRY = type(uint256).max;

    CONTRACT_VERSION = _VERSION;
    emit ContractVersionSet(_VERSION);

    return true;
  }

  modifier onlyPortal() {
    require(
      msg.sender == GEM.getGovernance(),
      "WithdrawalContract: sender NOT PORTAL"
    );
    _;
  }

  modifier onlyController() {
    require(
      msg.sender == GEM.getSenate(),
      "WithdrawalContract: sender NOT CONTROLLER"
    );
    _;
  }

  ///@dev required by the UUPS module
  function _authorizeUpgrade(
    address proposed_implementation
  ) internal virtual override onlyController {
    require(
      GEM.isUpgradeAllowed(proposed_implementation),
      "WithdrawalContract: NOT allowed to upgrade"
    );
  }

  /**
   * @notice pausing the contract activates the recoveryMode
   */
  function pause() external virtual override onlyController {
    _pause();
  }

  /**
   * @notice unpausing the contract deactivates the recoveryMode
   */
  function unpause() external virtual override onlyController {
    _unpause();
  }

  /**
   * @notice get gETH as a contract
   */
  function getgETH() public view override returns (IgETH) {
    return IgETH(gETH);
  }

  /**
   * @notice get Portal as a contract
   */
  function getPortal() public view override returns (IPortal) {
    return IPortal(GEM.getGovernance());
  }

  /**
   * @notice get the gETH ID of the corresponding staking pool
   */
  function getPoolId() public view override returns (uint256) {
    return POOL_ID;
  }

  /**
   * @notice get the current version of the contract
   */
  function getContractVersion() public view virtual override returns (uint256) {
    return CONTRACT_VERSION;
  }

  /**
   * @notice get the latest version of the withdrawal contract module from Portal
   */
  function getProposedVersion() public view virtual override returns (uint256) {
    return getPortal().getDefaultModule(ID_TYPE.MODULE_WITHDRAWAL_CONTRACT);
  }

  /**
   * @notice Recovery Mode allows Withdrawal Contract to isolate itself
   * from Portal and continue handling the withdrawals.
   * @return isRecovering true if recoveryMode is active
   */
  function recoveryMode()
    public
    view
    virtual
    override
    returns (bool isRecovering)
  {
    isRecovering =
      getContractVersion() != getProposedVersion() ||
      paused() ||
      getPortal().readAddressForId(getPoolId(), "CONTROLLER") !=
      GEM.getSenate() ||
      block.timestamp >= GEM.getSenateExpiry();
  }

  /**
   * @notice Creates a new Proposal within Withdrawal Contract, used by Portal
   * @dev only Governance check is inside, note Governance is Portal.
   */
  function newProposal(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external virtual override(IGeodeModule, IWithdrawalContract) {
    GEM.newProposal(DATASTORE, _CONTROLLER, _TYPE, _NAME, duration);
  }

  function approveProposal(
    uint256 id
  )
    public
    virtual
    override
    whenNotPaused
    returns (uint256 _type, address _controller)
  {
    (_type, _controller) = GEM.approveProposal(DATASTORE, id);
  }

  /**
   * @notice Fetching an upgradeProposal from Portal creates an upgrade proposal
   * @notice approving the version changes the approvedVersion on GeodeUtils
   * @dev remaining code is basically taken from upgradeTo of UUPS since
   * it is still not public, but external
   */
  function fetchUpgradeProposal() external virtual override onlyController {
    uint256 proposedVersion = getPortal().fetchModuleUpgradeProposal(
      ID_TYPE.MODULE_WITHDRAWAL_CONTRACT
    );

    require(
      proposedVersion != getContractVersion() && proposedVersion != 0,
      "WithdrawalContract: PROPOSED_VERSION ERROR"
    );

    approveProposal(proposedVersion);
    _authorizeUpgrade(GEM.approvedVersion);
    _upgradeToAndCallUUPS(GEM.approvedVersion, new bytes(0), false);
  }

  /**
   * @notice changes the Senate's address without extending the expiry
   * @dev OnlySenate is checked inside the GeodeUtils
   */
  function changeController(address _newSenate) external virtual override {
    GEM.changeSenate(_newSenate);
  }

  fallback() external payable {}

  receive() external payable {}

  /**
   * @notice keep the contract size at 50
   */
  uint256[45] private __gap;
}
