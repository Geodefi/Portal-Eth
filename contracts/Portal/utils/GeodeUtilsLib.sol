// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "./DataStoreUtilsLib.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title GeodeUtils library
 * @notice Exclusively contains functions responsible for administration of DATASTORE,
 * including functions related to "limited upgradability" with Senate & proposals.
 * @dev Contracts relying on this library must initialize GeodeUtils.Universe
 * @dev ALL "fee" variables are limited by PERCENTAGE_DENOMINATOR = 100%
 * @dev Admin functions are already protected
 * Note this library contains both functions called by users(ID) (approveSenate) and admins(GOVERNANCE, SENATE)
 * Note refer to DataStoreUtils before reviewing
 */
library GeodeUtils {
    using DataStoreUtils for DataStoreUtils.DataStore;

    event GovernanceTaxUpdated(uint256 newFee);
    event MaxGovernanceTaxUpdated(uint256 newMaxFee);
    event ControllerChanged(uint256 id, address newCONTROLLER);
    event Proposed(
        uint256 id,
        address CONTROLLER,
        uint256 TYPE,
        uint256 deadline
    );
    event ProposalApproved(uint256 id);
    event ElectorTypeSet(uint256 TYPE, bool isElector);
    event Vote(uint256 proposalId, uint256 electorId);
    event NewSenate(address senate, uint256 senateExpiry);

    /**
     * @notice Proposal basically refers to give the control of an ID to a CONTROLLER.
     *
     * @notice A Proposal has 4 specs:
     * @param TYPE: separates the proposals and related functionality between different ID types.
     * * RESERVED TYPES on GeodeUtils:
     * * * TYPE 0: inactive
     * * * TYPE 1: Senate: controls state of governance, contract updates and other members of A Universe
     * * * TYPE 2: Upgrade: address of the implementation for desired contract upgrade
     * * * TYPE 3: **gap** : formally it represented the admin contract, however since UUPS is being used as a upgrade path,
     * this TYPE is now reserved.
     *
     * @param name: id is created by keccak(name, type)
     *
     * @param CONTROLLER: the address that refers to the change that is proposed by given proposal ID.
     * * This slot can refer to the controller of an id, a new implementation contract, a new Senate etc.
     *
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
     * @notice Universe is A blockchain. In this case, it defines Ethereum
     * @param GOVERNANCE a community that works to improve the core product and ensures its adoption in the DeFi ecosystem
     * Suggests updates, such as new planets, operators, comets, contract upgrades and new Senate, on the Ecosystem -without any permission to force them-
     * @param SENATE An address that controls the state of governance, updates and other users in the Geode Ecosystem
     * Note SENATE is proposed by Governance and voted by all elector types, operates if ⌊2/3⌋ approves.
     * @param GOVERNANCE_TAX operation fee of the given contract, acquired by GOVERNANCE. Limited by MAX_GOVERNANCE_TAX
     * @param MAX_GOVERNANCE_TAX set by SENATE, limited by PERCENTAGE_DENOMINATOR
     * @param SENATE_EXPIRY refers to the last timestamp that SENATE can continue operating. Enforces a new election, limited by MAX_SENATE_PERIOD
     * @param approvedUpgrade only 1 implementation contract can be "approved" at any given time. @dev safe to set to address(0) after every upgrade
     * @param _electorCount increased when a new id is added with _electorTypes[id] == true
     * @param _electorTypes only given types can vote @dev MUST only change during upgrades.
     * @param _proposalForId proposals are kept seperately instead of setting the parameters of id in DATASTORE, and then setting it's type; to allow surpassing type checks to save gas cost
     **/
    struct Universe {
        address SENATE;
        address GOVERNANCE;
        uint256 GOVERNANCE_TAX;
        uint256 MAX_GOVERNANCE_TAX;
        uint256 SENATE_EXPIRY;
        address approvedUpgrade;
        uint256 _electorCount;
        mapping(uint256 => bool) _electorTypes;
        mapping(uint256 => Proposal) _proposalForId;
    }

    /// @notice PERCENTAGE_DENOMINATOR represents 100%
    uint256 public constant PERCENTAGE_DENOMINATOR = 10**10;

    uint32 public constant MIN_PROPOSAL_DURATION = 1 days;
    uint32 public constant MAX_PROPOSAL_DURATION = 2 weeks;
    uint32 public constant MAX_SENATE_PERIOD = 365 days; // 1 year

    modifier onlySenate(Universe storage self) {
        require(msg.sender == self.SENATE, "GeodeUtils: SENATE role needed");
        require(
            block.timestamp < self.SENATE_EXPIRY,
            "GeodeUtils: SENATE not active"
        );
        _;
    }

    modifier onlyGovernance(Universe storage self) {
        require(
            msg.sender == self.GOVERNANCE,
            "GeodeUtils: GOVERNANCE role needed"
        );
        _;
    }

    modifier onlyController(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) {
        require(
            msg.sender == DATASTORE.readAddressForId(id, "CONTROLLER"),
            "GeodeUtils: CONTROLLER role needed"
        );
        _;
    }

    /**
     *                                         ** UNIVERSE GETTERS **
     **/

    /**
     * @return address of SENATE
     **/
    function getSenate(Universe storage self) external view returns (address) {
        return self.SENATE;
    }

    /**
     * @return address of GOVERNANCE
     **/
    function getGovernance(Universe storage self)
        external
        view
        returns (address)
    {
        return self.GOVERNANCE;
    }

    /**
     * @notice MAX_GOVERNANCE_TAX must limit GOVERNANCE_TAX even if MAX is changed
     * @return active GOVERNANCE_TAX, limited by MAX_GOVERNANCE_TAX
     */
    function getGovernanceTax(Universe storage self)
        external
        view
        returns (uint256)
    {
        return self.GOVERNANCE_TAX;
    }

    /**
     *  @return MAX_GOVERNANCE_TAX
     */
    function getMaxGovernanceTax(Universe storage self)
        external
        view
        returns (uint256)
    {
        return self.MAX_GOVERNANCE_TAX;
    }

    /**
     * @return the expiration date of current SENATE as a timestamp
     */
    function getSenateExpiry(Universe storage self)
        external
        view
        returns (uint256)
    {
        return self.SENATE_EXPIRY;
    }

    /**
     *                                         ** UNIVERSE SETTERS **
     */

    /**
     * @dev can not set the fee more than MAX_GOVERNANCE_TAX
     * @dev no need to check PERCENTAGE_DENOMINATOR because MAX_GOVERNANCE_TAX is limited already
     * @return true if the operation was succesful, might be helpful when governance rights are distributed
     */
    function setGovernanceTax(Universe storage self, uint256 newFee)
        external
        onlyGovernance(self)
        returns (bool)
    {
        require(
            newFee <= self.MAX_GOVERNANCE_TAX,
            "GeodeUtils: cannot be more than MAX_GOVERNANCE_TAX"
        );

        self.GOVERNANCE_TAX = newFee;

        emit GovernanceTaxUpdated(newFee);

        return true;
    }

    /**
     * @dev can not set a fee more than PERCENTAGE_DENOMINATOR (100%)
     * @return true if the operation was succesful
     */
    function setMaxGovernanceTax(Universe storage self, uint256 newMaxFee)
        external
        onlySenate(self)
        returns (bool)
    {
        require(
            newMaxFee <= PERCENTAGE_DENOMINATOR,
            "GeodeUtils: fee more than 100%"
        );

        self.MAX_GOVERNANCE_TAX = newMaxFee;

        emit MaxGovernanceTaxUpdated(newMaxFee);

        return true;
    }

    /**
     *                                          ** ID **
     */

    /**
     * @dev Some TYPEs may require permissionless creation. But to allow anyone to claim any ID,
     * meaning malicious actors can claim names and operate pools to mislead people. To prevent this
     * TYPEs will be considered during id generation.
     */
    function _generateId(bytes calldata _NAME, uint256 _TYPE)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(_NAME, _TYPE)));
    }

    /**
     * @dev returns address(0) for empty ids, mandatory
     */
    function getCONTROLLERFromId(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external view returns (address) {
        return DATASTORE.readAddressForId(id, "CONTROLLER");
    }

    /**
     * @dev returns uint(0) for empty ids, mandatory
     */
    function getTYPEFromId(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external view returns (uint256) {
        return DATASTORE.readUintForId(id, "TYPE");
    }

    /**
     * @dev returns bytes(0) for empty ids, mandatory
     */
    function getNAMEFromId(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external view returns (bytes memory) {
        return DATASTORE.readBytesForId(id, "NAME");
    }

    /**
     * @notice only the current CONTROLLER can change
     * @dev this operation can not be reverted by the old CONTROLLER
     * @dev in case the current controller wants to remove the
     * need to upgrade to Controller they should provide smt like 0x000000000000000000000000000000000000dEaD
     */
    function changeIdCONTROLLER(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        address newCONTROLLER
    ) external onlyController(DATASTORE, id) {
        require(
            newCONTROLLER != address(0),
            "GeodeUtils: CONTROLLER can not be zero"
        );

        DATASTORE.writeAddressForId(id, "CONTROLLER", newCONTROLLER);

        emit ControllerChanged(id, newCONTROLLER);
    }

    /**
     *                                          ** PROPOSALS **
     */

    /**
     * CONTROLLER Proposals
     */

    function getProposal(Universe storage self, uint256 id)
        external
        view
        returns (Proposal memory)
    {
        return self._proposalForId[id];
    }

    /**
     * @notice a proposal can never be overriden.
     * @notice DATASTORE(id) will not be updated until the proposal is approved.
     * @dev refer to structure of Proposal for explanations of params
     */
    function newProposal(
        Universe storage self,
        address _CONTROLLER,
        uint256 _TYPE,
        bytes calldata _NAME,
        uint256 duration
    ) external onlyGovernance(self) returns (uint256 id) {
        require(
            duration >= MIN_PROPOSAL_DURATION,
            "GeodeUtils: duration should be higher than MIN_PROPOSAL_DURATION"
        );
        require(
            duration <= MAX_PROPOSAL_DURATION,
            "GeodeUtils: duration exceeds MAX_PROPOSAL_DURATION"
        );

        id = _generateId(_NAME, _TYPE);

        require(
            self._proposalForId[id].deadline == 0,
            "GeodeUtils: NAME already proposed"
        );

        self._proposalForId[id] = Proposal({
            CONTROLLER: _CONTROLLER,
            TYPE: _TYPE,
            NAME: _NAME,
            deadline: block.timestamp + duration
        });

        emit Proposed(id, _CONTROLLER, _TYPE, block.timestamp + duration);
    }

    /**
     *  @notice type specific changes for reserved_types(1,2,3) are implemented here,
     *  any other addition should take place in Portal, as not related
     *  @param id given ID proposal that has been approved by Senate
     *  @dev Senate should not be able to approve approved proposals
     *  @dev Senate should not be able to approve expired proposals
     *  @dev Senate should not be able to approve SENATE proposals :)
     */
    function approveProposal(
        Universe storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external onlySenate(self) {
        require(
            self._proposalForId[id].deadline > block.timestamp,
            "GeodeUtils: proposal expired"
        );
        require(
            self._proposalForId[id].TYPE != 1,
            "GeodeUtils: Senate can not approve Senate Election"
        );

        DATASTORE.writeAddressForId(
            id,
            "CONTROLLER",
            self._proposalForId[id].CONTROLLER
        );
        DATASTORE.writeUintForId(id, "TYPE", self._proposalForId[id].TYPE);
        DATASTORE.writeBytesForId(id, "NAME", self._proposalForId[id].NAME);

        if (self._proposalForId[id].TYPE == 2) {
            self.approvedUpgrade = self._proposalForId[id].CONTROLLER;
        }

        if (self._electorTypes[DATASTORE.readUintForId(id, "TYPE")]) {
            self._electorCount += 1;
        }

        DATASTORE.allIdsByType[self._proposalForId[id].TYPE].push(id);
        self._proposalForId[id].deadline = block.timestamp;

        emit ProposalApproved(id);
    }

    /**
     * SENATE Proposals
     */

    /**
     * @notice only elector types can vote for senate
     * @param _TYPE selected type
     * @param isElector true if selected _type can vote for senate from now on
     * @dev can not set with the same value again, preventing double increment/decrements
     */
    function setElectorType(
        Universe storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _TYPE,
        bool isElector
    ) external onlyGovernance(self) {
        require(
            self._electorTypes[_TYPE] != isElector,
            "GeodeUtils: type already _isElector"
        );
        require(
            _TYPE != 0 && _TYPE != 1 && _TYPE != 2 && _TYPE != 3,
            "GeodeUtils: 0, Senate, Upgrade cannot be elector"
        );

        self._electorTypes[_TYPE] = isElector;

        if (isElector) {
            self._electorCount += DATASTORE.allIdsByType[_TYPE].length;
        } else {
            self._electorCount -= DATASTORE.allIdsByType[_TYPE].length;
        }

        emit ElectorTypeSet(_TYPE, isElector);
    }

    /**
     * @notice Proposed CONTROLLER is the new Senate after 2/3 of the electors approved
     * NOTE mathematically, min 4 elector is needed for (c+1)*2/3 to work properly
     * @notice id can not vote if:
     * - approved already
     * - proposal is expired
     * - not its type is elector
     * - not senate proposal
     * @param electorId should have the voting rights, msg.sender should be the CONTROLLER of given ID
     * @dev pins id as "voted" when approved
     * @dev increases "approvalCount" of proposalId by 1 when approved
     */
    function approveSenate(
        Universe storage self,
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 proposalId,
        uint256 electorId
    ) external onlyController(DATASTORE, electorId) {
        require(
            self._proposalForId[proposalId].TYPE == 1,
            "GeodeUtils: NOT Senate Proposal"
        );
        require(
            self._proposalForId[proposalId].deadline >= block.timestamp,
            "GeodeUtils: proposal expired"
        );
        require(
            self._electorTypes[DATASTORE.readUintForId(electorId, "TYPE")],
            "GeodeUtils: NOT an elector"
        );
        require(
            DATASTORE.readUintForId(
                proposalId,
                DataStoreUtils.getKey(electorId, "voted")
            ) == 0,
            " GeodeUtils: already approved"
        );

        DATASTORE.writeUintForId(
            proposalId,
            DataStoreUtils.getKey(electorId, "voted"),
            1
        );
        DATASTORE.addUintForId(proposalId, "approvalCount", 1);

        if (
            DATASTORE.readUintForId(proposalId, "approvalCount") >=
            ((self._electorCount + 1) * 2) / 3
        ) {
            self._proposalForId[proposalId].deadline = block.timestamp;
            _setSenate(
                self,
                self._proposalForId[proposalId].CONTROLLER,
                MAX_SENATE_PERIOD
            );
        }

        emit Vote(proposalId, electorId);
    }

    function _setSenate(
        Universe storage self,
        address _newSenate,
        uint256 _senatePeriod
    ) internal {
        self.SENATE = _newSenate;
        self.SENATE_EXPIRY = block.timestamp + _senatePeriod;

        emit NewSenate(self.SENATE, self.SENATE_EXPIRY);
    }

    /**
     * @notice Get if it is allowed to change a specific contract with the current version.
     * @return True if it is allowed by senate and false if not.
     * @dev address(0) should return false
     * @dev DO NOT TOUCH, EVER! WHATEVER YOU DEVELOP IN FUCKING 3022
     **/
    function isUpgradeAllowed(
        Universe storage self,
        address proposedImplementation
    ) external view returns (bool) {
        return
            self.approvedUpgrade != address(0) &&
            self.approvedUpgrade == proposedImplementation;
    }
}
