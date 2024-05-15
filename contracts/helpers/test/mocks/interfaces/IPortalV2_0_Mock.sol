// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;
import {IGeodeModule} from "../../../../interfaces/modules/IGeodeModule.sol";
import {IStakeModule} from "../../../../interfaces/modules/IStakeModule.sol";

interface IPortalV2_0_Mock is IStakeModule, IGeodeModule {
  function initializeV2_0_Mock(uint256 value) external;

  function setFreshSlot(uint256 value) external;

  function getFreshSlot() external view returns (uint256);

  function pausegETH() external;

  function unpausegETH() external;

  function pushUpgrade(uint256 packageType) external returns (uint256 id);

  function releasePrisoned(uint256 operatorId) external;
}
