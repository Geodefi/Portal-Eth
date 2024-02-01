// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// Created with https://wizard.openzeppelin.com/#erc20

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @title Liquidity Provider Token
 * @notice This token is an ERC20 detailed token with added capability to be minted by the owner.
 * It is used to represent user shares when providing liquidity to LPP.
 * @dev Only LPP contracts should initialize and own LPToken contracts.
 */
contract LPToken is
  Initializable,
  ERC20Upgradeable,
  ERC20BurnableUpgradeable,
  OwnableUpgradeable,
  ERC20PermitUpgradeable
{
  error LPTokenZeroMint();

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Initializes this LPToken contract with the given name and symbol
   * @dev The caller of this function will become the owner. A Swap contract should call this
   * in its initializer function.
   * @param name name of this token
   * @param symbol symbol of this token
   */
  function initialize(string memory name, string memory symbol) external initializer {
    __ERC20_init_unchained(name, symbol);
    __ERC20Burnable_init();
    __Ownable_init_unchained(msg.sender);
  }

  /**
   * @notice Mints the given amount of LPToken to the recipient.
   * @dev only owner can call this mint function
   * @param to address of account to receive the tokens
   * @param amount amount of tokens to mint
   */
  function mint(address to, uint256 amount) external onlyOwner {
    if (amount == 0) {
      revert LPTokenZeroMint();
    }

    _mint(to, amount);
  }

  /**
   * @dev Overrides ERC20._update() which get called on every transfers including
   * minting and burning. This ensures that Swap.updateUserWithdrawFees are called everytime.
   * This assumes the owner is set to a Swap contract's address.
   */
  function _update(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20Upgradeable) {
    if (to == address(this)) {
      revert ERC20InvalidReceiver(address(this));
    }

    super._update(from, to, amount);
  }
}
