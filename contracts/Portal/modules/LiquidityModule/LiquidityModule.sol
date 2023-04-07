// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// external
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
// libraries
import {LiquidityModuleLib as LML} from "./libs/LiquidityModuleLib.sol";
import {AmplificationLib as AL} from "./libs/AmplificationLib.sol";
// interfaces
import {ILiquidityModule} from "./interfaces/ILiquidityModule.sol";

/**
 * @title Liquidity Module - LM
 *
 * @author Icebear & Crash Bandicoot
 *
 * @notice A StableSwap implementation in solidity.
 * NOTE this module lacks admin checks etc: should be overriden with super.
 * NOTE all modules lack initialize: should be implemented when this module is iherited
 * NOTE all modules lack pausability state modifiers(pause/unpause): should be implemented when this module is iherited
 */
contract LiquidityModule is
  ILiquidityModule,
  ERC1155HolderUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable
{
  using LML for LML.Swap;
  using AL for LML.Swap;

  /**
   * @dev                                     ** VARIABLES **
   */
  // Struct storing data responsible for automatic market maker functionalities.
  // In order to access this data, use LiquidityModuleLibrary.
  LML.Swap internal LIQUIDITY;

  /**
   * @dev                                     ** EVENTS **
   *
   * @dev following events are added from LML to help fellow devs with a better ABI
   */
  event TokenSwap(
    address indexed buyer,
    uint256 tokensSold,
    uint256 tokensBought,
    uint128 soldId,
    uint128 boughtId
  );
  event AddLiquidity(
    address indexed provider,
    uint256[2] tokenAmounts,
    uint256[2] fees,
    uint256 invariant,
    uint256 lpTokenSupply
  );
  event RemoveLiquidity(address indexed provider, uint256[2] tokenAmounts, uint256 lpTokenSupply);
  event RemoveLiquidityOne(
    address indexed provider,
    uint256 lpTokenAmount,
    uint256 lpTokenSupply,
    uint256 boughtId,
    uint256 tokensBought
  );
  event RemoveLiquidityImbalance(
    address indexed provider,
    uint256[2] tokenAmounts,
    uint256[2] fees,
    uint256 invariant,
    uint256 lpTokenSupply
  );
  event NewAdminFee(uint256 newAdminFee);
  event NewSwapFee(uint256 newSwapFee);
  event NewWithdrawFee(uint256 newWithdrawFee);
  event RampA(uint256 oldA, uint256 newA, uint256 initialTime, uint256 futureTime);
  event StopRampA(uint256 currentA, uint256 time);

  /**
   * @dev                                     ** MODIFIERS **
   */

  /**
   * @notice Modifier to check deadline against current timestamp
   * @param deadline latest timestamp to accept this transaction
   */
  modifier deadlineCheck(uint256 deadline) {
    require(block.timestamp <= deadline, "Swap: Deadline not met");
    _;
  }

  /**
   * @dev                                     ** GETTER FUNCTIONS **
   */
  /**
   * @dev -> external view: all
   */

  /**
   * @notice Returns the internal staking token, which is ERC1155
   */
  function getERC1155() external view virtual override returns (address) {
    return address(LIQUIDITY.gETH);
  }

  /**
   * @notice Return A, the amplification coefficient * n * (n - 1)
   * @dev See the StableSwap paper for details
   * @return A parameter
   */
  function getA() external view virtual override returns (uint256) {
    return LIQUIDITY.getA();
  }

  /**
   * @notice Return A in its raw precision form
   * @dev See the StableSwap paper for details
   * @return A parameter in its raw precision form
   */
  function getAPrecise() external view virtual override returns (uint256) {
    return LIQUIDITY.getAPrecise();
  }

  /**
   * @notice Return id of the pooled token
   * @return id of the pooled gEther token
   */
  function getSwapFee() external view virtual override returns (uint256) {
    return LIQUIDITY.swapFee;
  }

  /**
   * @notice Returns the ERC1155 Id of the represented staking token
   */
  function getTokenId() external view virtual override returns (uint256) {
    return LIQUIDITY.pooledTokenId;
  }

  /**
   * @notice Return current balance of the pooled token at given index
   * @param index the index of the token
   * @return current balance of the pooled token at given index with token's native precision
   */
  function getBalance(uint8 index) external view virtual override returns (uint256) {
    return LIQUIDITY.balances[index];
  }

  /**
   * @notice Get the virtual override price, to help calculate profit
   * @return the virtual override price
   */
  function getVirtualPrice() external view virtual override returns (uint256) {
    return LIQUIDITY.getVirtualPrice();
  }

  /**
   * @notice Debt, The amount of buyback for stable pricing (1=1).
   * @return debt the half of the D StableSwap invariant when debt is needed to be payed.
   * @dev result might change when price is in.
   */
  function getDebt() external view virtual override returns (uint256) {
    return LIQUIDITY.getDebt();
  }

  /**
   * @notice Reads the accumulated amount of admin fees of the token with given index
   * @param index Index of the pooled token
   * @return admin's token balance in the token's precision
   */
  function getAdminBalance(uint256 index) external view virtual override returns (uint256) {
    return LIQUIDITY.getAdminBalance(index);
  }

  /**
   * @dev                                     ** HELPER FUNCTIONS **
   */

  /**
   * @dev -> external view: all
   */

  /**
   * @notice Calculate amount of tokens you receive on swap
   * @param tokenIndexFrom the token the user wants to sell
   * @param tokenIndexTo the token the user wants to buy
   * @param dx the amount of tokens the user wants to sell. If the token charges
   * a fee on transfers, use the amount that gets transferred after the fee.
   * @return amount of tokens the user will receive
   */
  function calculateSwap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx
  ) external view virtual override returns (uint256) {
    return LIQUIDITY.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
  }

  /**
   * @notice A simple method to calculate prices from deposits or
   * withdrawals, excluding fees but including slippage. This is
   * helpful as an input into the various "min" parameters on calls
   * to fight front-running
   *
   * @dev This shouldn't be used outside frontends for user estimates.
   *
   * @param amounts an array of token amounts to deposit or withdrawal,
   * corresponding to pooledTokens. The amount should be in each
   * pooled token's native precision. If a token charges a fee on transfers,
   * use the amount that gets transferred after the fee.
   * @param deposit whether this is a deposit or a withdrawal
   * @return token amount the user will receive
   */
  function calculateTokenAmount(
    uint256[2] calldata amounts,
    bool deposit
  ) external view virtual override returns (uint256) {
    return LIQUIDITY.calculateTokenAmount(amounts, deposit);
  }

  /**
   * @notice A simple method to calculate amount of each underlying
   * tokens that is returned upon burning given amount of LP tokens
   * @param amount the amount of LP tokens that would be burned on withdrawal
   * @return array of token balances that the user will receive
   */
  function calculateRemoveLiquidity(
    uint256 amount
  ) external view virtual override returns (uint256[2] memory) {
    return LIQUIDITY.calculateRemoveLiquidity(amount);
  }

  /**
   * @notice Calculate the amount of underlying token available to withdraw
   * when withdrawing via only single token
   * @param tokenAmount the amount of LP token to burn
   * @param tokenIndex index of which token will be withdrawn
   * @return availableTokenAmount calculated amount of underlying token
   * available to withdraw
   */
  function calculateRemoveLiquidityOneToken(
    uint256 tokenAmount,
    uint8 tokenIndex
  ) external view virtual override returns (uint256 availableTokenAmount) {
    return LIQUIDITY.calculateWithdrawOneToken(tokenAmount, tokenIndex);
  }

  /**
   * @dev                                     ** STATE MODIFYING FUNCTIONS **
   */
  /**
   * @dev -> external: all
   */

  /**
   * @notice Swap two tokens using this pool
   * @param tokenIndexFrom the token the user wants to swap from
   * @param tokenIndexTo the token the user wants to swap to
   * @param dx the amount of tokens the user wants to swap from
   * @param minDy the min amount the user would like to receive, or revert.
   * @param deadline latest timestamp to accept this transaction
   */
  function swap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline
  )
    external
    payable
    virtual
    override
    nonReentrant
    whenNotPaused
    deadlineCheck(deadline)
    returns (uint256)
  {
    return LIQUIDITY.swap(tokenIndexFrom, tokenIndexTo, dx, minDy);
  }

  /**
   * @notice Add liquidity to the pool with the given amounts of tokens
   * @param amounts the amounts of each token to add, in their native precision
   * @param minToMint the minimum LP tokens adding this amount of liquidity
   * should mint, otherwise revert. Handy for front-running mitigation
   * @param deadline latest timestamp to accept this transaction
   * @return amount of LP token user minted and received
   */
  function addLiquidity(
    uint256[2] calldata amounts,
    uint256 minToMint,
    uint256 deadline
  )
    external
    payable
    virtual
    override
    nonReentrant
    whenNotPaused
    deadlineCheck(deadline)
    returns (uint256)
  {
    return LIQUIDITY.addLiquidity(amounts, minToMint);
  }

  /**
   * @notice Burn LP tokens to remove liquidity from the pool.
   * @dev Liquidity can always be removed, even when the pool is paused.
   * @param amount the amount of LP tokens to burn
   * @param minAmounts the minimum amounts of each token in the pool
   *        acceptable for this burn. Useful as a front-running mitigation
   * @param deadline latest timestamp to accept this transaction
   * @return amounts of tokens user received
   */
  function removeLiquidity(
    uint256 amount,
    uint256[2] calldata minAmounts,
    uint256 deadline
  ) external virtual override nonReentrant deadlineCheck(deadline) returns (uint256[2] memory) {
    return LIQUIDITY.removeLiquidity(amount, minAmounts);
  }

  /**
   * @notice Remove liquidity from the pool all in one token.
   * @param tokenAmount the amount of the token you want to receive
   * @param tokenIndex the index of the token you want to receive
   * @param minAmount the minimum amount to withdraw, otherwise revert
   * @param deadline latest timestamp to accept this transaction
   * @return amount of chosen token user received
   */
  function removeLiquidityOneToken(
    uint256 tokenAmount,
    uint8 tokenIndex,
    uint256 minAmount,
    uint256 deadline
  ) external virtual override nonReentrant whenNotPaused deadlineCheck(deadline) returns (uint256) {
    return LIQUIDITY.removeLiquidityOneToken(tokenAmount, tokenIndex, minAmount);
  }

  /**
   * @notice Remove liquidity from the pool, weighted differently than the
   * pool's current balances.
   * @param amounts how much of each token to withdraw
   * @param maxBurnAmount the max LP token provider is willing to pay to
   * remove liquidity. Useful as a front-running mitigation.
   * @param deadline latest timestamp to accept this transaction
   * @return amount of LP tokens burned
   */
  function removeLiquidityImbalance(
    uint256[2] calldata amounts,
    uint256 maxBurnAmount,
    uint256 deadline
  ) external virtual override nonReentrant whenNotPaused deadlineCheck(deadline) returns (uint256) {
    return LIQUIDITY.removeLiquidityImbalance(amounts, maxBurnAmount);
  }

  /**
   * @dev                                     ** ADMIN FUNCTIONS **
   */
  /**
   * @dev -> external: all
   */
  /**
   * @notice Update the admin fee. Admin fee takes portion of the swap fee.
   * @param newAdminFee new admin fee to be applied on future transactions
   */
  function setAdminFee(uint256 newAdminFee) external virtual override {
    LIQUIDITY.setAdminFee(newAdminFee);
  }

  /**
   * @notice Update the swap fee to be applied on swaps
   * @param newSwapFee new swap fee to be applied on future transactions
   */
  function setSwapFee(uint256 newSwapFee) external virtual override {
    LIQUIDITY.setSwapFee(newSwapFee);
  }

  /**
   * @notice Start ramping up or down A parameter towards given futureA and futureTime
   * Checks if the change is too rapid, and commits the new A value only when it falls under
   * the limit range.
   * @param futureA the new A to ramp towards
   * @param futureTime timestamp when the new A should be reached
   */
  function rampA(uint256 futureA, uint256 futureTime) external virtual override {
    LIQUIDITY.rampA(futureA, futureTime);
  }

  /**
   * @notice Stop ramping A immediately. Reverts if ramp A is already stopped.
   */
  function stopRampA() external virtual override {
    LIQUIDITY.stopRampA();
  }
}
