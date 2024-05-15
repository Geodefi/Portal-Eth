// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

// internal - interfaces
import {ILPToken} from "../../../interfaces/helpers/ILPToken.sol";

/**
 * @notice Helper Struct storing variables used in calculations in the
 * calculateWithdrawOneTokenDY function to avoid stack too deep errors
 */
struct CalculateWithdrawOneTokenDYInfo {
  uint256 d0;
  uint256 d1;
  uint256 newY;
  uint256 feePerToken;
  uint256 preciseA;
}

/**
 * @notice Helper Struct storing variables used in calculations in the
 * {add,remove} Liquidity functions to avoid stack too deep errors
 */
struct ManageLiquidityInfo {
  ILPToken lpToken;
  uint256 d0;
  uint256 d1;
  uint256 d2;
  uint256 preciseA;
  uint256 totalSupply;
  uint256[2] balances;
}
