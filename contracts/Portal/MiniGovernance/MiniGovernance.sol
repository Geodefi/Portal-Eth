// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../utils/GeodeUtilsLib.sol";
import "../utils/DataStoreLib.sol";
import "../../interfaces/IgETH.sol";
import "../../interfaces/IPortal.sol";

contract MiniGovernances is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    event Proposed(
        uint256 id,
        address _CONTROLLER,
        uint256 _type,
        uint256 _duration
    );
    event ProposalApproved(uint256 id);
    event NewSenate(address senate, uint256 senate_expiry);

    event ContractVersionSet(uint256 version);

    using DataStoreUtils for DataStoreUtils.DataStore;
    using GeodeUtils for GeodeUtils.Universe;

    DataStoreUtils.DataStore private DATASTORE;
    GeodeUtils.Universe private GEM; // MiniGeode
    MiniGovernance private SELF;

    struct MiniGovernance {
        IgETH gETH;
        uint256 ID;
        bytes32 PASSWORD;
        uint256 lastPause;
        uint256 whenPauseAllowed;
        uint256 contractVersion;
        uint256 proposedVersion;
    }

    function initialize(
        address _gETH,
        uint256 _ID,
        address _PORTAL,
        uint256 _VERSION,
        address _MAINTAINER
    ) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        SELF.gETH = IgETH(_gETH);
        SELF.ID = _ID;
        SELF.lastPause = type(uint256).max;
        GEM.GOVERNANCE = _PORTAL;
        _refreshSenate(_MAINTAINER);

        SELF.contractVersion = _VERSION;
        emit ContractVersionSet(_VERSION);
    }

    modifier onlyPortal() {
        require(
            msg.sender == GEM.GOVERNANCE,
            "StakeUtils: sender is NOT PORTAL"
        );
        _;
    }

    modifier onlyMaintainer() {
        require(msg.sender == GEM.SENATE, "StakeUtils: sender is NOT SENATE");
        _;
    }

    function getPortal() internal view returns (IPortal) {
        return IPortal(GEM.GOVERNANCE);
    }

    ///@dev required by the UUPS module
    function _authorizeUpgrade(address proposed_implementation)
        internal
        virtual
        override
        onlyMaintainer
    {
        require(
            GEM.isUpgradeAllowed(proposed_implementation),
            "MiniGovernance: is NOT allowed to upgrade"
        );
    }

    function pause() external virtual onlyMaintainer {
        require(block.timestamp > SELF.whenPauseAllowed);
        _pause();
        SELF.lastPause = block.timestamp;
    }

    // can not spam pause / unpause
    function unpause() external virtual onlyMaintainer {
        _unpause();
        SELF.whenPauseAllowed = block.timestamp + 1 weeks;
        SELF.lastPause = type(uint256).max;
    }

    function getVersion() external view virtual returns (uint256) {
        return SELF.contractVersion;
    }

    // currently only rule is being not updated OR SENATE expired
    function isolationMode() public view virtual returns (bool) {
        return
            SELF.proposedVersion != SELF.contractVersion ||
            block.timestamp > GEM.SENATE_EXPIRY;
    }

    /**
     *                                          ** PROPOSALS **
     */

    // anyone can fetch proposal from Portal, so  we don't need to call it.
    // note: timer for isAbandoned starts after catch.
    function fetchUpgradeProposal() external virtual whenNotPaused {
        uint256 id = getPortal().miniGovernanceVersion();
        require(id != SELF.contractVersion);
        GeodeUtils.Proposal memory proposal = getPortal().getProposal(id);
        require(proposal.TYPE == 11);
        GEM.newProposal(proposal.CONTROLLER, 2, proposal.NAME, 4 weeks);
        SELF.proposedVersion = id;
    }

    function approveProposal(uint256 _id)
        external
        virtual
        whenNotPaused
        onlyMaintainer
    {
        GEM.approveProposal(DATASTORE, _id);
    }

    /**
     *                                          ** SENATE & UPGRADE MANAGEMENT **
     */
    function _refreshSenate(address newSenate) internal virtual whenNotPaused {
        GEM._setSenate(newSenate, block.timestamp + 180 days);
    }

    // changePassword(){refresh} onlySenate =>  no need old password
    function refreshSenate(bytes32 newPassword) external onlyMaintainer {
        SELF.PASSWORD = newPassword;
        _refreshSenate(GEM.SENATE);
    }

    // changeSenate(){refresh} onlyPortal => needs old password
    function changeMaintainer(
        bytes calldata password,
        bytes32 newPasswordHash,
        address newMaintainer
    ) external onlyPortal whenNotPaused {
        require(
            keccak256(abi.encodePacked(SELF.ID, password)) == SELF.PASSWORD
        );
        SELF.PASSWORD = newPasswordHash;

        _refreshSenate(newMaintainer);
    }

    function claimUnstake(uint256 claim)
        external
        onlyPortal
        returns (bool success)
    {
        (success, ) = payable(GEM.GOVERNANCE).call{value: claim}("");
        require(success, "StakeUtils: Failed to send Ether");
    }

    uint256[47] private __gap;
}
