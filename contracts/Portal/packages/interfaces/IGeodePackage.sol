// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {IGeodeModule} from "../../modules/GeodeModule/interfaces/IGeodeModule.sol";

interface IGeodePackage is IGeodeModule {
  function initialize(
    uint256 pooledTokenId,
    address poolOwner,
    bytes memory versionName,
    bytes memory data
  ) external returns (bool);
}
