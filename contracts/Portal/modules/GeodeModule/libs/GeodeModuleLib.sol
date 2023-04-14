// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {PERCENTAGE_DENOMINATOR} from "../../../globals/macros.sol";
import {ID_TYPE} from "../../../globals/id_type.sol";
import {RESERVED_KEY_SPACE as rks} from "../../../globals/reserved_key_space.sol";
// libraries
import {DataStoreModuleLib as DSML} from "../../DataStoreModule/libs/DataStoreModuleLib.sol";

/**
 * @title GeodeModule Library - GML
 * @notice Dual Governance and Limited Upgradability
 * Exclusively contains functions for the administration of the Isolated Storage,
 * and Limited Upgradability with Dual Governance of Governance and Senate
 *
 * @dev This library contains both functions called by users(ID) like changeIdController, and admins(GOVERNANCE, SENATE)
 *
 * @dev Reserved ID TYPEs:
 * Type 0 : NULL
 * Type 1 : SENATE
 * * Senate is a third party, expected to be an immutable contract that allows identified
 * * TYPE's CONTROLLERs to vote on proposals on Portal.
 * * Senate is the pool owner on Withdrawal Contracts.
 * * Senate can represent other entities within the Dual Governance if this library is
 * * used by other Geode Modules in the future.
 * * Senate can be changed by the Dual Governance with TYPE 1 proposals on Portal OR
 * * 'instantly' by the pool Owner on Withdrawal Contracts.
 * * @dev SENATE can have an expiration date, a new one should be set before it ends.
 * * * otherwise governance can set a new senate without any proposals.
 * Type 2 : CONTRACT UPGRADES
 * * Provides Limited Upgradability on Portal and Withdrawal Contract
 * * Contract can be upgradable once Senate approves it.
 * Type 3 : __GAP__
 * * Initially represented the admin contract, but we use UUPS. Reserved to be never used.
 *
 * @dev Contracts relying on this library must initialize GeodeModuleLib.DualGovernance
 * @dev Functions are already protected accordingly
 *
 * @dev review DataStoreModule
 *
 * @author Ice Bear & Crash Bandicoot
 */
library GeodeModuleLib {
  /// @notice Using DataStoreModuleLib for IsolatedStorage struct
  using DSML for DSML.IsolatedStorage;

  /**
   * @custom:section                           ** STRUCTS **
   */

  /**
   * @notice Proposals give the control of a specific ID to a CONTROLLER
   * * An ID Proposal has 4 specs:
   * @param TYPE: refer to globals.sol
   * @param CONTROLLER: the address that refers to the change that is proposed by given proposal.
   * * This slot can refer to the controller of an id, a new implementation contract, a new Senate etc.
   * @param NAME: DataStore generates ID by keccak(name, type)
   * @param deadline: refers to last timestamp until a proposal expires, limited by MAX_PROPOSAL_DURATION
   * * Expired proposals can not be approved by Senate
   * * Expired proposals can not be overriden by new proposals
   **/
  struct Proposal {
    address CONTROLLER;
    uint256 TYPE;
    bytes NAME;
    uint256 deadline;
  }

  /**
   * @notice DualGovernance allows 2 parties to manage a contract with proposals and approvals.
   * @param GOVERNANCE a community that works to improve the core product and ensures its adoption in the DeFi ecosystem
   * Suggests updates, such as new operators, contract upgrades, a new Senate -without any permission to force them-
   * @param SENATE An address that protects the users by controlling the state of governance, contract updates and other crucial changes
   * Note SENATE can be changed by a proposal TYPE 1 by Governance and approved by the current Senate.
   * @param APPROVED_UPGRADE only 1 implementation contract SHOULD be "approved" at any given time.
   * @param GOVERNANCE_FEE operation fee on the given contract, acquired by GOVERNANCE. Limited by MAX_GOVERNANCE_FEE
   * @param CONTRACT_VERSION should always refer to the upgrade proposal ID. Does NOT increase uniformly like one might expect.
   * @param SENATE_EXPIRY refers to the last timestamp that SENATE can continue operating. Might not be utilized. Limited by MAX_SENATE_PERIOD
   * @param proposals till approved, proposals are kept separated from the Isolated Storage
   * @param __gap keep the struct size at 16, currently 6 slots(32 bytes)
   **/
  struct DualGovernance {
    address GOVERNANCE;
    address SENATE;
    address APPROVED_UPGRADE;
    uint256 GOVERNANCE_FEE;
    uint256 SENATE_EXPIRY;
    uint256 CONTRACT_VERSION;
    mapping(uint256 => Proposal) proposals;
    uint256[10] __gap;
  }

  /**
   * @custom:section                           ** CONSTANTS **
   */

  /**
   * @notice limiting the GOVERNANCE_FEE, 5%
   */
  uint256 public constant MAX_GOVERNANCE_FEE = (PERCENTAGE_DENOMINATOR * 5) / 100;

  /**
   * @notice prevents Governance from collecting any fees till given timestamp: MAY 2024
   * @dev fee switch will be automatically switched on after given timestamp
   * @dev fee switch can be switched on with the approval of Senate (a contract upgrade)
   */
  uint256 public constant FEE_COOLDOWN = 1714514461;

  /// @notice a proposal can have a duration between 1 days to 4 weeks (inclusive)
  uint32 public constant MIN_PROPOSAL_DURATION = 1 days;
  uint32 public constant MAX_PROPOSAL_DURATION = 4 weeks;

  /// @notice if expiry is utilized, a senate can be active for a year.
  /// max means a new senate can be set without expecting an expiry
  uint32 public constant MAX_SENATE_PERIOD = 365 days;

  /**
   * @custom:section                           ** EVENTS **
   */
  event GovernanceFeeUpdated(uint256 newFee);
  event ControllerChanged(uint256 indexed ID, address CONTROLLER);
  event Proposed(uint256 indexed TYPE, uint256 ID, address CONTROLLER, uint256 deadline);
  event Approved(uint256 ID);
  event NewSenate(address senate, uint256 expiry);

  /**
   * @custom:section                           ** MODIFIERS **
   */
  modifier onlyGovernance(DualGovernance storage self) {
    require(msg.sender == self.GOVERNANCE, "GML:GOVERNANCE role needed");
    _;
  }

  modifier onlySenate(DualGovernance storage self) {
    require(msg.sender == self.SENATE, "GML:SENATE role needed");
    require(block.timestamp < self.SENATE_EXPIRY, "GML:SENATE expired");
    _;
  }

  modifier onlyController(DSML.IsolatedStorage storage DATASTORE, uint256 id) {
    require(msg.sender == DATASTORE.readAddress(id, rks.CONTROLLER), "GML:CONTROLLER role needed");
    _;
  }

  /**
   * @custom:section                           ** DUAL GOVERNANCE **
   */

  /**
   * @dev -> external view
   */

  /**
   * @dev refer to Proposal struct
   */
  function getProposal(
    DualGovernance storage self,
    uint256 id
  ) external view returns (Proposal memory) {
    return self.proposals[id];
  }

  /**
   * @dev -> external
   */

  /**
   * @notice onlyGovernance, creates a new Proposal
   * @dev DATASTORE[id] will not be updated until the proposal is approved
   * @dev Proposals can NEVER be overriden
   * @dev refer to Proposal struct
   */
  function propose(
    DualGovernance storage self,
    DSML.IsolatedStorage storage DATASTORE,
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external onlyGovernance(self) returns (uint256 id) {
    id = DSML.generateId(_NAME, _TYPE);

    require(self.proposals[id].deadline == 0, "GML:NAME already proposed");
    require((DATASTORE.readBytes(id, rks.NAME)).length == 0, "GML:ID already exist");
    require(_CONTROLLER != address(0), "GML:CONTROLLER can NOT be ZERO");
    require(
      (_TYPE != ID_TYPE.NONE) && (_TYPE != ID_TYPE.__GAP__) && (_TYPE != ID_TYPE.POOL),
      "GML:TYPE is NONE, GAP or POOL"
    );
    require(
      (duration >= MIN_PROPOSAL_DURATION) && (duration <= MAX_PROPOSAL_DURATION),
      "GML:invalid proposal duration"
    );

    uint256 _deadline = block.timestamp + duration;

    self.proposals[id] = Proposal({
      CONTROLLER: _CONTROLLER,
      TYPE: _TYPE,
      NAME: _NAME,
      deadline: _deadline
    });

    emit Proposed(_TYPE, id, _CONTROLLER, _deadline);
  }

  /**
   * @notice onlySenate, approves a proposal and records given data to DataStore
   * @notice specific changes for the reserved types (1,2,3) are implemented here,
   * any other addition should take place in Portal, as not related.
   * @param id given ID proposal that has been approved by Senate
   * @dev Senate is not able to approve approved proposals
   * @dev Senate is not able to approve expired proposals
   */
  function approveProposal(
    DualGovernance storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 id
  ) external onlySenate(self) returns (uint256 _type, address _controller) {
    require(self.proposals[id].deadline > block.timestamp, "GML:NOT an active proposal");

    _type = self.proposals[id].TYPE;
    _controller = self.proposals[id].CONTROLLER;

    DATASTORE.writeUint(id, rks.TYPE, _type);
    DATASTORE.writeAddress(id, rks.CONTROLLER, _controller);
    DATASTORE.writeBytes(id, rks.NAME, self.proposals[id].NAME);
    DATASTORE.allIdsByType[_type].push(id);

    if (_type == ID_TYPE.SENATE) {
      _setSenate(self, _controller, block.timestamp + MAX_SENATE_PERIOD);
    } else if (_type == ID_TYPE.CONTRACT_UPGRADE) {
      self.APPROVED_UPGRADE = _controller;
    }

    // important
    self.proposals[id].deadline = block.timestamp;

    emit Approved(id);
  }

  /**
   * @custom:section                           ** GOVERNANCE FEE **
   **/
  /**
   * @dev -> external: all
   */

  /**
   * @notice onlyGovernance, sets the governance fee
   * @dev Can not set the fee more than MAX_GOVERNANCE_FEE
   */
  function setGovernanceFee(
    DualGovernance storage self,
    uint256 newFee
  ) external onlyGovernance(self) {
    require(newFee <= MAX_GOVERNANCE_FEE, "GML:> MAX_GOVERNANCE_FEE");
    require(block.timestamp < FEE_COOLDOWN, "GML:can not set a fee yet");

    self.GOVERNANCE_FEE = newFee;

    emit GovernanceFeeUpdated(newFee);
  }

  /**
   * @custom:section                           ** SENATE **
   */

  /**
   * @dev -> internal
   */

  /**
   * @notice internal function to set a new senate with a given period
   */
  function _setSenate(DualGovernance storage self, address _newSenate, uint256 _expiry) internal {
    self.SENATE = _newSenate;
    self.SENATE_EXPIRY = _expiry;

    emit NewSenate(self.SENATE, self.SENATE_EXPIRY);
  }

  /**
   * @dev -> external
   */

  /**
   * @notice onlySenate, sometimes it is useful to be able to change the Senate's address
   * * without changing the expiry,for example in the withdrawal contracts.
   * @dev does not change the expiry
   */
  function changeSenate(DualGovernance storage self, address _newSenate) external onlySenate(self) {
    _setSenate(self, _newSenate, self.SENATE_EXPIRY);
  }

  /**
   * @notice onlyGovernance, changes Senate in a scenerio where the current Senate acts maliciously.
   * * We are sure this will not be the case, but creating a method for possible recovery is a must.
   * @notice Normally, Governance creates Senate Proposals frequently to signal it does not have
   * * any intent of malicious overtake.
   * note: If Governance does not send a Senate Proposal a while before the SENATE_EXPIRY,
   * * we recommend users to take their money out.
   * @dev Obviously, Governance needs to wait for SENATE_EXPIRY.
   */
  function rescueSenate(
    DualGovernance storage self,
    address _newSenate
  ) external onlyGovernance(self) {
    require(block.timestamp > self.SENATE_EXPIRY, "GML:cannot rescue yet");

    _setSenate(self, _newSenate, block.timestamp + MAX_SENATE_PERIOD);
  }

  /**
   * @custom:section                           ** CONTROLLER **
   */

  /**
   * @dev -> external
   */

  /**
   * @notice onlyController, change the CONTROLLER of an ID
   * @dev this operation can not be reverted by the old CONTROLLER !
   * @dev can not provide address(0), try 0x000000000000000000000000000000000000dEaD
   */
  function changeIdCONTROLLER(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 id,
    address newCONTROLLER
  ) external onlyController(DATASTORE, id) {
    require(newCONTROLLER != address(0), "GML:CONTROLLER can not be zero");

    DATASTORE.writeAddress(id, rks.CONTROLLER, newCONTROLLER);

    emit ControllerChanged(id, newCONTROLLER);
  }

  /**
   * @dev                                       ** LIMITED UPGRADABILITY **
   */
  /**
   * @dev -> external view
   */
  /**
   * @notice Get if it is allowed to change a specific contract with the current version.
   * @return True if it is allowed by senate and false if not.
   * @dev address(0) should return false
   * @dev currentImplementation should always be UUPS._getImplementation()
   **/
  function isUpgradeAllowed(
    DualGovernance storage self,
    address proposedImplementation,
    address currentImplementation
  ) external view returns (bool) {
    return
      (self.APPROVED_UPGRADE != address(0)) &&
      (proposedImplementation != currentImplementation) &&
      (self.APPROVED_UPGRADE == proposedImplementation);
  }
}
