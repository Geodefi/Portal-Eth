// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import {GeodeModuleLib as GML} from "../libs/GeodeModuleLib.sol";

interface IGeodeModule {
  function getContractVersion() external view returns (uint256);

  function getProposedVersion() external view returns (uint256);

  function isolationMode() external view returns (bool isolated);

  function GeodeParams()
    external
    view
    returns (address senate, address governance, uint256 senate_expiry, uint256 governance_fee);

  function getProposal(uint256 id) external view returns (GML.Proposal memory proposal);

  function isUpgradeAllowed(address proposedImplementation) external view returns (bool);

  function setGovernanceFee(uint256 newFee) external;

  function newProposal(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external returns (uint256 id, bool success);

  function approveProposal(uint256 id) external returns (uint256 _type, address _controller);

  function changeSenate(address _newSenate) external;

  function rescueSenate(address _newSenate) external;

  function changeIdCONTROLLER(uint256 id, address newCONTROLLER) external;

  function pullUpgrade() external;
}
