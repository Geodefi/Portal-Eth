// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {IgETH} from "../IgETH.sol";
import {IPortal} from "../IPortal.sol";

interface IWithdrawalContract {
  function initialize(
    uint256 _ID,
    address _gETH,
    address _PORTAL,
    address _CONTROLLER,
    bytes memory _versionName
  ) external returns (bool);

  function getgETH() external view returns (IgETH);

  function getPortal() external view returns (IPortal);

  function getPoolId() external view returns (uint256);

  function getContractVersion() external view returns (uint256);

  function getProposedVersion() external view returns (uint256);

  function isolationMode() external view returns (bool);

  function isUpgradeAllowed(address proposedImplementation) external view returns (bool);

  function newProposal(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external returns (uint256 id, bool success);

  function approveProposal(uint256 id) external returns (uint256 _type, address _controller);

  function fetchUpgradeProposal() external;

  function changeController(address _newSenate) external;
}
