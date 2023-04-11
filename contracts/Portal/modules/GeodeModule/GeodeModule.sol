// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {ID_TYPE} from "../../globals/id_type.sol";
// interfaces
import {IGeodeModule} from "./interfaces/IGeodeModule.sol";
// libraries
import {DataStoreModuleLib as DSML} from "../DataStoreModule/libs/DataStoreModuleLib.sol";
import {GeodeModuleLib as GML} from "./libs/GeodeModuleLib.sol";
// contracts
import {DataStoreModule} from "../DataStoreModule/DataStoreModule.sol";
// external
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Geode Module - GM
 *
 * @author Ice Bear & Crash Bandicoot
 */
contract GeodeModule is IGeodeModule, DataStoreModule, UUPSUpgradeable {
  using GML for GML.DualGovernance;

  /**
   * @custom:section                           ** VARIABLES **
   *
   * @dev note do not add any other vairables, Modules do not have a gap.
   * Instead library main struct has a gap, providing up to 16 storage slot.
   * todo add this to internal docs
   */
  GML.DualGovernance internal GEODE;

  /**
   * @custom:section                           ** EVENTS **
   */
  event ContractVersionSet(uint256 version);
  /**
   * @dev following events are added from GML to help fellow devs with a better ABI
   */
  event GovernanceFeeUpdated(uint256 newFee);
  event ControllerChanged(uint256 indexed ID, address CONTROLLER);
  event Proposed(uint256 indexed TYPE, uint256 ID, address CONTROLLER, uint256 deadline);
  event Approved(uint256 ID);
  event NewSenate(address senate, uint256 expiry);

  /**
   * @custom:section                           ** INITIALIZING **
   */

  function __GeodeModule_init(
    address governance,
    address senate,
    uint256 governanceFee,
    uint256 senateExpiry
  ) internal onlyInitializing {
    __UUPSUpgradeable_init_unchained();
    __DataStoreModule_init_unchained();
    __GeodeModule_init_unchained(governance, senate, governanceFee, senateExpiry);
  }

  function __GeodeModule_init_unchained(
    address governance,
    address senate,
    uint256 governanceFee,
    uint256 senateExpiry
  ) internal onlyInitializing {
    GEODE.GOVERNANCE = governance;
    GEODE.SENATE = senate;
    GEODE.GOVERNANCE_FEE = governanceFee;
    GEODE.SENATE_EXPIRY = senateExpiry;
  }

  /**
   * @custom:section                           ** VERSION CONTROL FUNCTIONS **
   */

  /**
   * @dev -> internal
   */
  /**
   * @dev required by the OZ UUPS module
   * note that there is no Governance check, as upgrades are effective
   * * right after the Senate approval
   */
  function _authorizeUpgrade(address proposed_implementation) internal virtual override {
    require(isUpgradeAllowed(proposed_implementation), "GM: not allowed to upgrade");
  }

  function _setContractVersion(uint256 newVersion) internal virtual {
    GEODE.CONTRACT_VERSION = newVersion;
    emit ContractVersionSet(newVersion);
  }

  /**
   * @dev -> external view
   */

  function getContractVersion() public view virtual override returns (uint256) {
    return GEODE.CONTRACT_VERSION;
  }

  /**
   * @notice get the latest version of the withdrawal contract module from Portal
   */
  function getProposedVersion() public view virtual override returns (uint256) {
    revert("GM:This function needs to be overriden");
  }

  function isUpgradeAllowed(
    address proposedImplementation
  ) public view virtual override returns (bool) {
    return GEODE.isUpgradeAllowed(proposedImplementation, _getImplementation());
  }

  function isolationMode() external view virtual override returns (bool) {
    revert("GM:This function needs to be overriden");
  }

  /**
   * @dev -> external
   */

  function pullUpgrade() external virtual override {
    revert("GM:This function needs to be overriden");
  }

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   */

  /**
   * @dev -> external view
   */

  function GeodeParams()
    external
    view
    virtual
    override
    returns (
      address governance,
      address senate,
      address approvedUpgrade,
      uint256 governanceFee,
      uint256 senateExpiry,
      uint256 contractVersion
    )
  {
    governance = GEODE.GOVERNANCE;
    senate = GEODE.SENATE;
    approvedUpgrade = GEODE.APPROVED_UPGRADE;
    governanceFee = GEODE.GOVERNANCE_FEE;
    senateExpiry = GEODE.SENATE_EXPIRY;
    contractVersion = GEODE.CONTRACT_VERSION;
  }

  function getProposal(
    uint256 id
  ) external view virtual override returns (GML.Proposal memory proposal) {
    proposal = GEODE.getProposal(id);
  }

  /**
   * @custom:section                           ** SETTER FUNCTIONS **
   */
  /**
   * @dev -> external: all
   */

  /**
   * @dev Governance Functions
   */

  function newProposal(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external virtual override returns (uint256 id, bool success) {
    id = GEODE.newProposal(DATASTORE, _CONTROLLER, _TYPE, _NAME, duration);
    success = true;
  }

  /**
   * @notice only parameter of GeodeUtils that can be mutated is the fee
   */
  function setGovernanceFee(uint256 newFee) external virtual override {
    GEODE.setGovernanceFee(newFee);
  }

  /**
   * @dev Senate Functions
   */

  /**
   * @notice approves a specific proposal
   * @dev OnlySenate is checked inside the GeodeUtils
   */
  function approveProposal(
    uint256 id
  ) public virtual override returns (uint256 _type, address _controller) {
    (_type, _controller) = GEODE.approveProposal(DATASTORE, id);
  }

  /**
   * @notice changes the Senate's address without extending the expiry
   * @dev OnlySenate is checked inside the GeodeUtils
   */
  function changeSenate(address _newSenate) external virtual override {
    GEODE.changeSenate(_newSenate);
  }

  function rescueSenate(address _newSenate) external virtual override {
    GEODE.rescueSenate(_newSenate);
  }

  /**
   * @dev CONTROLLER Functions
   */
  function changeIdCONTROLLER(uint256 id, address newCONTROLLER) external virtual override {
    GML.changeIdCONTROLLER(DATASTORE, id, newCONTROLLER);
  }
}
