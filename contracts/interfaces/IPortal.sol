// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../Portal/utils/GeodeUtilsLib.sol";
import "../Portal/utils/OracleUtilsLib.sol";

interface IPortal {
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
    ) external;

    function pause() external;

    function unpause() external;

    function getVersion() external view returns (uint256);

    function gETH() external view returns (address);

    function allIdsByType(uint256 _type)
        external
        view
        returns (uint256[] memory);

    function getIdFromName(string calldata _name, uint256 _type)
        external
        pure
        returns (uint256 id);

    function GeodeParams()
        external
        view
        returns (
            address SENATE,
            address GOVERNANCE,
            uint256 GOVERNANCE_TAX,
            uint256 MAX_GOVERNANCE_TAX,
            uint256 SENATE_EXPIRY
        );

    function getProposal(uint256 id)
        external
        view
        returns (GeodeUtils.Proposal memory proposal);

    function isUpgradeAllowed(address proposedImplementation)
        external
        view
        returns (bool);

    function setGovernanceTax(uint256 newFee) external returns (bool);

    function newProposal(
        address _CONTROLLER,
        uint256 _TYPE,
        bytes calldata _NAME,
        uint256 duration
    ) external;

    function setMaxGovernanceTax(uint256 newMaxFee) external returns (bool);

    function approveProposal(uint256 id) external;

    function changeIdCONTROLLER(uint256 id, address newCONTROLLER) external;

    function approveSenate(uint256 proposalId, uint256 electorId) external;

    function allInterfaces(uint256 id) external view returns (address[] memory);

    function setInterface(uint256 id, address _interface) external;

    function unsetInterface(uint256 id, uint256 index) external;

    function TelescopeParams()
        external
        view
        returns (
            address ORACLE_POSITION,
            uint256 ORACLE_UPDATE_TIMESTAMP,
            uint256 MONOPOLY_THRESHOLD,
            uint256 VALIDATORS_INDEX,
            uint256 VERIFICATION_INDEX,
            uint256 PERIOD_PRICE_INCREASE_LIMIT,
            uint256 PERIOD_PRICE_DECREASE_LIMIT,
            bytes32 PRICE_MERKLE_ROOT
        );

    function releasePrisoned(uint256 operatorId) external;

    function miniGovernanceVersion() external view returns (uint256 id);

    function getValidator(bytes calldata pubkey)
        external
        view
        returns (OracleUtils.Validator memory);

    function isOracleActive() external view returns (bool);

    function reportOracle(
        bytes32 merkleRoot,
        uint256[] calldata beaconBalances,
        bytes32[][] calldata priceProofs
    ) external;

    function isPrisoned(uint256 operatorId) external view returns (bool);

    function getPlanet(uint256 planetId)
        external
        view
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
        );

    function getOperator(uint256 operatorId)
        external
        view
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
        );

    function regulateOperators(
        uint256 allValidatorsCount,
        uint256 validatorVerificationIndex,
        bytes[2][] calldata regulatedPubkeys
    ) external;

    function StakingParams()
        external
        view
        returns (
            address DEFAULT_gETH_INTERFACE,
            address DEFAULT_DWP,
            address DEFAULT_LP_TOKEN,
            uint256 MINI_GOVERNANCE_VERSION,
            uint256 MAX_MAINTAINER_FEE,
            uint256 BOOSTRAP_PERIOD,
            uint256 COMET_TAX
        );

    function updateStakingParams(
        address _DEFAULT_gETH_INTERFACE,
        address _DEFAULT_DWP,
        address _DEFAULT_LP_TOKEN,
        uint256 _MAX_MAINTAINER_FEE,
        uint256 _BOOSTRAP_PERIOD,
        uint256 _PERIOD_PRICE_INCREASE_LIMIT,
        uint256 _PERIOD_PRICE_DECREASE_LIMIT,
        uint256 _COMET_TAX
    ) external;

    function initiateOperator(
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        uint256 _validatorPeriod
    ) external;

    function initiatePlanet(
        uint256 _id,
        uint256 _fee,
        uint256 _withdrawalBoost,
        address _maintainer,
        string calldata _interfaceName,
        string calldata _interfaceSymbol
    ) external;

    function changeOperatorMaintainer(uint256 id, address newMaintainer)
        external;

    function changePoolMaintainer(
        uint256 id,
        bytes calldata password,
        bytes32 newPasswordHash,
        address newMaintainer
    ) external;

    function getMaintainerWalletBalance(uint256 id)
        external
        view
        returns (uint256);

    function switchMaintainerFee(uint256 id, uint256 newFee) external;

    function increaseMaintainerWallet(uint256 id)
        external
        payable
        returns (bool success);

    function decreaseMaintainerWallet(uint256 id, uint256 value)
        external
        returns (bool success);

    function setWithdrawalBoost(uint256 poolId, uint256 withdrawalBoost)
        external;

    function operatorAllowance(uint256 poolId, uint256 operatorId)
        external
        view
        returns (
            uint256 allowance,
            uint256 proposedValidators,
            uint256 activeValidators
        );

    function approveOperator(
        uint256 poolId,
        uint256 operatorId,
        uint256 allowance
    ) external returns (bool);

    function updateValidatorPeriod(uint256 operatorId, uint256 newPeriod)
        external;

    function canDeposit(uint256 _id) external view returns (bool);

    function canStake(bytes calldata pubkey) external view returns (bool);

    function pauseStakingForPool(uint256 id) external;

    function unpauseStakingForPool(uint256 id) external;

    function depositPlanet(
        uint256 poolId,
        uint256 mingETH,
        uint256 deadline
    ) external payable returns (uint256 gEthToSend);

    function withdrawPlanet(
        uint256 poolId,
        uint256 gEthToWithdraw,
        uint256 minETH,
        uint256 deadline
    ) external returns (uint256 EthToSend);

    function proposeStake(
        uint256 poolId,
        uint256 operatorId,
        bytes[] calldata pubkeys,
        bytes[] calldata signatures
    ) external;

    function beaconStake(uint256 operatorId, bytes[] calldata pubkeys) external;

    function signalUnstake(bytes[] calldata pubkeys) external;

    function fetchUnstake(
        bytes calldata pk,
        uint256 balance,
        bool isExit
    ) external returns (uint256 tax);
}
