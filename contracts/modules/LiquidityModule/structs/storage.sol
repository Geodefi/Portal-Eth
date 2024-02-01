// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// internal -interfaces
import {IgETH} from "../../../interfaces/IgETH.sol";
import {ILPToken} from "../../../interfaces/helpers/ILPToken.sol";

/**
 * @notice Storage struct for the liquidity pool logic, should be correctly initialized.
 *
 * @param gETH ERC1155 contract
 * @param lpToken address of the LP Token
 * @param pooledTokenId gETH ID of the pooled staking derivative
 * @param initialA the amplification coefficient * n * (n - 1)
 * @param futureA the amplification coef that will be effective after futureATime
 * @param initialATime variable around the ramp management of A
 * @param futureATime variable around the ramp management of A
 * @param swapFee fee as a percentage/PERCENTAGE_DENOMINATOR, will be deducted from resulting tokens of a swap
 * @param adminFee fee as a percentage/PERCENTAGE_DENOMINATOR, will be deducted from swapFee
 * @param balances the pool balance as [ETH, gETH]; the contract's actual token balance might differ
 *
 * @dev normally we would put custom:storage-location erc7201:geode.storage.LiquidityModule
 * but compiler throws an error... So np for now, just effects dev ex.
 */
struct LiquidityModuleStorage {
  IgETH gETH;
  ILPToken lpToken;
  uint256 pooledTokenId;
  uint256 initialA;
  uint256 futureA;
  uint256 initialATime;
  uint256 futureATime;
  uint256 swapFee;
  uint256 adminFee;
  uint256[2] balances;
}
