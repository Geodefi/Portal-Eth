// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import {IGeodeModule} from "./packages/IGeodePackage.sol";
import {IStakeModule} from "./modules/IStakeModule.sol";

interface IPortal is IStakeModule, IGeodeModule {
  function pause() external;

  function unpause() external;

  function pausegETH() external;

  function unpausegETH() external;

  function pushUpgrade(uint256 moduleType) external returns (uint256 moduleVersion);

  function releasePrisoned(uint256 operatorId) external;

  function Do_we_care() external pure returns (bool);
}
