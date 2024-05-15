// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC20Permit.sol)

pragma solidity ^0.8.20;

// external - interfaces
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
// external - libraries
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// external - contracts
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
// internal - libraries
import {BytesLib} from "../helpers/BytesLib.sol";
// internal - contracts
import {ERC20RebaseMiddleware} from "./ERC20RebaseMiddleware.sol";

/**
 * @dev differences between ERC20RebasePermitMiddleware and Openzeppelin's implementation of ERC20PermitUpgradable is:
 * -> using ERC20Middleware instead of ERC20Upgradeable
 * -> added initialize
 *
 * @dev Implementation of the ERC-20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[ERC-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC-20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
contract ERC20RebasePermitMiddleware is
  ERC20RebaseMiddleware,
  IERC20Permit,
  EIP712Upgradeable,
  NoncesUpgradeable
{
  bytes32 private constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  /**
   * @dev Permit deadline has expired.
   */
  error ERC2612ExpiredSignature(uint256 deadline);

  /**
   * @dev Mismatched signature.
   */
  error ERC2612InvalidSigner(address signer, address owner);

  ///@custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Sets the values for {name} and {symbol}.
   */
  function initialize(
    uint256 id_,
    address gETH_,
    bytes calldata data
  ) public virtual override initializer {
    uint256 nameLen = uint256(bytes32(BytesLib.slice(data, 0, 32)));
    __ERC20RebasePermitMiddleware_init(
      id_,
      gETH_,
      string(BytesLib.slice(data, 32, nameLen)),
      string(BytesLib.slice(data, 32 + nameLen, data.length - (32 + nameLen)))
    );
  }

  /**
   * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
   *
   * It's a good idea to use the same `name` that is defined as the ERC20 token name.
   */
  function __ERC20RebasePermitMiddleware_init(
    uint256 id_,
    address gETH_,
    string memory name_,
    string memory symbol_
  ) internal onlyInitializing {
    __EIP712_init_unchained(name_, "1");
    __ERC20RebaseMiddleware_init_unchained(id_, gETH_, name_, symbol_);
    __ERC20RebasePermitMiddleware_init_unchained();
  }

  function __ERC20RebasePermitMiddleware_init_unchained() internal onlyInitializing {}

  /**
   * @inheritdoc IERC20Permit
   */
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public virtual {
    if (block.timestamp > deadline) {
      revert ERC2612ExpiredSignature(deadline);
    }

    bytes32 structHash = keccak256(
      abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline)
    );

    bytes32 hash = _hashTypedDataV4(structHash);

    address signer = ECDSA.recover(hash, v, r, s);
    if (signer != owner) {
      revert ERC2612InvalidSigner(signer, owner);
    }

    _approve(owner, spender, value);
  }

  /**
   * @inheritdoc IERC20Permit
   */
  function nonces(
    address owner
  ) public view virtual override(IERC20Permit, NoncesUpgradeable) returns (uint256) {
    return super.nonces(owner);
  }

  /**
   * @inheritdoc IERC20Permit
   */
  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
    return _domainSeparatorV4();
  }
}
