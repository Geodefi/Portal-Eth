// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../utils/DataStoreUtilsLib.sol";
import "../utils/GeodeUtilsLib.sol";
import "../../interfaces/IgETH.sol";
import "../../interfaces/IPortal.sol";
import "../../interfaces/IMiniGovernance.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title MiniGovernance: local defense layer of the trustless Staking Derivatives
 * @dev Global defense layer is the Portal
 * @notice This contract is being used as the withdrawal credential of the validators,
 * * that are maintained by the given IDs maintainer.
 * @dev currently only defense mechanics this contract provides is the trustless updates that are
 * * achieved with GeodeUtils and passwordHashes
 * * 1. portal cannot change the maintainer without knowing the real password
 * * 2. portal cannot upgrade the contract without Maintainer's approval
 * *
 * * However there are such improvements planned to be implemented to make
 * * the staking environment more trustless.
 * * * "isolationMode" is one of them, currently only rules of the isolation mode is Senate_Expiry and
 * * * isUpgraded check. However, this is a good start to ensure that the future implementations will be
 * * * enforced to incentivise the trustless behaviour! The end goal is to create mini-portals
 * * * with different mechanics and allow auto-staking contracts...
 */
contract MiniGovernance is
    IMiniGovernance,
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
    GeodeUtils.Universe private GEM; // MiniGeode :)
    PoolGovernance private SELF;

    /**
     * @dev While there are currently no worry on if the pool will be abandoned,
     * with the introduction of private pools, it can be a problem.
     * Thus, we require senate to refresh it's validity time to time.
     */
     uint256 constant SENATE_VALIDITY = 180 days;
    /**
     * @dev While there are currently no worry on what pausing will affect,
     * with the next implementations, spamming stake/unstake can cause an issue.
     * Thus, we require senate to wait a bit before pausing the contract again, allowing
     * validator unstake(maybe).
     */
    uint256 constant PAUSE_LAPSE = 1 weeks;

    struct PoolGovernance {
        IgETH gETH;
        uint256 ID;
        bytes32 PASSWORD_HASH;
        uint256 lastPause;
        uint256 whenPauseAllowed;
        uint256 contractVersion;
        uint256 proposedVersion;
        uint256[9] __gap;
    }

    function initialize(
        address _gETH,
        address _PORTAL,
        address _MAINTAINER,
        uint256 _ID,
        uint256 _VERSION
    ) public virtual override initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        SELF.gETH = IgETH(_gETH);
        SELF.ID = _ID;
        SELF.lastPause = type(uint256).max;
        GEM.GOVERNANCE = _PORTAL;
        _refreshSenate(_MAINTAINER);

        SELF.contractVersion = _VERSION;
        SELF.proposedVersion = _VERSION;
        emit ContractVersionSet(_VERSION);
    }

    modifier onlyPortal() {
        require(
            msg.sender == GEM.GOVERNANCE,
            "MiniGovernance: sender is NOT PORTAL"
        );
        _;
    }

    modifier onlyMaintainer() {
        require(msg.sender == GEM.SENATE, "MiniGovernance: sender is NOT SENATE");
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

    function pause() external virtual override onlyMaintainer {
        require(block.timestamp > SELF.whenPauseAllowed);
        _pause();
        SELF.lastPause = block.timestamp;
    }

    /// @dev cannot spam, be careful
    function unpause() external virtual override onlyMaintainer {
        _unpause();
        SELF.whenPauseAllowed = block.timestamp + PAUSE_LAPSE;
        SELF.lastPause = type(uint256).max;
    }

    function getCurrentVersion()
        external
        view
        virtual
        override
        returns (uint256)
    {
        return SELF.contractVersion;
    }

    function getProposedVersion()
        external
        view
        virtual
        override
        returns (uint256)
    {
        return SELF.proposedVersion;
    }

    function isolationMode() public view virtual override returns (bool) {
        return
            SELF.contractVersion != SELF.proposedVersion ||
            block.timestamp > GEM.SENATE_EXPIRY;
    }

    /**
     *                                          ** PROPOSALS **
     */

    /**
     * @notice anyone can fetch proposal from Portal, so  we don't need to call it.
     */
    function fetchUpgradeProposal() external virtual override {
        uint256 id = getPortal().miniGovernanceVersion();
        require(id != SELF.contractVersion);
        GeodeUtils.Proposal memory proposal = getPortal().getProposal(id);
        require(proposal.TYPE == 11);
        GEM.newProposal(proposal.CONTROLLER, 2, proposal.NAME, 5 days);
        SELF.proposedVersion = id;
    }

    function approveProposal(uint256 _id)
        external
        virtual
        override
        whenNotPaused
        onlyMaintainer
    {
        GEM.approveProposal(DATASTORE, _id);
    }

    /**
     *                                          ** SENATE & UPGRADE MANAGEMENT **
     */
    function _refreshSenate(address newSenate) internal virtual whenNotPaused {
        GEM._setSenate(newSenate, SENATE_VALIDITY);
    }

    /**
     * @dev should change the password, every now and then
     * @param newPasswordHash = keccak256(abi.encodePacked(SELF.ID, password))
     */
    function refreshSenate(bytes32 newPasswordHash)
        external
        virtual
        override
        onlyMaintainer
    {
        SELF.PASSWORD_HASH = newPasswordHash;
        _refreshSenate(GEM.SENATE);
    }

    /**
     * @notice Portal changing the Senate of Minigovernance when the maintainer of the pool is changed
     * @dev (Senate+Governance) can possibly access this function if they are working together.
     * * Thus, access to this function requires an optional password.
     * @param newPasswordHash = keccak256(abi.encodePacked(SELF.ID, password))
     */
    function changeMaintainer(
        bytes calldata password,
        bytes32 newPasswordHash,
        address newMaintainer
    )
        external
        virtual
        override
        onlyPortal
        whenNotPaused
        returns (bool success)
    {
        require(
            SELF.PASSWORD_HASH == bytes32(0) ||
                SELF.PASSWORD_HASH ==
                keccak256(abi.encodePacked(SELF.ID, password))
        );
        SELF.PASSWORD_HASH = newPasswordHash;

        _refreshSenate(newMaintainer);

        success = true;
    }

    /**
     * @notice according to eip-4895, the unstaked balances will be just happen to emerge within this contract.
     * * Telescope (oracle) will be watching these events andn finalizing the unstakes.
     * * This method even makes it possible to claim rewards without unstake, which we know is a possibility
     * @param claim specified amount can be the unstaked balance or just a reward, ETH.
     * @return success if claim was successful
     */
    function claimUnstake(uint256 claim)
        external
        virtual
        override
        onlyPortal
        nonReentrant
        returns (bool success)
    {
        (success, ) = payable(GEM.GOVERNANCE).call{value: claim}("");
        require(success, "MiniGovernance: Failed to send Ether");
    }

    /// @notice keep the contract size at 50
    uint256[45] private __gap;
}
