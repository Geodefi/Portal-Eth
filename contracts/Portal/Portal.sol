// SPDX-License-Identifier: MIT

//   ██████╗ ███████╗ ██████╗ ██████╗ ███████╗    ██████╗  ██████╗ ██████╗ ████████╗ █████╗ ██╗
//  ██╔════╝ ██╔════╝██╔═══██╗██╔══██╗██╔════╝    ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██║
//  ██║  ███╗█████╗  ██║   ██║██║  ██║█████╗      ██████╔╝██║   ██║██████╔╝   ██║   ███████║██║
//  ██║   ██║██╔══╝  ██║   ██║██║  ██║██╔══╝      ██╔═══╝ ██║   ██║██╔══██╗   ██║   ██╔══██║██║
//  ╚██████╔╝███████╗╚██████╔╝██████╔╝███████╗    ██║     ╚██████╔╝██║  ██║   ██║   ██║  ██║███████╗
//   ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
//

pragma solidity =0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./utils/DataStoreUtilsLib.sol";
import "./utils/GeodeUtilsLib.sol";
import "./utils/OracleUtilsLib.sol";
import "./utils/MaintainerUtilsLib.sol";
import "./utils/StakeUtilsLib.sol";

import "../interfaces/IPortal.sol";
import "../interfaces/IgETH.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title Geode Finance Ethereum Portal: Trustless Dynamic Liquid Staking Pools
 * *
 * @notice Geode Portal provides a first of its kind trustless implementation on LSDs: gETH
 * * * These derivatives are maintained within Portal's functionality.
 *
 * * Global trustlessness is achieved by GeodeUtils, which makes sure that
 * * * every update is approved by a Senate before being effective.
 * * * Senate is elected by the all maintainers.
 *
 * * Local trustlessness is achieved by MiniGovernances, which is used as a withdrawal
 * * * credential contract. However, similar to Portal, upgrade requires the approval of
 * * * local Senate. Isolation Mode (WIP), will allow these contracts to become mini-portals
 * * * and allow the unstaking operations to be done directly, in the future.
 *
 * * StakeUtils contains all the staking related functionalities, including pool management
 * * * and Oracle activities.
 * * * These operations relies on a Dynamic Withdrawal Pool, which is a StableSwap
 * * * pool with a dynamic peg.
 *
 * * * One thing to consider is that currently private pools implementation is WIP, but the overall
 * * * design is done while ensuring it is possible without much changes in the future.
 *
 * @dev refer to DataStoreUtils before reviewing
 * @dev refer to GeodeUtils > Includes the logic for management of Geode Portal with Senate/Governance.
 * @dev refer to StakeUtils > Includes the logic for staking functionality with Withdrawal Pools
 * * * MaintainerUtils is a library used by StakeUtils, handling the maintainer related functionalities
 * * * OracleUtils is a library used by StakeUtils, handling the Oracle related functionalities
 *
 * @notice TYPE: seperates the proposals and related functionality between different ID types.
 * * CURRENTLY RESERVED TYPES on Portal:
 * * * TYPE 0: *invalid*
 * * * TYPE 1: Senate Election
 * * * TYPE 2: Portal Upgrade
 * * * TYPE 3: *gap*
 * * * TYPE 4: Validator Operator
 * * * TYPE 5: Planet (public pool)
 * * * TYPE 6: Comet (private pool)
 * * * TYPE 11: MiniGovernance Upgrade
 *
 * note ctrl+k+2 and ctrl+k+1 then scroll while reading the function names and opening the comments.
 */

contract Portal is
    IPortal,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    ERC1155HolderUpgradeable,
    UUPSUpgradeable
{
    using DataStoreUtils for DataStoreUtils.DataStore;
    using MaintainerUtils for DataStoreUtils.DataStore;
    using GeodeUtils for GeodeUtils.Universe;
    using StakeUtils for StakeUtils.StakePool;
    using OracleUtils for OracleUtils.Oracle;

    /**
     * @dev following events are added to help fellow devs with a better ABI
     */

    /// GeodeUtils EVENTS
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

    /// MaintainerUtils EVENTS
    event IdInitiated(uint256 id, uint256 TYPE);
    event MaintainerChanged(uint256 id, address newMaintainer);
    event MaintainerFeeSwitched(
        uint256 id,
        uint256 fee,
        uint256 effectiveTimestamp
    );

    /// OracleUtils EVENTS
    event Alienated(bytes pubkey);
    event Busted(bytes pubkey);
    event Prisoned(uint256 id, uint256 releaseTimestamp);
    event Released(uint256 id);
    event VerificationIndexUpdated(uint256 validatorVerificationIndex);

    /// StakeUtils EVENTS
    event ValidatorPeriodUpdated(uint256 operatorId, uint256 newPeriod);
    event OperatorApproval(
        uint256 planetId,
        uint256 operatorId,
        uint256 allowance
    );
    event PausedPool(uint256 id);
    event UnpausedPool(uint256 id);
    event ProposeStaked(bytes pubkey, uint256 planetId, uint256 operatorId);
    event BeaconStaked(bytes pubkey);
    event UnstakeSignal(bytes pubkey);

    // Portal Events
    event ContractVersionSet(uint256 version);
    event ParamsUpdated(
        address DEFAULT_gETH_INTERFACE,
        address DEFAULT_DWP,
        address DEFAULT_LP_TOKEN,
        uint256 MAX_MAINTAINER_FEE,
        uint256 BOOSTRAP_PERIOD,
        uint256 PERIOD_PRICE_INCREASE_LIMIT,
        uint256 PERIOD_PRICE_DECREASE_LIMIT,
        uint256 COMET_TAX,
        uint256 BOOST_SWITCH_LATENCY
    );

    // Portal VARIABLES
    /**
     * @notice always refers to the proposal (TYPE2) id.
     * Does NOT increase uniformly like the expected versioning style.
     */
    uint256 public CONTRACT_VERSION;
    DataStoreUtils.DataStore private DATASTORE;
    GeodeUtils.Universe private GEODE;
    StakeUtils.StakePool private STAKEPOOL;

    function initialize(
        address _GOVERNANCE,
        address _gETH,
        address _ORACLE_POSITION,
        address _DEFAULT_gETH_INTERFACE,
        address _DEFAULT_DWP,
        address _DEFAULT_LP_TOKEN,
        address _MINI_GOVERNANCE_POSITION,
        uint256 _GOVERNANCE_TAX,
        uint256 _COMET_TAX,
        uint256 _MAX_MAINTAINER_FEE,
        uint256 _BOOSTRAP_PERIOD
    ) public virtual override initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __ERC1155Holder_init();
        __UUPSUpgradeable_init();

        GEODE.SENATE = _GOVERNANCE;
        GEODE.GOVERNANCE = _GOVERNANCE;
        GEODE.GOVERNANCE_TAX = _GOVERNANCE_TAX;
        GEODE.MAX_GOVERNANCE_TAX = _GOVERNANCE_TAX;
        GEODE.SENATE_EXPIRY = type(uint256).max;

        STAKEPOOL.GOVERNANCE = _GOVERNANCE;
        STAKEPOOL.gETH = IgETH(_gETH);
        STAKEPOOL.TELESCOPE.gETH = IgETH(_gETH);
        STAKEPOOL.TELESCOPE.ORACLE_POSITION = _ORACLE_POSITION;
        STAKEPOOL.TELESCOPE.MONOPOLY_THRESHOLD = 20000;

        updateStakingParams(
            _DEFAULT_gETH_INTERFACE,
            _DEFAULT_DWP,
            _DEFAULT_LP_TOKEN,
            _MAX_MAINTAINER_FEE,
            _BOOSTRAP_PERIOD,
            type(uint256).max,
            type(uint256).max,
            _COMET_TAX,
            3 days
        );

        uint256 _MINI_GOVERNANCE_VERSION = GEODE.newProposal(
            _MINI_GOVERNANCE_POSITION,
            11,
            "mini-v1",
            2 days
        );
        GEODE.approveProposal(DATASTORE, _MINI_GOVERNANCE_VERSION);
        STAKEPOOL.MINI_GOVERNANCE_VERSION = _MINI_GOVERNANCE_VERSION;

        // currently only planet controllers has a say on Senate elections
        GEODE.setElectorType(DATASTORE, 5, true);
        uint256 version_id = GEODE.newProposal(
            _getImplementation(),
            2,
            "V1",
            2 days
        );
        GEODE.approveProposal(DATASTORE, version_id);
        CONTRACT_VERSION = version_id;
        GEODE.approvedUpgrade = address(0);

        emit ContractVersionSet(getVersion());
    }

    /**
     * @dev required by the OZ UUPS module
     * note that there is no Governance check, as upgrades are effective
     * * right after the Senate approval
     */
    function _authorizeUpgrade(address proposed_implementation)
        internal
        virtual
        override
    {
        require(proposed_implementation != address(0));
        require(
            GEODE.isUpgradeAllowed(proposed_implementation),
            "Portal: is not allowed to upgrade"
        );
    }

    function pause() external virtual override {
        require(
            msg.sender == GEODE.GOVERNANCE,
            "Portal: sender not GOVERNANCE"
        );
        _pause();
    }

    function unpause() external virtual override {
        require(
            msg.sender == GEODE.GOVERNANCE,
            "Portal: sender not GOVERNANCE"
        );
        _unpause();
    }

    function getVersion() public view virtual override returns (uint256) {
        return CONTRACT_VERSION;
    }

    function gETH() external view virtual override returns (address) {
        return address(STAKEPOOL.gETH);
    }

    /// @return returns an array of IDs of the given TYPE from Datastore
    function allIdsByType(uint256 _type)
        external
        view
        virtual
        override
        returns (uint256[] memory)
    {
        return DATASTORE.allIdsByType[_type];
    }

    /// @notice id is keccak(name, type)
    function getIdFromName(string calldata _name, uint256 _type)
        external
        pure
        virtual
        override
        returns (uint256 id)
    {
        id = uint256(keccak256(abi.encodePacked(_name, _type)));
    }

    /**
     *                                  ** Geode Functionalities **
     */

    function GeodeParams()
        external
        view
        virtual
        override
        returns (
            address SENATE,
            address GOVERNANCE,
            uint256 GOVERNANCE_TAX,
            uint256 MAX_GOVERNANCE_TAX,
            uint256 SENATE_EXPIRY
        )
    {
        SENATE = GEODE.getSenate();
        GOVERNANCE = GEODE.getGovernance();
        GOVERNANCE_TAX = GEODE.getGovernanceTax();
        MAX_GOVERNANCE_TAX = GEODE.getMaxGovernanceTax();
        SENATE_EXPIRY = GEODE.getSenateExpiry();
    }

    function getProposal(uint256 id)
        external
        view
        virtual
        override
        returns (GeodeUtils.Proposal memory proposal)
    {
        proposal = GEODE.getProposal(id);
    }

    function isUpgradeAllowed(address proposedImplementation)
        external
        view
        virtual
        override
        returns (bool)
    {
        return GEODE.isUpgradeAllowed(proposedImplementation);
    }

    /**
     * @notice GOVERNANCE Functions
     */

    function setGovernanceTax(uint256 newFee)
        external
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        return GEODE.setGovernanceTax(newFee);
    }

    function newProposal(
        address _CONTROLLER,
        uint256 _TYPE,
        bytes calldata _NAME,
        uint256 duration
    ) external virtual override whenNotPaused {
        require(
            msg.sender == GEODE.GOVERNANCE,
            "Portal: sender not GOVERNANCE"
        );
        GEODE.newProposal(_CONTROLLER, _TYPE, _NAME, duration);
    }

    /**
     * @notice SENATE Functions
     */

    function setMaxGovernanceTax(uint256 newMaxFee)
        external
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        return GEODE.setMaxGovernanceTax(newMaxFee);
    }

    function approveProposal(uint256 id)
        external
        virtual
        override
        whenNotPaused
    {
        GEODE.approveProposal(DATASTORE, id);
        if (DATASTORE.readUintForId(id, "TYPE") == 11)
            STAKEPOOL.setMiniGovernanceVersion(DATASTORE, id);
    }

    /**
     * @notice CONTROLLER Functions
     */

    function changeIdCONTROLLER(uint256 id, address newCONTROLLER)
        external
        virtual
        override
        whenNotPaused
    {
        GeodeUtils.changeIdCONTROLLER(DATASTORE, id, newCONTROLLER);
    }

    function approveSenate(uint256 proposalId, uint256 electorId)
        external
        virtual
        override
        whenNotPaused
        nonReentrant
    {
        GEODE.approveSenate(DATASTORE, proposalId, electorId);
    }

    /**
     *                                  ** gETH Functionalities **
     */

    function allInterfaces(uint256 id)
        external
        view
        virtual
        override
        returns (address[] memory)
    {
        return StakeUtils.allInterfaces(DATASTORE, id);
    }

    function setInterface(uint256 id, address _interface)
        external
        virtual
        override
        whenNotPaused
    {
        STAKEPOOL.setInterface(DATASTORE, id, _interface);
    }

    function unsetInterface(uint256 id, uint256 index)
        external
        virtual
        override
        whenNotPaused
    {
        STAKEPOOL.unsetInterface(DATASTORE, id, index);
    }

    /**
     *                                     ** Oracle Operations **
     */
    function TelescopeParams()
        external
        view
        virtual
        override
        returns (
            address ORACLE_POSITION,
            uint256 ORACLE_UPDATE_TIMESTAMP,
            uint256 MONOPOLY_THRESHOLD,
            uint256 VALIDATORS_INDEX,
            uint256 VERIFICATION_INDEX,
            uint256 PERIOD_PRICE_INCREASE_LIMIT,
            uint256 PERIOD_PRICE_DECREASE_LIMIT,
            bytes32 PRICE_MERKLE_ROOT
        )
    {
        ORACLE_POSITION = STAKEPOOL.TELESCOPE.ORACLE_POSITION;
        ORACLE_UPDATE_TIMESTAMP = STAKEPOOL.TELESCOPE.ORACLE_UPDATE_TIMESTAMP;
        MONOPOLY_THRESHOLD = STAKEPOOL.TELESCOPE.MONOPOLY_THRESHOLD;
        VALIDATORS_INDEX = STAKEPOOL.TELESCOPE.VALIDATORS_INDEX;
        VERIFICATION_INDEX = STAKEPOOL.TELESCOPE.VERIFICATION_INDEX;
        PERIOD_PRICE_INCREASE_LIMIT = STAKEPOOL
            .TELESCOPE
            .PERIOD_PRICE_INCREASE_LIMIT;
        PERIOD_PRICE_DECREASE_LIMIT = STAKEPOOL
            .TELESCOPE
            .PERIOD_PRICE_DECREASE_LIMIT;
        PRICE_MERKLE_ROOT = STAKEPOOL.TELESCOPE.PRICE_MERKLE_ROOT;
    }

    function getValidator(bytes calldata pubkey)
        external
        view
        virtual
        override
        returns (OracleUtils.Validator memory)
    {
        return STAKEPOOL.TELESCOPE.getValidator(pubkey);
    }

    /**
     * @notice Updating PricePerShare
     */
    function isOracleActive() external view virtual override returns (bool) {
        return STAKEPOOL.TELESCOPE._isOracleActive();
    }

    function reportOracle(
        bytes32 merkleRoot,
        uint256[] calldata beaconBalances,
        bytes32[][] calldata priceProofs
    ) external virtual override nonReentrant {
        STAKEPOOL.TELESCOPE.reportOracle(
            DATASTORE,
            merkleRoot,
            beaconBalances,
            priceProofs
        );
    }

    /**
     * @notice Batch validator verification and regulating operators
     */
    function isPrisoned(uint256 operatorId)
        external
        view
        virtual
        override
        returns (bool)
    {
        return OracleUtils.isPrisoned(DATASTORE, operatorId);
    }

    function updateVerificationIndex(
        uint256 allValidatorsCount,
        uint256 validatorVerificationIndex,
        bytes[] calldata alienatedPubkeys
    ) external virtual override {
        STAKEPOOL.TELESCOPE.updateVerificationIndex(
            DATASTORE,
            allValidatorsCount,
            validatorVerificationIndex,
            alienatedPubkeys
        );
    }

    function regulateOperators(
        bytes[] calldata bustedExits,
        bytes[] calldata bustedSignals,
        uint256[2][] calldata feeThefts
    ) external virtual override {
        STAKEPOOL.TELESCOPE.regulateOperators(
            DATASTORE,
            bustedExits,
            bustedSignals,
            feeThefts
        );
    }

    /**
     *                                       ** Staking Operations **
     */
    function StakingParams()
        external
        view
        virtual
        override
        returns (
            address DEFAULT_gETH_INTERFACE,
            address DEFAULT_DWP,
            address DEFAULT_LP_TOKEN,
            uint256 MINI_GOVERNANCE_VERSION,
            uint256 MAX_MAINTAINER_FEE,
            uint256 BOOSTRAP_PERIOD,
            uint256 COMET_TAX
        )
    {
        DEFAULT_gETH_INTERFACE = STAKEPOOL.DEFAULT_gETH_INTERFACE;
        DEFAULT_DWP = STAKEPOOL.DEFAULT_DWP;
        DEFAULT_LP_TOKEN = STAKEPOOL.DEFAULT_LP_TOKEN;
        MINI_GOVERNANCE_VERSION = STAKEPOOL.MINI_GOVERNANCE_VERSION;
        MAX_MAINTAINER_FEE = STAKEPOOL.MAX_MAINTAINER_FEE;
        BOOSTRAP_PERIOD = STAKEPOOL.BOOSTRAP_PERIOD;
        COMET_TAX = STAKEPOOL.COMET_TAX;
    }

    function getPlanet(uint256 planetId)
        external
        view
        virtual
        override
        returns (
            bytes memory name,
            address CONTROLLER,
            address maintainer,
            uint256 initiated,
            uint256 fee,
            uint256 feeSwitch,
            uint256 surplus,
            uint256 secured,
            uint256 withdrawalBoost,
            address withdrawalPool,
            address LPToken,
            address miniGovernance
        )
    {
        name = DATASTORE.readBytesForId(planetId, "NAME");
        CONTROLLER = DATASTORE.readAddressForId(planetId, "CONTROLLER");
        maintainer = DATASTORE.readAddressForId(planetId, "maintainer");
        initiated = DATASTORE.readUintForId(planetId, "initiated");
        fee = DATASTORE.getMaintainerFee(planetId);
        feeSwitch = DATASTORE.readUintForId(planetId, "feeSwitch");
        surplus = DATASTORE.readUintForId(planetId, "surplus");
        secured = DATASTORE.readUintForId(planetId, "secured");
        withdrawalBoost = DATASTORE.readUintForId(planetId, "withdrawalBoost");
        withdrawalPool = DATASTORE.readAddressForId(planetId, "withdrawalPool");
        LPToken = DATASTORE.readAddressForId(planetId, "LPToken");
        miniGovernance = DATASTORE.readAddressForId(planetId, "miniGovernance");
    }

    function getOperator(uint256 operatorId)
        external
        view
        virtual
        override
        returns (
            bytes memory name,
            address CONTROLLER,
            address maintainer,
            uint256 initiated,
            uint256 fee,
            uint256 feeSwitch,
            uint256 totalActiveValidators,
            uint256 validatorPeriod,
            uint256 released
        )
    {
        name = DATASTORE.readBytesForId(operatorId, "NAME");
        CONTROLLER = DATASTORE.readAddressForId(operatorId, "CONTROLLER");
        maintainer = DATASTORE.readAddressForId(operatorId, "maintainer");
        initiated = DATASTORE.readUintForId(operatorId, "initiated");
        fee = DATASTORE.getMaintainerFee(operatorId);
        feeSwitch = DATASTORE.readUintForId(operatorId, "feeSwitch");
        totalActiveValidators = DATASTORE.readUintForId(
            operatorId,
            "totalActiveValidators"
        );
        validatorPeriod = DATASTORE.readUintForId(
            operatorId,
            "validatorPeriod"
        );
        released = DATASTORE.readUintForId(operatorId, "released");
    }

    function miniGovernanceVersion()
        external
        view
        virtual
        override
        returns (uint256 version)
    {
        version = STAKEPOOL.MINI_GOVERNANCE_VERSION;
    }

    /**
     * @notice Governance functions on pools
     */

    /**
     * @notice updating the StakePool Params that does NOT require Senate approval
     * @dev onlyGovernance
     */
    function updateStakingParams(
        address _DEFAULT_gETH_INTERFACE,
        address _DEFAULT_DWP,
        address _DEFAULT_LP_TOKEN,
        uint256 _MAX_MAINTAINER_FEE,
        uint256 _BOOSTRAP_PERIOD,
        uint256 _PERIOD_PRICE_INCREASE_LIMIT,
        uint256 _PERIOD_PRICE_DECREASE_LIMIT,
        uint256 _COMET_TAX,
        uint256 _BOOST_SWITCH_LATENCY
    ) public virtual override {
        require(
            msg.sender == GEODE.GOVERNANCE,
            "Portal: sender not GOVERNANCE"
        );
        require(
            _DEFAULT_gETH_INTERFACE.code.length > 0,
            "Portal: DEFAULT_gETH_INTERFACE NOT contract"
        );
        require(
            _DEFAULT_DWP.code.length > 0,
            "Portal: DEFAULT_DWP NOT contract"
        );
        require(
            _DEFAULT_LP_TOKEN.code.length > 0,
            "Portal: DEFAULT_LP_TOKEN NOT contract"
        );
        require(
            _MAX_MAINTAINER_FEE > 0 &&
                _MAX_MAINTAINER_FEE <= StakeUtils.PERCENTAGE_DENOMINATOR,
            "Portal: incorrect MAX_MAINTAINER_FEE"
        );
        require(
            _PERIOD_PRICE_INCREASE_LIMIT > 0,
            "Portal: incorrect PERIOD_PRICE_INCREASE_LIMIT"
        );
        require(
            _PERIOD_PRICE_DECREASE_LIMIT > 0,
            "Portal: incorrect PERIOD_PRICE_DECREASE_LIMIT"
        );
        require(
            _COMET_TAX <= _MAX_MAINTAINER_FEE,
            "Portal: COMET_TAX should be less than MAX_MAINTAINER_FEE"
        );
        STAKEPOOL.DEFAULT_gETH_INTERFACE = _DEFAULT_gETH_INTERFACE;
        STAKEPOOL.DEFAULT_DWP = _DEFAULT_DWP;
        STAKEPOOL.DEFAULT_LP_TOKEN = _DEFAULT_LP_TOKEN;
        STAKEPOOL.MAX_MAINTAINER_FEE = _MAX_MAINTAINER_FEE;
        STAKEPOOL.COMET_TAX = _COMET_TAX;
        STAKEPOOL.BOOSTRAP_PERIOD = _BOOSTRAP_PERIOD;
        STAKEPOOL.BOOST_SWITCH_LATENCY = _BOOST_SWITCH_LATENCY;
        STAKEPOOL
            .TELESCOPE
            .PERIOD_PRICE_INCREASE_LIMIT = _PERIOD_PRICE_INCREASE_LIMIT;
        STAKEPOOL
            .TELESCOPE
            .PERIOD_PRICE_DECREASE_LIMIT = _PERIOD_PRICE_DECREASE_LIMIT;
        emit ParamsUpdated(
            _DEFAULT_gETH_INTERFACE,
            _DEFAULT_DWP,
            _DEFAULT_LP_TOKEN,
            _MAX_MAINTAINER_FEE,
            _BOOSTRAP_PERIOD,
            _PERIOD_PRICE_INCREASE_LIMIT,
            _PERIOD_PRICE_DECREASE_LIMIT,
            _COMET_TAX,
            _BOOST_SWITCH_LATENCY
        );
    }

    /**
     * @dev onlyGovernance
     */
    function releasePrisoned(uint256 operatorId) external virtual override {
        require(
            msg.sender == GEODE.GOVERNANCE,
            "Portal: sender not GOVERNANCE"
        );
        OracleUtils.releasePrisoned(DATASTORE, operatorId);
    }

    /**
     * @notice ID initiatiors for different types
     * @dev comets(private pools) are not implemented yet
     */

    function initiateOperator(
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        uint256 _validatorPeriod
    ) external virtual override whenNotPaused {
        STAKEPOOL.initiateOperator(
            DATASTORE,
            _id,
            _fee,
            _maintainer,
            _validatorPeriod
        );
    }

    function initiatePlanet(
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        string calldata _interfaceName,
        string calldata _interfaceSymbol
    ) external virtual override whenNotPaused {
        STAKEPOOL.initiatePlanet(
            DATASTORE,
            _id,
            _fee,
            _maintainer,
            [_interfaceName, _interfaceSymbol]
        );
    }

    function changeOperatorMaintainer(uint256 id, address newMaintainer)
        external
        virtual
        override
        whenNotPaused
    {
        StakeUtils.changeOperatorMaintainer(DATASTORE, id, newMaintainer);
    }

    /**
     * @notice Maintainer functions
     */

    function changePoolMaintainer(
        uint256 id,
        bytes calldata password,
        bytes32 newPasswordHash,
        address newMaintainer
    ) external virtual override whenNotPaused {
        StakeUtils.changePoolMaintainer(
            DATASTORE,
            id,
            password,
            newPasswordHash,
            newMaintainer
        );
    }

    function switchMaintainerFee(uint256 id, uint256 newFee)
        external
        virtual
        override
        whenNotPaused
    {
        STAKEPOOL.switchMaintainerFee(DATASTORE, id, newFee);
    }

    /**
     * @notice Maintainer wallet
     */

    function getMaintainerWalletBalance(uint256 id)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return DATASTORE.getMaintainerWalletBalance(id);
    }

    function increaseMaintainerWallet(uint256 id)
        external
        payable
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (bool success)
    {
        success = StakeUtils.increaseMaintainerWallet(DATASTORE, id);
    }

    function decreaseMaintainerWallet(uint256 id, uint256 value)
        external
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (bool success)
    {
        success = StakeUtils.decreaseMaintainerWallet(DATASTORE, id, value);
    }

    /**
     * @notice Pool - Operator interactions
     */

    function switchWithdrawalBoost(uint256 poolId, uint256 withdrawalBoost)
        external
        virtual
        override
        whenNotPaused
    {
        STAKEPOOL.switchWithdrawalBoost(DATASTORE, poolId, withdrawalBoost);
    }

    function operatorAllowance(uint256 poolId, uint256 operatorId)
        external
        view
        virtual
        override
        returns (
            uint256 allowance,
            uint256 proposedValidators,
            uint256 activeValidators
        )
    {
        allowance = StakeUtils.operatorAllowance(DATASTORE, poolId, operatorId);
        proposedValidators = DATASTORE.readUintForId(
            poolId,
            DataStoreUtils.getKey(operatorId, "proposedValidators")
        );
        activeValidators = DATASTORE.readUintForId(
            poolId,
            DataStoreUtils.getKey(operatorId, "activeValidators")
        );
    }

    function approveOperator(
        uint256 poolId,
        uint256 operatorId,
        uint256 allowance
    ) external virtual override whenNotPaused returns (bool) {
        return
            StakeUtils.approveOperator(
                DATASTORE,
                poolId,
                operatorId,
                allowance
            );
    }

    function updateValidatorPeriod(uint256 operatorId, uint256 newPeriod)
        external
        virtual
        override
        whenNotPaused
    {
        StakeUtils.updateValidatorPeriod(DATASTORE, operatorId, newPeriod);
    }

    /**
     * @notice Depositing functions (user)
     * @dev comets(private pools) are not implemented yet
     */

    function canDeposit(uint256 id)
        external
        view
        virtual
        override
        returns (bool)
    {
        return StakeUtils.canDeposit(DATASTORE, id);
    }

    function pauseStakingForPool(uint256 id) external virtual override {
        StakeUtils.pauseStakingForPool(DATASTORE, id);
    }

    function unpauseStakingForPool(uint256 id)
        external
        virtual
        override
        whenNotPaused
    {
        StakeUtils.unpauseStakingForPool(DATASTORE, id);
    }

    function depositPlanet(
        uint256 poolId,
        uint256 mingETH,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (uint256 gEthToSend)
    {
        gEthToSend = STAKEPOOL.depositPlanet(
            DATASTORE,
            poolId,
            mingETH,
            deadline
        );
    }

    /**
     * @notice Withdrawal functions (user)
     * @dev comets(private pools) are not implemented yet
     */

    function withdrawPlanet(
        uint256 poolId,
        uint256 gEthToWithdraw,
        uint256 minETH,
        uint256 deadline
    )
        external
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (uint256 EthToSend)
    {
        EthToSend = STAKEPOOL.withdrawPlanet(
            DATASTORE,
            poolId,
            gEthToWithdraw,
            minETH,
            deadline
        );
    }

    /**
     * @notice Validator creation (Stake) functions (operator)
     */

    function canStake(bytes calldata pubkey)
        external
        view
        virtual
        override
        returns (bool)
    {
        return STAKEPOOL.canStake(DATASTORE, pubkey);
    }

    function proposeStake(
        uint256 poolId,
        uint256 operatorId,
        bytes[] calldata pubkeys,
        bytes[] calldata signatures
    ) external virtual override whenNotPaused nonReentrant {
        STAKEPOOL.proposeStake(
            DATASTORE,
            poolId,
            operatorId,
            pubkeys,
            signatures
        );
    }

    function beaconStake(uint256 operatorId, bytes[] calldata pubkeys)
        external
        virtual
        override
        whenNotPaused
        nonReentrant
    {
        STAKEPOOL.beaconStake(DATASTORE, operatorId, pubkeys);
    }

    /**
     * @notice Validator exiting (Unstake) functions (operator)
     */

    function signalUnstake(bytes[] calldata pubkeys)
        external
        virtual
        override
        whenNotPaused
        nonReentrant
    {
        STAKEPOOL.signalUnstake(DATASTORE, pubkeys);
    }

    function fetchUnstake(
        uint256 poolId,
        uint256 operatorId,
        bytes[] calldata pubkeys,
        uint256[] calldata balances,
        bool[] calldata isExit
    ) external virtual override whenNotPaused nonReentrant {
        STAKEPOOL.fetchUnstake(
            DATASTORE,
            poolId,
            operatorId,
            pubkeys,
            balances,
            isExit
        );
    }

    /**
     * @notice We do care.
     */

    function Do_we_care() external pure returns (bool) {
        return true;
    }

    /// @notice keep the contract size at 50
    uint256[46] private __gap;
}
