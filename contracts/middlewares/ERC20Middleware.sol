// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;

// external - interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
// external - contracts
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
// internal - interfaces
import {IgETH} from "../interfaces/IgETH.sol";
import {IgETHMiddleware} from "../interfaces/middlewares/IgETHMiddleware.sol";
// internal - libraries
import {BytesLib} from "../helpers/BytesLib.sol";

/**
 * @notice A virtual ERC20 implementation to move underlying ERC1155 tokens.
 * @dev This contract should only be used for user interaction when ERC1155 is not an option.
 * @dev As a known bug, not all Transfer events are logged here. Please listen the underlying ERC1155 for the correct data.
 *
 * @dev ref: https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/4ca003c9635d2c16756cf8c9db6760e2d3653dee/contracts/token/ERC20/ERC20Upgradeable.sol#L1
 *
 * @dev differences between ERC20Middleware and Openzeppelin's implementation of ERC20Upgradeable is:
 * -> ERC20Middleware uses gETH contract for balances and totalsupply info.
 * -> unique id of ERC1155 is used
 * -> there is no _mint, _burn.
 * -> differences can be observed at totalSupply, balanceOf, _update.
 *
 * diffchecker: https://www.diffchecker.com/20q5E9GA/
 *
 * @dev decimals is 18 onlyif erc1155.denominator = 1e18
 *
 */
contract ERC20Middleware is
  Initializable,
  ContextUpgradeable,
  IgETHMiddleware,
  IERC20,
  IERC20Metadata,
  IERC20Errors
{
  /// @custom:storage-location erc7201:geode.storage.ERC20Middleware
  struct ERC20MiddlewareStorage {
    // mapping(address account => uint256) _balances; -> use ERC1155
    mapping(address account => mapping(address spender => uint256)) _allowances;
    // uint256 _totalSupply; -> use ERC1155
    string _name;
    string _symbol;
    IgETH ERC1155;
    uint256 ERC1155_ID;
  }

  // keccak256(abi.encode(uint256(keccak256("geode.storage.ERC20Middleware")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant ERC20MiddlewareStorageLocation =
    0xe22aaba88ea2d91ae86fe1c55e46fee2f572fef0a3fd6d1010f5764e3170a300;

  function _getERC20MiddlewareStorage() private pure returns (ERC20MiddlewareStorage storage $) {
    assembly {
      $.slot := ERC20MiddlewareStorageLocation
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    uint256 id_,
    address gETH_,
    bytes calldata data
  ) public virtual override initializer {
    uint256 nameLen = uint256(bytes32(BytesLib.slice(data, 0, 32)));
    __ERC20Middleware_init(
      id_,
      gETH_,
      string(BytesLib.slice(data, 32, nameLen)),
      string(BytesLib.slice(data, 32 + nameLen, data.length - (32 + nameLen)))
    );
  }

  /**
   * @dev Sets the values for {name} and {symbol} based on provided data:
   * * First 32 bytes indicate the lenght of the name, one therefore can find out
   * * which byte the name ends and symbol starts.
   */
  function __ERC20Middleware_init(
    uint256 id_,
    address gETH_,
    string memory name_,
    string memory symbol_
  ) internal onlyInitializing {
    __ERC20Middleware_init_unchained(id_, gETH_, name_, symbol_);
  }

  function __ERC20Middleware_init_unchained(
    uint256 id_,
    address gETH_,
    string memory name_,
    string memory symbol_
  ) internal onlyInitializing {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();
    $._name = name_;
    $._symbol = symbol_;
    $.ERC1155 = IgETH(gETH_);
    $.ERC1155_ID = id_;
  }

  function name() public view virtual returns (string memory) {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();
    return $._name;
  }

  function symbol() public view virtual returns (string memory) {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();
    return $._symbol;
  }

  function ERC1155() public view virtual override returns (address) {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();
    return address($.ERC1155);
  }

  function ERC1155_ID() public view virtual override returns (uint256) {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();
    return $.ERC1155_ID;
  }

  function pricePerShare() public view virtual override returns (uint256) {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();
    return $.ERC1155.pricePerShare($.ERC1155_ID);
  }

  function decimals() public view virtual returns (uint8) {
    return 18;
  }

  function totalSupply() public view virtual returns (uint256) {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();
    return $.ERC1155.totalSupply($.ERC1155_ID);
  }

  function balanceOf(address account) public view virtual returns (uint256) {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();
    return $.ERC1155.balanceOf(account, $.ERC1155_ID);
  }

  function transfer(address to, uint256 value) public virtual returns (bool) {
    address owner = _msgSender();
    _transfer(owner, to, value);
    return true;
  }

  function allowance(address owner, address spender) public view virtual returns (uint256) {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();
    return $._allowances[owner][spender];
  }

  function approve(address spender, uint256 value) public virtual returns (bool) {
    address owner = _msgSender();
    _approve(owner, spender, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
    address spender = _msgSender();
    _spendAllowance(from, spender, value);
    _transfer(from, to, value);
    return true;
  }

  function _transfer(address from, address to, uint256 value) internal {
    if (from == address(0)) {
      revert ERC20InvalidSender(address(0));
    }
    if (to == address(0)) {
      revert ERC20InvalidReceiver(address(0));
    }
    _update(from, to, value);
  }

  function _update(address from, address to, uint256 value) internal virtual {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();

    uint256 fromBalance = balanceOf(from);
    if (fromBalance < value) {
      revert ERC20InsufficientBalance(from, fromBalance, value);
    }

    $.ERC1155.safeTransferFrom(from, to, $.ERC1155_ID, value, "");

    emit Transfer(from, to, value);
  }

  function _approve(address owner, address spender, uint256 value) internal {
    _approve(owner, spender, value, true);
  }

  function _approve(
    address owner,
    address spender,
    uint256 value,
    bool emitEvent
  ) internal virtual {
    ERC20MiddlewareStorage storage $ = _getERC20MiddlewareStorage();
    if (owner == address(0)) {
      revert ERC20InvalidApprover(address(0));
    }
    if (spender == address(0)) {
      revert ERC20InvalidSpender(address(0));
    }
    $._allowances[owner][spender] = value;
    if (emitEvent) {
      emit Approval(owner, spender, value);
    }
  }

  function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
    uint256 currentAllowance = allowance(owner, spender);
    if (currentAllowance != type(uint256).max) {
      if (currentAllowance < value) {
        revert ERC20InsufficientAllowance(spender, currentAllowance, value);
      }
      unchecked {
        _approve(owner, spender, currentAllowance - value, false);
      }
    }
  }
}
