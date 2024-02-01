// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @notice Giving the control of a specific ID to proposed CONTROLLER.
 *
 * @param TYPE: refer to globals/id_type.sol
 * @param CONTROLLER: the address that refers to the change that is proposed by given proposal.
 * * This slot can refer to the controller of an id, a new implementation contract, a new Senate etc.
 * @param NAME: DataStore generates ID by keccak(name, type)
 * @param deadline: refers to last timestamp until a proposal expires, limited by MAX_PROPOSAL_DURATION
 * * Expired proposals cannot be approved by Senate
 * * Expired proposals cannot be overriden by new proposals
 **/
struct Proposal {
  address CONTROLLER;
  uint256 TYPE;
  bytes NAME;
  uint256 deadline;
}
