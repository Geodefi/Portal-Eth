// SPDX-License-Identifier: MIT

pragma solidity =0.8.7;

import {IPortal} from "./IPortal.sol";
import {ILiquidityModule} from "../modules/LiquidityModule/interfaces/ILiquidityModule.sol";
import {IGeodePackage} from "../packages/interfaces/IGeodePackage.sol";

interface ILiquidityPool is ILiquidityModule, IGeodePackage {
  function initialize(
    uint256 pooledTokenId,
    address poolOwner,
    bytes memory versionName,
    bytes memory data
  ) public returns (bool success);

  function getPoolId() public view returns (uint256);

  function getPortal() public view returns (IPortal);

  function getProposedVersion() public view returns (uint256);

  function pause() external;

  function unpause() external;
}
