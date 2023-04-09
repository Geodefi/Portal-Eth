// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IGeodePackage {
  function initialize(
    uint256 pooledTokenId,
    address poolOwner,
    bytes memory data
  ) external returns (bool);
}
