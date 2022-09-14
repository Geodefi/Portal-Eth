// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../Portal/utils/GeodeUtilsLib.sol";

interface IMiniGovernance {
    function initialize(
        address _gETH,
        uint256 _ID,
        address _PORTAL,
        uint256 _VERSION,
        address _MAINTAINER
    ) external;

    function pause() external;

    function unpause() external;

    function getCurrentVersion() external view returns (uint256);

    function getProposedVersion() external view returns (uint256);

    function isolationMode() external view returns (bool);

    function fetchUpgradeProposal() external;

    function approveProposal(uint256 _id) external;

    function refreshSenate(bytes32 newPassword) external;

    function changeMaintainer(
        bytes calldata password,
        bytes32 newPasswordHash,
        address newMaintainer
    ) external returns (bool success);

    function claimUnstake(uint256 claim) external returns (bool success);
}
