// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

// external
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable, ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

/**
 * @title Liquidity Provider Token
 * @notice This token is an ERC20 detailed token with added capability to be minted by the owner.
 * It is used to represent user shares when providing liquidity to LPP.
 * @dev Only LPP contracts should initialize and own LPToken contracts.
 */
contract LPToken is ERC20BurnableUpgradeable, OwnableUpgradeable {
  ///@custom:oz-upgrades-unsafe-allow constructor
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
    __Context_init_unchained();
    __ERC20_init_unchained(name, symbol);
    __ERC20Burnable_init_unchained();
    __Ownable_init_unchained();
  }

  /**
   * @notice Mints the given amount of LPToken to the recipient.
   * @dev only owner can call this mint function
   * @param recipient address of account to receive the tokens
   * @param amount amount of tokens to mint
   */
  function mint(address recipient, uint256 amount) external onlyOwner {
    require(amount != 0, "LPToken: cannot mint 0");
    _mint(recipient, amount);
  }

  /**
   * @dev Overrides ERC20._beforeTokenTransfer() which get called on every transfers including
   * minting and burning. This ensures that Swap.updateUserWithdrawFees are called everytime.
   * This assumes the owner is set to a Swap contract's address.
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20Upgradeable) {
    require(to != address(this), "LPToken: cannot send to itself");
    super._beforeTokenTransfer(from, to, amount);
  }
}
