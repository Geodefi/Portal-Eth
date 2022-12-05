// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../Portal/utils/GeodeUtilsLib.sol";

interface IMiniGovernance {
    function initialize(
        address _gETH,
        address _PORTAL,
        address _MAINTAINER,
        uint256 _ID,
        uint256 _VERSION
    ) external;

    function pause() external;

    function unpause() external;

    function getCurrentVersion() external view returns (uint256);

    function getProposedVersion() external view returns (uint256);

    function isolationMode() external view returns (bool);

    function fetchUpgradeProposal() external;

    function approveProposal(uint256 _id) external;

    function setSenate(address newController) external;

    function claimUnstake(uint256 claim) external returns (bool success);
}
