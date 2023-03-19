// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IGeodeModule {
  function newProposal(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external returns (uint256 id, bool success);

  function approveProposal(uint256 id) external returns (uint256 _type, address _controller);

  function isUpgradeAllowed(address proposedImplementation) external view returns (bool);
}
