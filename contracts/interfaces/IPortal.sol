// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IGeodeModule} from "./modules/IGeodeModule.sol";
import {IStakeModule} from "./modules/IStakeModule.sol";

interface IPortal is IGeodeModule, IStakeModule {
  function pausegETH() external;

  function unpausegETH() external;

  function pushUpgrade(uint256 packageType) external returns (uint256 id);

  function releasePrisoned(uint256 operatorId) external;

  function setGovernanceFee(uint256 newFee) external;
}
