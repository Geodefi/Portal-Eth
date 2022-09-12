// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "../../utils/DataStoreUtilsLib.sol";
import "../../utils/GeodeUtilsLib.sol";

contract TestGeodeUtils {
    using DataStoreUtils for DataStoreUtils.DataStore;
    using GeodeUtils for GeodeUtils.Universe;
    DataStoreUtils.DataStore private DATASTORE;
    GeodeUtils.Universe private GEODE;

    constructor(
        address _GOVERNANCE,
        address _SENATE,
        uint256 _GOVERNANCE_TAX,
        uint256 _MAX_GOVERNANCE_TAX
    ) {
        GEODE.GOVERNANCE = _GOVERNANCE;
        GEODE.SENATE = _SENATE;
        GEODE.SENATE_EXPIRY = block.timestamp + 1 days;
        GEODE.GOVERNANCE_TAX = _GOVERNANCE_TAX;
        GEODE.MAX_GOVERNANCE_TAX = _MAX_GOVERNANCE_TAX;

        GEODE.setElectorType(DATASTORE, 5, true); // allow type4 to vote for Senate

        GEODE.approvedUpgrade = address(0);
    }

    function getSenate() external view virtual returns (address) {
        return GEODE.getSenate();
    }

    function getGovernance() external view virtual returns (address) {
        return GEODE.getGovernance();
    }

    function getGovernanceTax() external view virtual returns (uint256) {
        return GEODE.getGovernanceTax();
    }

    function getPERCENTAGE_DENOMINATOR()
        external
        view
        virtual
        returns (uint256)
    {
        return GeodeUtils.PERCENTAGE_DENOMINATOR;
    }

    function getMaxGovernanceTax() external view virtual returns (uint256) {
        return GEODE.getMaxGovernanceTax();
    }

    function getSenateExpireTimestamp()
        external
        view
        virtual
        returns (uint256)
    {
        return GEODE.getSenateExpireTimestamp();
    }

    /**
     **  ID GETTERS **
     */
    function getIdsByTYPE(uint256 _TYPE)
        external
        view
        virtual
        returns (uint256[] memory)
    {
        return DATASTORE.allIdsByType[_TYPE];
    }

    function getId(string calldata _NAME, uint256 _TYPE)
        external
        pure
        virtual
        returns (uint256 _id)
    {
        return uint256(keccak256(abi.encodePacked(_NAME, _TYPE)));
    }

    function getCONTROLLERFromId(uint256 _id)
        external
        view
        virtual
        returns (address)
    {
        return GeodeUtils.getCONTROLLERFromId(DATASTORE, _id);
    }

    function getTYPEFromId(uint256 _id)
        external
        view
        virtual
        returns (uint256)
    {
        return GeodeUtils.getTYPEFromId(DATASTORE, _id);
    }

    function getNAMEFromId(uint256 _id)
        external
        view
        virtual
        returns (bytes memory)
    {
        return GeodeUtils.getNAMEFromId(DATASTORE, _id);
    }

    /**
     *                                          ** SETTERS **
     */
    function changeIdCONTROLLER(uint256 _id, address _newCONTROLLER)
        external
        virtual
    {
        GeodeUtils.changeIdCONTROLLER(DATASTORE, _id, _newCONTROLLER);
    }

    /**
     * ** GOVERNANCE/SENATE SETTERS **
     */
    function setGovernanceTax(uint256 _newFee)
        external
        virtual
        returns (bool success)
    {
        // onlyGovernance CHECKED inside
        success = GEODE.setGovernanceTax(_newFee);
    }

    function setMaxGovernanceTax(uint256 _newFee)
        external
        virtual
        returns (bool success)
    {
        // onlySenate CHECKED inside
        success = GEODE.setMaxGovernanceTax(_newFee);
    }

    /**
     *                                          ** PROPOSALS **
     */

    function getProposal(uint256 id)
        external
        view
        virtual
        returns (GeodeUtils.Proposal memory)
    {
        return GEODE.getProposal(id);
    }

    function newProposal(
        address _CONTROLLER,
        uint256 _TYPE,
        bytes calldata _NAME,
        uint256 _proposalDuration
    ) external virtual {
        require(
            DATASTORE
                .readBytesForId(
                    uint256(keccak256(abi.encodePacked(_NAME, _TYPE))),
                    "NAME"
                )
                .length == 0,
            "GeodeUtils: NAME already claimed"
        );
        GEODE.newProposal(_CONTROLLER, _TYPE, _NAME, _proposalDuration);
    }

    function approveProposal(uint256 _id) external virtual {
        GEODE.approveProposal(DATASTORE, _id);
    }

    function approveSenate(uint256 proposalId, uint256 electorId)
        external
        virtual
    {
        GEODE.approveSenate(DATASTORE, proposalId, electorId);
    }

    function setSenate(address newSenate, uint256 senatePeriod)
        external
        virtual
    {
        GEODE._setSenate(newSenate, senatePeriod);
    }

    /// @dev DO NOT TOUCH, EVER! WHATEVER YOU DEVELOP IN FUCKING 3022.
    function isUpgradeAllowed(address proposed_implementation)
        external
        view
        virtual
        returns (bool)
    {
        return GEODE.isUpgradeAllowed(proposed_implementation);
    }
}
