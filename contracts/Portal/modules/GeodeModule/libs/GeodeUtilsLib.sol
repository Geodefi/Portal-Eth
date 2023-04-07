// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {ID_TYPE, PERCENTAGE_DENOMINATOR} from "./globals.sol";
import {DataStoreUtils as DSU} from "./DataStoreUtilsLib.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title Geode Dual Governance and Limited Upgradability Logic
 * @notice Exclusively contains functions for the administration of the Isolated Storage,
 * and Limited Upgradability with Dual Governance of Governance and Senate
 * Note This library contains both functions called by users(ID) like changeIdController, and admins(GOVERNANCE, SENATE)
 *
 * @dev Reserved ID_TYPEs:
 *
 * * Type 0 : NULL
 *
 * * Type 1 : SENATE
 * * * Senate is a third party, expected to be an immutable contract that allows identified
 * * * TYPE's CONTROLLERs to vote on proposals on Portal.
 * * * Senate is the pool owner on Withdrawal Contracts.
 * * * Senate can represent other entities within the Dual Governance if this library is
 * * * used by other Geode Modules in the future.
 * * * Senate can be changed by the Dual Governance with TYPE 1 proposals on Portal OR
 * * * 'instantly' by the pool Owner on Withdrawal Contracts.
 * * * @dev SENATE can have an expiration date, a new one should be set before it ends.
 * * * * otherwise governance can set a new senate without any proposals.
 *
 * * Type 2 : CONTRACT UPGRADES
 * * * Provides Limited Upgradability on Portal and Withdrawal Contract
 * * * Contract can be upgradable once Senate approves it.
 *
 * * Type 3 : __GAP__
 * * * Normally represented the admin contract, but we use UUPS. Reserved to be never used.
 *
 * @dev Contracts relying on this library must initialize GeodeUtils.DualGovernance
 * @dev Functions are already protected accordingly
 *
 * @dev review DataStoreUtils
 */
library GeodeUtils {
  /// @notice Using DataStoreUtils for IsolatedStorage struct
  using DSU for DSU.IsolatedStorage;

  /// @notice EVENTS
  event GovernanceFeeUpdated(uint256 newFee);
  event ControllerChanged(uint256 indexed id, address newCONTROLLER);
  event Proposed(uint256 id, address CONTROLLER, uint256 indexed TYPE, uint256 deadline);
  event ProposalApproved(uint256 id);
  event NewSenate(address senate, uint256 senateExpiry);

  /**
   * @notice Proposals give the control of a specific ID to a CONTROLLER
   *
   * @notice A Proposal has 4 specs:
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
   * @param SENATE_EXPIRY refers to the last timestamp that SENATE can continue operating. Limited by MAX_SENATE_PERIOD
   * @param GOVERNANCE_FEE operation fee on the given contract, acquired by GOVERNANCE. Limited by MAX_GOVERNANCE_FEE
   * @param approvedUpgrade only 1 implementation contract SHOULD be "approved" at any given time.
   * * @dev safe to set to address(0) after every upgrade as isUpgradeAllowed returns false for address(0)
   * @param _proposals till approved, proposals are kept separated from the Isolated Storage
   * @param __gap keep the struct size at 16, 3*20+2*32+1*32 = 5 slots
   **/
  struct DualGovernance {
    address GOVERNANCE;
    address SENATE;
    address approvedUpgrade;
    uint256 SENATE_EXPIRY;
    uint256 GOVERNANCE_FEE;
    mapping(uint256 => Proposal) _proposals;
    uint256[11] __gap;
  }

  /**
   * @notice limiting the GOVERNANCE_FEE, 5%
   */
  uint256 public constant MAX_GOVERNANCE_FEE = (PERCENTAGE_DENOMINATOR * 5) / 100;

  /**
   * @notice prevents Governance from collecting any fees till given timestamp:
   * @notice April 2025
   * @dev fee switch will be automatically switched on after given timestamp
   * @dev fee switch can be switched on with the approval of Senate (a contract upgrade)
   */
  uint256 public constant FEE_COOLDOWN = 1743454800;

  uint32 public constant MIN_PROPOSAL_DURATION = 1 days;
  uint32 public constant MAX_PROPOSAL_DURATION = 4 weeks;
  uint32 public constant MAX_SENATE_PERIOD = 365 days;

  modifier onlyGovernance(DualGovernance storage self) {
    require(msg.sender == self.GOVERNANCE, "GU: GOVERNANCE role needed");
    _;
  }

  modifier onlySenate(DualGovernance storage self) {
    require(msg.sender == self.SENATE, "GU: SENATE role needed");
    require(block.timestamp < self.SENATE_EXPIRY, "GU: SENATE expired");
    _;
  }

  modifier onlyController(DSU.IsolatedStorage storage DATASTORE, uint256 id) {
    require(msg.sender == DATASTORE.readAddress(id, "CONTROLLER"), "GU: CONTROLLER role needed");
    _;
  }

  /**
   * @notice                                     ** DualGovernance **
   **/

  /**
   * @dev  ->  view
   */

  /**
   * @return address of SENATE
   **/
  function getSenate(DualGovernance storage self) external view returns (address) {
    return self.SENATE;
  }

  /**
   * @return address of GOVERNANCE
   **/
  function getGovernance(DualGovernance storage self) external view returns (address) {
    return self.GOVERNANCE;
  }

  /**
   * @return the expiration date of current SENATE as a timestamp
   */
  function getSenateExpiry(DualGovernance storage self) external view returns (uint256) {
    return self.SENATE_EXPIRY;
  }

  /**
   * @notice active GOVERNANCE_FEE limited by FEE_COOLDOWN and MAX_GOVERNANCE_FEE
   * @dev MAX_GOVERNANCE_FEE MUST limit GOVERNANCE_FEE even if MAX is changed later
   * @dev MUST return 0 until cooldown period is active
   */
  function getGovernanceFee(DualGovernance storage self) external view returns (uint256) {
    return
      block.timestamp < FEE_COOLDOWN ? 0 : MAX_GOVERNANCE_FEE > self.GOVERNANCE_FEE
        ? self.GOVERNANCE_FEE
        : MAX_GOVERNANCE_FEE;
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice onlyGovernance, sets the governance fee
   * @dev Can not set the fee more than MAX_GOVERNANCE_FEE
   */
  function setGovernanceFee(
    DualGovernance storage self,
    uint256 newFee
  ) external onlyGovernance(self) {
    require(newFee <= MAX_GOVERNANCE_FEE, "GU: > MAX_GOVERNANCE_FEE");

    self.GOVERNANCE_FEE = newFee;

    emit GovernanceFeeUpdated(newFee);
  }

  /**
   * @notice                                     ** ID **
   */

  /**
   * @dev  ->  external
   */

  /**
   * @notice onlyController, change the CONTROLLER of an ID
   * @dev this operation can not be reverted by the old CONTROLLER !
   * @dev can not provide address(0), try 0x000000000000000000000000000000000000dEaD
   */
  function changeIdCONTROLLER(
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id,
    address newCONTROLLER
  ) external onlyController(DATASTORE, id) {
    require(newCONTROLLER != address(0), "GU: CONTROLLER can not be zero");

    DATASTORE.writeAddress(id, "CONTROLLER", newCONTROLLER);

    emit ControllerChanged(id, newCONTROLLER);
  }

  /**
   * @notice                                     ** PROPOSALS **
   */

  /**
   * @dev  ->  view
   */

  /**
   * @dev refer to Proposal struct
   */
  function getProposal(
    DualGovernance storage self,
    uint256 id
  ) external view returns (Proposal memory) {
    return self._proposals[id];
  }

  /**
   * @dev  ->  external
   */

  /**
   * @notice onlyGovernance, creates a new Proposal
   * @dev DATASTORE[id] will not be updated until the proposal is approved
   * @dev Proposals can NEVER be overriden
   * @dev refer to Proposal struct
   */
  function newProposal(
    DualGovernance storage self,
    DSU.IsolatedStorage storage DATASTORE,
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external onlyGovernance(self) returns (uint256 id) {
    id = DSU.generateId(_NAME, _TYPE);

    require(self._proposals[id].deadline == 0, "GU: NAME already proposed");
    require((DATASTORE.readBytes(id, "NAME")).length == 0, "GU: ID already exist");
    require(_CONTROLLER != address(0), "GU: CONTROLLER can NOT be ZERO");
    require(
      (_TYPE != ID_TYPE.NONE) && (_TYPE != ID_TYPE.__GAP__) && (_TYPE != ID_TYPE.POOL),
      "GU: TYPE is NONE, GAP or POOL"
    );
    require(
      (duration >= MIN_PROPOSAL_DURATION) && (duration <= MAX_PROPOSAL_DURATION),
      "GU: invalid proposal duration"
    );

    uint256 _deadline = block.timestamp + duration;

    self._proposals[id] = Proposal({
      CONTROLLER: _CONTROLLER,
      TYPE: _TYPE,
      NAME: _NAME,
      deadline: _deadline
    });

    emit Proposed(id, _CONTROLLER, _TYPE, _deadline);
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
    DSU.IsolatedStorage storage DATASTORE,
    uint256 id
  ) external onlySenate(self) returns (uint256 _type, address _controller) {
    require(self._proposals[id].deadline > block.timestamp, "GU: NOT an active proposal");

    _type = self._proposals[id].TYPE;
    _controller = self._proposals[id].CONTROLLER;

    DATASTORE.writeUint(id, "TYPE", _type);
    DATASTORE.writeAddress(id, "CONTROLLER", _controller);
    DATASTORE.writeBytes(id, "NAME", self._proposals[id].NAME);
    DATASTORE.allIdsByType[_type].push(id);

    if (_type == ID_TYPE.SENATE) {
      _setSenate(self, _controller, block.timestamp + MAX_SENATE_PERIOD);
    } else if (_type == ID_TYPE.CONTRACT_UPGRADE) {
      self.approvedUpgrade = _controller;
    }

    // important
    self._proposals[id].deadline = block.timestamp;

    emit ProposalApproved(id);
  }

  /**
   * @notice                                       ** SENATE and GOVERNANCE **
   */

  /**
   * @dev  ->  internal
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
   * @dev  ->  external
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
    require(block.timestamp > self.SENATE_EXPIRY, "GU: cannot rescue yet");

    _setSenate(self, _newSenate, block.timestamp + MAX_SENATE_PERIOD);
  }

  /**
   * @notice                                       ** LIMITED UPGRADABILITY **
   */

  /**
   * @dev  ->  view
   */

  /**
   * @notice Get if it is allowed to change a specific contract with the current version.
   * @return True if it is allowed by senate and false if not.
   * @dev address(0) should return false
   * @dev currentImplementation should always be UUPS._getImplementation()
   * @dev DO NOT TOUCH, EVER! WHATEVER YOU DEVELOP IN FUCKING 3022
   **/
  function isUpgradeAllowed(
    DualGovernance storage self,
    address proposedImplementation,
    address currentImplementation
  ) external view returns (bool) {
    return
      (self.approvedUpgrade != address(0)) &&
      (proposedImplementation != currentImplementation) &&
      (self.approvedUpgrade == proposedImplementation);
  }
}