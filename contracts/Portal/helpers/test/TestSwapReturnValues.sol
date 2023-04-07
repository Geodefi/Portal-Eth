// SPDX-License-Identifier: MIT

pragma solidity =0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "../../../../interfaces/ISwap.sol";

import "hardhat/console.sol";

contract TestSwapReturnValues is ERC1155Holder {
  ISwap public swap;
  IERC1155 public gETH;
  IERC20 public lpToken;
  uint8 public n;

  uint256 public constant MAX_INT = 2 ** 256 - 1;

  constructor(
    ISwap swapContract,
    IERC1155 gETHReference,
    IERC20 lpTokenContract,
    uint8 numOfTokens
  ) {
    swap = swapContract;
    gETH = gETHReference;
    lpToken = lpTokenContract;
    n = numOfTokens;

    // Pre-approve tokens
    gETH.setApprovalForAll(address(swap), true);
    lpToken.approve(address(swap), MAX_INT);
  }

  function test_swap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy
  ) public payable {
    uint256 etherbalanceBefore = address(this).balance;
    uint256 getherbalanceBefore = gETH.balanceOf(address(this), swap.getToken());

    if (tokenIndexFrom == 0) {
      // If ether to gether
      uint256 returnValue = swap.swap{value: msg.value}(
        tokenIndexFrom,
        tokenIndexTo,
        dx,
        minDy,
        block.timestamp
      );

      uint256 getherbalanceAfter = gETH.balanceOf(address(this), swap.getToken());

      require(
        returnValue == getherbalanceAfter - getherbalanceBefore,
        "swap()'s return value does not match received gether amount"
      );
    } else {
      uint256 returnValue = swap.swap(tokenIndexFrom, tokenIndexTo, dx, minDy, block.timestamp);
      uint256 etherbalanceAfter = address(this).balance;

      require(
        returnValue == etherbalanceAfter - etherbalanceBefore,
        "swap()'s return value does not match received ether amount"
      );
    }
  }

  function test_addLiquidity(uint256[2] calldata amounts, uint256 minToMint) public payable {
    require(msg.value == amounts[0], "The update of about ETH amount -0xCypher");
    uint256 balanceBefore = lpToken.balanceOf(address(this));
    uint256 returnValue = swap.addLiquidity{value: msg.value}(amounts, minToMint, MAX_INT);
    uint256 balanceAfter = lpToken.balanceOf(address(this));

    console.log("addLiquidity: Expected %s, got %s", balanceAfter - balanceBefore, returnValue);

    require(
      returnValue == balanceAfter - balanceBefore,
      "addLiquidity()'s return value does not match minted amount"
    );
  }

  function test_removeLiquidity(uint256 amount, uint256[2] memory minAmounts) public {
    uint256[] memory balanceBefore = new uint256[](n);
    uint256[] memory balanceAfter = new uint256[](n);

    balanceBefore[0] = address(this).balance;
    balanceBefore[1] = gETH.balanceOf(address(this), swap.getToken());

    uint256[2] memory returnValue = swap.removeLiquidity(amount, minAmounts, MAX_INT);
    balanceAfter[0] = address(this).balance;
    balanceAfter[1] = gETH.balanceOf(address(this), swap.getToken());

    for (uint8 i = 0; i < n; ++i) {
      console.log(
        "removeLiquidity: Expected %s, got %s",
        balanceAfter[i] - balanceBefore[i],
        returnValue[i]
      );
      require(
        balanceAfter[i] - balanceBefore[i] == returnValue[i],
        "removeLiquidity()'s return value does not match received amounts of tokens"
      );
    }
  }

  function test_removeLiquidityImbalance(
    uint256[2] calldata amounts,
    uint256 maxBurnAmount
  ) public {
    uint256 balanceBefore = lpToken.balanceOf(address(this));
    uint256 returnValue = swap.removeLiquidityImbalance(amounts, maxBurnAmount, MAX_INT);
    uint256 balanceAfter = lpToken.balanceOf(address(this));

    console.log(
      "removeLiquidityImbalance: Expected %s, got %s",
      balanceBefore - balanceAfter,
      returnValue
    );

    require(
      returnValue == balanceBefore - balanceAfter,
      "removeLiquidityImbalance()'s return value does not match burned lpToken amount"
    );
  }

  function test_removeLiquidityOneToken(
    uint256 tokenAmount,
    uint8 tokenIndex,
    uint256 minAmount
  ) public {
    uint256 balanceBefore;
    if (tokenIndex == 0) {
      balanceBefore = address(this).balance;
    } else {
      balanceBefore = gETH.balanceOf(address(this), swap.getToken());
    }
    uint256 returnValue = swap.removeLiquidityOneToken(tokenAmount, tokenIndex, minAmount, MAX_INT);

    uint256 balanceAfter;
    if (tokenIndex == 0) {
      balanceAfter = address(this).balance;
    } else {
      balanceAfter = gETH.balanceOf(address(this), swap.getToken());
    }
    console.log(
      "removeLiquidityOneToken: Expected %s, got %s",
      balanceAfter - balanceBefore,
      returnValue
    );

    require(
      returnValue == balanceAfter - balanceBefore,
      "removeLiquidityOneToken()'s return value does not match received token amount"
    );
  }

  receive() external payable {}
}
