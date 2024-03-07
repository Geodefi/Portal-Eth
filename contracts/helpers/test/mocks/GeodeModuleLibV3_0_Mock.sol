// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

// structs
import {DataStoreModuleStorage} from "../../../modules/DataStoreModule/structs/storage.sol";
// globals
import {ID_TYPE} from "../../../globals/id_type.sol";
import {RESERVED_KEY_SPACE as rks} from "../../../globals/reserved_key_space.sol";
// libraries
import {DataStoreModuleLib as DSML} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";
import {Proposal} from "../../../modules/GeodeModule/structs/utils.sol";

/**
 * @notice Storage struct for the Dual Governance logic
 * @dev Dual Governance allows 2 parties to manage a package with proposals and approvals.
 * @param GOVERNANCE a community that works to improve the core product and ensures its adoption in the DeFi ecosystem
 * Suggests updates, such as new operators, contract/package upgrades, a new Senate (without any permission to force them)
 * @param SENATE An address that protects the users by controlling the state of governance, contract updates and other crucial changes
 * @param APPROVED_UPGRADE only 1 implementation contract SHOULD be "approved" at any given time.
 * @param SENATE_EXPIRY refers to the last timestamp that SENATE can continue operating. Might not be utilized. Limited by MAX_SENATE_PERIOD
 * @param PACKAGE_TYPE every package has a specific TYPE. Defined in globals/id_type.sol
 * @param CONTRACT_VERSION always refers to the upgrade proposal ID. Does not increase uniformly like one might expect.
 * @param proposals till approved, proposals are kept separated from the Isolated Storage
 * @param __gap keep the struct size at 16
 **/
struct DualGovernanceV3_0_Mock {
  address GOVERNANCE;
  address SENATE;
  address APPROVED_UPGRADE;
  uint256 SENATE_EXPIRY;
  uint256 PACKAGE_TYPE;
  uint256 CONTRACT_VERSION;
  mapping(uint256 => Proposal) proposals;
  uint256 freshSlot;
  uint256[8] __gap;
}

/**
 * @title GML: Geode Module Library
 *
 * @notice Dual Governance & Limited Upgradability:
 * Administration of the Isolated Storage with a Dual Governance consisting a Governance and a Senate.
 * Administration of a UUPS contract with Limited Upgradability for Packages like Portal, LiquidityPool.
 *
 * @dev review: DataStoreModule for the id based isolated storage logic.
 * @dev review: Reserved TYPEs are defined within globals/id_type.sol
 *
 * @dev SENATE_EXPIRY is not mandatory to utilize. Simply set it to MAX_UINT256 if rescueSenate is not needed.
 *
 * @dev There are 3 ways to set a new Senate:
 * 1. With a proposal TYPE 1. Proposal's controller becomes the new Senate, refreshes the expiry.
 * 2. Current Senate can call changeSenate, which doesn't change the expiry
 * 3. As a circuit breaker: If senate is expired, then rescue senate can be called by governance.
 * @dev Currently, there are no way to set a new Governance.
 *
 *
 * @dev Contracts relying on this library must use GeodeModuleLib.GeodeModuleStorage
 * @dev This is an external library, requires deployment.
 *
 * @author Ice Bear & Crash Bandicoot
 */
library GeodeModuleLibV3_0_Mock {
  using DSML for DataStoreModuleStorage;

  /**
   * @custom:section                           ** CONSTANTS **
   */

  /// @notice a proposal can have a duration between 1 days to 4 weeks (inclusive)
  uint32 internal constant MIN_PROPOSAL_DURATION = 1 days;
  uint32 internal constant MAX_PROPOSAL_DURATION = 4 weeks;

  /// @notice if expiry is utilized, a senate can be active for a year.
  /// @dev "MAX" underlines a new senate can be set without expecting an expiry
  uint32 internal constant MAX_SENATE_PERIOD = 365 days;

  /**
   * @custom:section                           ** EVENTS **
   */
  event Proposed(uint256 indexed TYPE, uint256 ID, address CONTROLLER, uint256 deadline);
  event Approved(uint256 ID);
  event NewSenate(address senate, uint256 expiry);
  event ControllerChanged(uint256 indexed ID, address CONTROLLER);

  /**
   * @custom:section                           ** MODIFIERS **
   */
  modifier onlyGovernance(DualGovernanceV3_0_Mock storage self) {
    require(msg.sender == self.GOVERNANCE, "GML:GOVERNANCE role needed");
    _;
  }

  modifier onlySenate(DualGovernanceV3_0_Mock storage self) {
    require(msg.sender == self.SENATE, "GML:SENATE role needed");
    require(block.timestamp < self.SENATE_EXPIRY, "GML:SENATE expired");
    _;
  }

  modifier onlyController(DataStoreModuleStorage storage DATASTORE, uint256 id) {
    require(msg.sender == DATASTORE.readAddress(id, rks.CONTROLLER), "GML:CONTROLLER role needed");
    _;
  }

  /**
   * @custom:section                           ** LIMITED UUPS VERSION CONTROL **
   *
   * @custom:visibility -> view-external
   */

  function setFreshSlot(DualGovernanceV3_0_Mock storage self, uint256 value) external {
    self.freshSlot = value;
  }

  function getFreshSlot(DualGovernanceV3_0_Mock storage self) external view returns (uint256) {
    return self.freshSlot;
  }

  /**
   * @notice Check if it is allowed to change the package version to given proposedImplementation.
   * @dev provided for _authorizeUpgrade
   * @dev currentImplementation should always be UUPS._getImplementation()
   * @dev currentImplementation or zero as proposedImplementation will return false
   **/
  function isUpgradeAllowed(
    DualGovernanceV3_0_Mock storage self,
    address proposedImplementation,
    address currentImplementation
  ) external view returns (bool) {
    return
      (self.APPROVED_UPGRADE != address(0)) &&
      (proposedImplementation != currentImplementation) &&
      (self.APPROVED_UPGRADE == proposedImplementation);
  }

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   *
   * @custom:visibility -> view-external
   */

  function getProposal(
    DualGovernanceV3_0_Mock storage self,
    uint256 id
  ) external view returns (Proposal memory) {
    return self.proposals[id];
  }

  /**
   * @custom:section                           ** SETTER FUNCTIONS **
   */

  /**
   * @custom:subsection                        ** INTERNAL **
   *
   * @custom:visibility -> internal
   */
  function _setSenate(
    DualGovernanceV3_0_Mock storage self,
    address _newSenate,
    uint256 _expiry
  ) internal {
    require(_newSenate != address(0), "GML:Senate cannot be zero address");
    self.SENATE = _newSenate;
    self.SENATE_EXPIRY = _expiry;

    emit NewSenate(self.SENATE, self.SENATE_EXPIRY);
  }

  /**
   * @custom:subsection                        ** ONLY GOVERNANCE **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice generates a new ID with given TYPE and NAME, proposes it to be owned by a CONTROLLER.
   * @dev DATASTORE[id] will not be updated until the proposal is approved
   * @dev Proposals can NEVER be overriden
   */
  function propose(
    DualGovernanceV3_0_Mock storage self,
    DataStoreModuleStorage storage DATASTORE,
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external onlyGovernance(self) returns (uint256 id) {
    id = DSML.generateId(_NAME, _TYPE);

    require(self.proposals[id].deadline == 0, "GML:already proposed");
    require((DATASTORE.readBytes(id, rks.NAME)).length == 0, "GML:ID already exist");
    require(_CONTROLLER != address(0), "GML:CONTROLLER cannot be ZERO");
    require((_TYPE != ID_TYPE.NONE) && (_TYPE != ID_TYPE.POOL), "GML:TYPE is NONE or POOL");
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
   * @notice changes Senate in a scenerio where the current Senate acts maliciously!
   * * We are sure this will not be the case, but creating a method for possible recovery is a must.
   * @notice Normally, Governance creates Senate Proposals frequently to signal it does not have
   * * any intent of malicious overtake.
   * note: If Governance does not send a Senate Proposal "a while" before the SENATE_EXPIRY,
   * * we recommend users to take their money out.
   * @dev Obviously, Governance needs to wait for SENATE_EXPIRY.
   * @dev Refreshes the expiry
   */
  function rescueSenate(
    DualGovernanceV3_0_Mock storage self,
    address _newSenate
  ) external onlyGovernance(self) {
    require(block.timestamp > self.SENATE_EXPIRY, "GML:cannot rescue yet");

    _setSenate(self, _newSenate, block.timestamp + MAX_SENATE_PERIOD);
  }

  /**
   * @custom:subsection                        ** ONLY SENATE **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice approves a proposal and records given data to DataStore
   * @notice specific changes for the reserved types (1, 2, 3) are implemented here,
   * any other addition should take place in Portal, as not related.
   * Note that GM has additional logic for package type approvals.
   * @param id given ID proposal that has will be approved by Senate
   * @dev Senate is not able to approve approved proposals
   * @dev Senate is not able to approve expired proposals
   */
  function approveProposal(
    DualGovernanceV3_0_Mock storage self,
    DataStoreModuleStorage storage DATASTORE,
    uint256 id
  ) external onlySenate(self) returns (address _controller, uint256 _type, bytes memory _name) {
    require(self.proposals[id].deadline > block.timestamp, "GML:not an active proposal");

    _controller = self.proposals[id].CONTROLLER;
    _type = self.proposals[id].TYPE;
    _name = self.proposals[id].NAME;

    DATASTORE.writeUint(id, rks.TYPE, _type);
    DATASTORE.writeAddress(id, rks.CONTROLLER, _controller);
    DATASTORE.writeBytes(id, rks.NAME, _name);
    DATASTORE.allIdsByType[_type].push(id);

    if (_type == ID_TYPE.SENATE) {
      _setSenate(self, _controller, block.timestamp + MAX_SENATE_PERIOD);
    } else if (_type == self.PACKAGE_TYPE) {
      self.APPROVED_UPGRADE = _controller;
    }

    // important
    self.proposals[id].deadline = block.timestamp;

    emit Approved(id);
  }

  /**
   * @notice It is useful to be able to change the Senate's address without changing the expiry.
   * @dev Does not change the expiry
   */
  function changeSenate(
    DualGovernanceV3_0_Mock storage self,
    address _newSenate
  ) external onlySenate(self) {
    _setSenate(self, _newSenate, self.SENATE_EXPIRY);
  }

  /**
   * @custom:section                           ** ONLY CONTROLLER **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice change the CONTROLLER of an ID
   * @dev this operation cannot be reverted by the old CONTROLLER!!!
   * @dev cannot provide address(0), try 0x000000000000000000000000000000000000dEaD
   */
  function changeIdCONTROLLER(
    DataStoreModuleStorage storage DATASTORE,
    uint256 id,
    address newCONTROLLER
  ) external onlyController(DATASTORE, id) {
    require(newCONTROLLER != address(0), "GML:CONTROLLER cannot be zero");

    uint256 typeOfId = DATASTORE.readUint(id, rks.TYPE);
    require(
      typeOfId > ID_TYPE.LIMIT_MIN_USER && typeOfId < ID_TYPE.LIMIT_MAX_USER,
      "GML:ID TYPE is not user"
    );

    DATASTORE.writeAddress(id, rks.CONTROLLER, newCONTROLLER);

    emit ControllerChanged(id, newCONTROLLER);
  }
}
