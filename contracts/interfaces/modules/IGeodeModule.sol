// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IDataStoreModule} from "./IDataStoreModule.sol";
import {Proposal} from "../../modules/GeodeModule/structs/utils.sol";

interface IGeodeModule is IDataStoreModule {
  function isolationMode() external view returns (bool);

  function GeodeParams()
    external
    view
    returns (
      address governance,
      address senate,
      address approvedUpgrade,
      uint256 senateExpiry,
      uint256 packageType
    );

  function getGovernance() external view returns (address);

  function getContractVersion() external view returns (uint256);

  function getProposal(uint256 id) external view returns (Proposal memory proposal);

  function propose(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external returns (uint256 id);

  function rescueSenate(address _newSenate) external;

  function approveProposal(
    uint256 id
  ) external returns (address _controller, uint256 _type, bytes memory _name);

  function changeSenate(address _newSenate) external;

  function changeIdCONTROLLER(uint256 id, address newCONTROLLER) external;
}
