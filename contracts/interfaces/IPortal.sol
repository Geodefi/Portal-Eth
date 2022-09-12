// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../Portal/utils/GeodeUtilsLib.sol";

interface IPortal {
    function getProposal(uint256 id)
        external
        returns (GeodeUtils.Proposal memory);

    // returns 1 in the beginning
    function miniGovernanceVersion() external view returns (uint256 id);
}
