// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// internal - structs
import {Proposal} from "./utils.sol";

/**
 * @notice Storage struct for the Dual Governance logic
 * @dev Dual Governance allows 2 parties to manage a package with proposals and approvals.
 * @param GOVERNANCE a community that works to improve the core product and ensures its adoption in the DeFi ecosystem
 * Suggests updates, such as new operators, contract/package upgrades, a new Senate (without any permission to force them)
 * @param SENATE An address that protects the users by controlling the state of governance, contract updates and other crucial changes
 * @param APPROVED_UPGRADE only 1 implementation contract SHOULD be "approved" at any given time.
 * @param SENATE_EXPIRY refers to the last timestamp that SENATE can continue operating. Might not be utilized. Limited by MAX_SENATE_PERIOD
 * @param PACKAGE_TYPE every package has a specific TYPE. Defined in globals/id_type.sol
 * @param CONTRACT_VERSION always refers to the upgrade proposal ID. Does not increase uniformly like one might expect.
 * @param proposals till approved, proposals are kept separated from the Isolated Storage
 *
 * @dev normally we would put custom:storage-location erc7201:geode.storage.GeodeModule
 * but compiler throws an error... So np for now, just effects dev ex.
 **/
struct GeodeModuleStorage {
  address GOVERNANCE;
  address SENATE;
  address APPROVED_UPGRADE;
  uint256 SENATE_EXPIRY;
  uint256 PACKAGE_TYPE;
  uint256 CONTRACT_VERSION;
  mapping(uint256 => Proposal) proposals;
}
