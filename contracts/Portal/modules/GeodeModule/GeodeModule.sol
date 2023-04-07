// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// external
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
//global
import {ID_TYPE} from "../../utils/globals.sol";
// libraries
import {DataStoreModuleLib as DSML} from "../DataStoreModule/libs/DataStoreModuleLib.sol";
import {GeodeModuleLib as GML} from "./libs/GeodeModuleLib.sol";
// contracts
import {DataStoreModule} from "../DataStoreModule/DataStoreModule.sol";
// interfaces
import {IGeodeModule} from "./interfaces/IGeodeModule.sol";

/**
 * @title Geode Module - GM
 *
 * @author Icebear & Crash Bandicoot
 *
 */
contract GeodeModule is IGeodeModule, DataStoreModule, UUPSUpgradeable {
  using GML for GML.DualGovernance;

  /**
   * @dev                                     ** VARIABLES **
   */
  GML.DualGovernance internal GEODE;
  /**
   * @notice CONTRACT_VERSION always refers to the upgrade proposal' (TYPE2) ID.
   * @dev Does NOT increase uniformly like one might expect.
   */
  uint256 internal CONTRACT_VERSION;

  /**
   * @dev                                     ** EVENTS **
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
   * @dev                                     ** UPGRADABALITY FUNCTIONS **
   */
  /**
   * @dev -> view
   */

  function getContractVersion() public view virtual override returns (uint256) {
    return CONTRACT_VERSION;
  }

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

  function _setContractVersion(bytes memory versionName) internal virtual {
    CONTRACT_VERSION = DSML.generateId(versionName, ID_TYPE.CONTRACT_UPGRADE);
    emit ContractVersionSet(getContractVersion());
  }

  /**
   * @dev                                     ** GETTER FUNCTIONS **
   */

  /**
   * @dev -> external view
   */

  function GeodeParams()
    external
    view
    virtual
    override
    returns (address senate, address governance, uint256 senate_expiry, uint256 governance_fee)
  {
    senate = GEODE.getSenate();
    governance = GEODE.getGovernance();
    senate_expiry = GEODE.getSenateExpiry();
    governance_fee = GEODE.getGovernanceFee();
  }

  function getProposal(
    uint256 id
  ) external view virtual override returns (GML.Proposal memory proposal) {
    proposal = GEODE.getProposal(id);
  }

  /**
   * @dev -> public view
   */
  function isUpgradeAllowed(
    address proposedImplementation
  ) public view virtual override returns (bool) {
    return GEODE.isUpgradeAllowed(proposedImplementation, _getImplementation());
  }

  function isolationMode() external view virtual override returns (bool isolated) {
    revert("GM:This function needs to be overriden!");
  }

  /**
   * @dev                                     ** SETTER FUNCTIONS **
   */
  /**
   * @dev -> external: all
   */

  /**
   * @dev Governance Functions
   */

  /**
   * @notice only parameter of GeodeUtils that can be mutated is the fee
   */
  function setGovernanceFee(uint256 newFee) external virtual {
    GEODE.setGovernanceFee(newFee);
  }

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

  function rescueSenate(address _newSenate) external virtual {
    GEODE.rescueSenate(_newSenate);
  }

  /**
   * @dev CONTROLLER Functions
   */

  function changeIdCONTROLLER(uint256 id, address newCONTROLLER) external virtual override {
    GML.changeIdCONTROLLER(DATASTORE, id, newCONTROLLER);
  }
}
