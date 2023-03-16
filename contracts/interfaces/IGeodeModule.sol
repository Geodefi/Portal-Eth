// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IGeodeModule {
  function newProposal(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external;
}
