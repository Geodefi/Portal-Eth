// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;
import {IGeodeModule} from "../../../../interfaces/modules/IGeodeModule.sol";
import {IStakeModule} from "../../../../interfaces/modules/IStakeModule.sol";
import {IFreshSlotModule} from "./IFreshSlotModule.sol";

interface IPortalV4_0_Mock is IStakeModule, IGeodeModule, IFreshSlotModule {
  function initializeV4_0_Mock(uint256 value) external;

  function pausegETH() external;

  function unpausegETH() external;

  function pushUpgrade(uint256 packageType) external returns (uint256 id);

  function releasePrisoned(uint256 operatorId) external;

  function setGovernanceFee(uint256 newFee) external;
}
