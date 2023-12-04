// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;
import {IGeodeModuleV3_0_Mock} from "./IGeodeModuleV3_0_Mock.sol";
import {IStakeModule} from "../../../../interfaces/modules/IStakeModule.sol";

interface IPortalV3_0_Mock is IStakeModule, IGeodeModuleV3_0_Mock {
  function initializeV3_0_Mock(uint256 value) external;

  function pausegETH() external;

  function unpausegETH() external;

  function pushUpgrade(uint256 packageType) external returns (uint256 id);

  function releasePrisoned(uint256 operatorId) external;

  function setGovernanceFee(uint256 newFee) external;
}
