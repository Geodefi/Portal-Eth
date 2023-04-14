// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {IDataStoreModule} from "./IDataStoreModule.sol";
import {GeodeModuleLib as GML} from "../../modules/GeodeModule/libs/GeodeModuleLib.sol";

interface IGeodeModule is IDataStoreModule {
  function getContractVersion() external view returns (uint256);

  function getProposedVersion() external view returns (uint256);

  function isUpgradeAllowed(address proposedImplementation) external view returns (bool);

  function isolationMode() external view returns (bool);

  function pullUpgrade() external;

  function GeodeParams()
    external
    view
    returns (
      address governance,
      address senate,
      address approvedUpgrade,
      uint256 governanceFee,
      uint256 senateExpiry,
      uint256 contractVersion
    );

  function getProposal(uint256 id) external view returns (GML.Proposal memory proposal);

  function setGovernanceFee(uint256 newFee) external;

  function propose(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external returns (uint256 id, bool success);

  function approveProposal(uint256 id) external returns (uint256 _type, address _controller);

  function changeSenate(address _newSenate) external;

  function rescueSenate(address _newSenate) external;

  function changeIdCONTROLLER(uint256 id, address newCONTROLLER) external;
}
