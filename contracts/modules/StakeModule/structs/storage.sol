// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

// internal - interfaces
import {IgETH} from "../../../interfaces/IgETH.sol";
// internal - structs
import {Validator} from "./utils.sol";

/**
 * @notice Storage struct for the Pooled Liquid Staking logic
 * todo: ask if that would be a problem if the interface changes??? like should you update the param too?? Then check other params with IPortal IgETH etc.
 * @param gETH constant, ERC1155, all Geode Staking Derivatives.
 * @param ORACLE_POSITION constant, address of the Oracle https://github.com/Geodefi/Telescope-Eth
 * @param VALIDATORS_INDEX total number of validators that are proposed at any given point.
 * * Includes all validators: proposed, active, alienated, exited.
 * @param VERIFICATION_INDEX the highest index of the validators that are verified (as not alien) by the Holy Oracle.
 * @param MONOPOLY_THRESHOLD max number of validators 1 operator is allowed to operate, updated by the Holy Oracle.
 * @param ORACLE_UPDATE_TIMESTAMP timestamp of the latest oracle update
 * @param DAILY_PRICE_DECREASE_LIMIT limiting the price decreases for one oracle period, 24h. Effective for any time interval, per second.
 * @param DAILY_PRICE_INCREASE_LIMIT limiting the price increases for one oracle period, 24h. Effective for any time interval, per second.
 * @param PRICE_MERKLE_ROOT merkle root of the prices of every pool, updated by the Holy Oracle.
 * @param GOVERNANCE_FEE **reserved** Although it is 0 right now, It can be updated in the future.
 * @param BALANCE_MERKLE_ROOT merkle root of the balances and other validator related data, useful on withdrawals, updated by the Holy Oracle.
 * @param validators pubkey => Validator, contains all the data about proposed, alienated, active, exit-called and fully exited validators.
 * @param packages TYPE => version id, pointing to the latest versions of the given package.
 * * Like default Withdrawal Contract version.
 * @param middlewares TYPE => version id => isAllowed, useful to check if given version of the middleware can be used.
 * * Like all the whitelisted gETHMiddlewares.
 * @param __gap keep the struct size at 16
 **/
struct PooledStaking {
  IgETH gETH;
  address ORACLE_POSITION;
  uint256 VALIDATORS_INDEX;
  uint256 VERIFICATION_INDEX;
  uint256 MONOPOLY_THRESHOLD;
  uint256 ORACLE_UPDATE_TIMESTAMP;
  uint256 DAILY_PRICE_INCREASE_LIMIT;
  uint256 DAILY_PRICE_DECREASE_LIMIT;
  uint256 GOVERNANCE_FEE;
  bytes32 PRICE_MERKLE_ROOT;
  bytes32 BALANCE_MERKLE_ROOT;
  mapping(bytes => Validator) validators;
  mapping(uint256 => uint256) packages;
  mapping(uint256 => mapping(uint256 => bool)) middlewares;
  uint256[2] __gap;
}
