// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {IGeodeModule} from "../modules/IGeodeModule.sol";

interface IGeodePackage is IGeodeModule {
  function initialize(
    uint256 versionId,
    uint256 poolId,
    address owner,
    bytes memory data
  ) external returns (bool);
}
