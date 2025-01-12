// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

// internal - interfaces
import {IgETH} from "../../../interfaces/IgETH.sol";
// internal - structs
import {Queue, Request, ValidatorData} from "./utils.sol";

/**
 * @notice Storage struct for the Withdrawal Package enabling the Queued Withdrawal Requests with instant run-off validator exit elections
 * @param gETH constant, ERC1155, all Geode Staking Derivatives.
 * @param PORTAL constant, address of the PORTAL.
 * @param POOL_ID constant, ID of the pool, also the token ID of represented gETH.
 * @param EXIT_THRESHOLD variable, current exit threshold that is set by the owner.
 * @param queue main variables related to Enqueue-Dequeue operations.
 * @param requests an array of requests
 * @param validators as pubkey being the key, the related data for the validators of the given pool. Updated on processValidators.
 *
 * @dev normally we would put custom:storage-location erc7201:geode.storage.StakeModule
 * but compiler throws an error... So np for now, just effects dev ex.
 **/
struct WithdrawalModuleStorage {
  IgETH gETH;
  address PORTAL;
  uint256 POOL_ID;
  uint256 EXIT_THRESHOLD;
  uint256 gatheredInfrastructureFees;
  Queue queue;
  Request[] requests;
  mapping(bytes => ValidatorData) validators;
}
