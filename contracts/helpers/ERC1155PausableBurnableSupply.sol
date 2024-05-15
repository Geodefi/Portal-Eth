// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/ERC1155.sol)

// External
// Dependencies: ERC1155
//  * interfaces
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
//  * libraries
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";
//  * contracts
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// Dependencies: ERC1155Pausable
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

// Dependencies: ERC1155PausableBurnableSupply
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// Internal - interfaces
import {IERC1155Burnable, IERC1155Supply, IERC1155PausableBurnableSupply} from "../interfaces/helpers/IERC1155PausableBurnableSupply.sol";

abstract contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI, IERC1155Errors {
  using Arrays for uint256[];
  using Arrays for address[];

  mapping(uint256 id => mapping(address account => uint256)) private _balances;

  mapping(address account => mapping(address operator => bool)) private _operatorApprovals;

  // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
  string private _uri;

  /**
   * @dev See {_setURI}.
   */
  constructor(string memory uri_) {
    _setURI(uri_);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override(ERC165, IERC165) returns (bool) {
    return
      interfaceId == type(IERC1155).interfaceId ||
      interfaceId == type(IERC1155MetadataURI).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  /**
   * @dev See {IERC1155MetadataURI-uri}.
   *
   * This implementation returns the same URI for *all* token types. It relies
   * on the token type ID substitution mechanism
   * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
   *
   * Clients calling this function must replace the `\{id\}` substring with the
   * actual token type ID.
   */
  function uri(uint256 /* id */) public view virtual returns (string memory) {
    return _uri;
  }

  /**
   * @dev See {IERC1155-balanceOf}.
   */
  function balanceOf(address account, uint256 id) public view virtual returns (uint256) {
    return _balances[id][account];
  }

  /**
   * @dev See {IERC1155-balanceOfBatch}.
   *
   * Requirements:
   *
   * - `accounts` and `ids` must have the same length.
   */
  function balanceOfBatch(
    address[] memory accounts,
    uint256[] memory ids
  ) public view virtual returns (uint256[] memory) {
    if (accounts.length != ids.length) {
      revert ERC1155InvalidArrayLength(ids.length, accounts.length);
    }

    uint256[] memory batchBalances = new uint256[](accounts.length);

    for (uint256 i = 0; i < accounts.length; ++i) {
      batchBalances[i] = balanceOf(accounts.unsafeMemoryAccess(i), ids.unsafeMemoryAccess(i));
    }

    return batchBalances;
  }

  /**
   * @dev See {IERC1155-setApprovalForAll}.
   */
  function setApprovalForAll(address operator, bool approved) public virtual {
    _setApprovalForAll(_msgSender(), operator, approved);
  }

  /**
   * @dev See {IERC1155-isApprovedForAll}.
   */
  function isApprovedForAll(address account, address operator) public view virtual returns (bool) {
    return _operatorApprovals[account][operator];
  }

  /**
   * @dev See {IERC1155-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 value,
    bytes memory data
  ) public virtual {
    address sender = _msgSender();
    if (from != sender && !isApprovedForAll(from, sender)) {
      revert ERC1155MissingApprovalForAll(sender, from);
    }
    _safeTransferFrom(from, to, id, value, data);
  }

  /**
   * @dev See {IERC1155-safeBatchTransferFrom}.
   */
  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory values,
    bytes memory data
  ) public virtual {
    address sender = _msgSender();
    if (from != sender && !isApprovedForAll(from, sender)) {
      revert ERC1155MissingApprovalForAll(sender, from);
    }
    _safeBatchTransferFrom(from, to, ids, values, data);
  }

  /**
   * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`. Will mint (or burn) if `from`
   * (or `to`) is the zero address.
   *
   * Emits a {TransferSingle} event if the arrays contain one element, and {TransferBatch} otherwise.
   *
   * Requirements:
   *
   * - If `to` refers to a smart contract, it must implement either {IERC1155Receiver-onERC1155Received}
   *   or {IERC1155Receiver-onERC1155BatchReceived} and return the acceptance magic value.
   * - `ids` and `values` must have the same length.
   *
   * NOTE: The ERC-1155 acceptance check is not performed in this function. See {_updateWithAcceptanceCheck} instead.
   */
  function _update(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory values
  ) internal virtual {
    if (ids.length != values.length) {
      revert ERC1155InvalidArrayLength(ids.length, values.length);
    }

    address operator = _msgSender();

    for (uint256 i = 0; i < ids.length; ++i) {
      uint256 id = ids.unsafeMemoryAccess(i);
      uint256 value = values.unsafeMemoryAccess(i);

      if (from != address(0)) {
        uint256 fromBalance = _balances[id][from];
        if (fromBalance < value) {
          revert ERC1155InsufficientBalance(from, fromBalance, value, id);
        }
        unchecked {
          // Overflow not possible: value <= fromBalance
          _balances[id][from] = fromBalance - value;
        }
      }

      if (to != address(0)) {
        _balances[id][to] += value;
      }
    }

    if (ids.length == 1) {
      uint256 id = ids.unsafeMemoryAccess(0);
      uint256 value = values.unsafeMemoryAccess(0);
      emit TransferSingle(operator, from, to, id, value);
    } else {
      emit TransferBatch(operator, from, to, ids, values);
    }
  }

  /**
   * @dev Version of {_update} that performs the token acceptance check by calling
   * {IERC1155Receiver-onERC1155Received} or {IERC1155Receiver-onERC1155BatchReceived} on the receiver address if it
   * contains code (eg. is a smart contract at the moment of execution).
   *
   * IMPORTANT: Overriding this function is discouraged because it poses a reentrancy risk from the receiver. So any
   * update to the contract state after this function would break the check-effect-interaction pattern. Consider
   * overriding {_update} instead.
   */
  function _updateWithAcceptanceCheck(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory values,
    bytes memory data
  ) internal virtual {
    _update(from, to, ids, values);
    if (to != address(0)) {
      address operator = _msgSender();
      if (ids.length == 1) {
        uint256 id = ids.unsafeMemoryAccess(0);
        uint256 value = values.unsafeMemoryAccess(0);
        _doSafeTransferAcceptanceCheck(operator, from, to, id, value, data);
      } else {
        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, values, data);
      }
    }
  }

  /**
   * @dev Transfers a `value` tokens of token type `id` from `from` to `to`.
   *
   * Emits a {TransferSingle} event.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - `from` must have a balance of tokens of type `id` of at least `value` amount.
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
   * acceptance magic value.
   */
  function _safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 value,
    bytes memory data
  ) internal {
    if (to == address(0)) {
      revert ERC1155InvalidReceiver(address(0));
    }
    if (from == address(0)) {
      revert ERC1155InvalidSender(address(0));
    }
    (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
    _updateWithAcceptanceCheck(from, to, ids, values, data);
  }

  /**
   * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
   *
   * Emits a {TransferBatch} event.
   *
   * Requirements:
   *
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
   * acceptance magic value.
   * - `ids` and `values` must have the same length.
   */
  function _safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory values,
    bytes memory data
  ) internal {
    if (to == address(0)) {
      revert ERC1155InvalidReceiver(address(0));
    }
    if (from == address(0)) {
      revert ERC1155InvalidSender(address(0));
    }
    _updateWithAcceptanceCheck(from, to, ids, values, data);
  }

  /**
   * @dev Sets a new URI for all token types, by relying on the token type ID
   * substitution mechanism
   * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
   *
   * By this mechanism, any occurrence of the `\{id\}` substring in either the
   * URI or any of the values in the JSON file at said URI will be replaced by
   * clients with the token type ID.
   *
   * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
   * interpreted by clients as
   * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
   * for token type ID 0x4cce0.
   *
   * See {uri}.
   *
   * Because these URIs cannot be meaningfully represented by the {URI} event,
   * this function emits no events.
   */
  function _setURI(string memory newuri) internal virtual {
    _uri = newuri;
  }

  /**
   * @dev Creates a `value` amount of tokens of type `id`, and assigns them to `to`.
   *
   * Emits a {TransferSingle} event.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
   * acceptance magic value.
   */
  function _mint(address to, uint256 id, uint256 value, bytes memory data) internal {
    if (to == address(0)) {
      revert ERC1155InvalidReceiver(address(0));
    }
    (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
    _updateWithAcceptanceCheck(address(0), to, ids, values, data);
  }

  /**
   * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
   *
   * Emits a {TransferBatch} event.
   *
   * Requirements:
   *
   * - `ids` and `values` must have the same length.
   * - `to` cannot be the zero address.
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
   * acceptance magic value.
   */
  function _mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory values,
    bytes memory data
  ) internal {
    if (to == address(0)) {
      revert ERC1155InvalidReceiver(address(0));
    }
    _updateWithAcceptanceCheck(address(0), to, ids, values, data);
  }

  /**
   * @dev Destroys a `value` amount of tokens of type `id` from `from`
   *
   * Emits a {TransferSingle} event.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `from` must have at least `value` amount of tokens of type `id`.
   */
  function _burn(address from, uint256 id, uint256 value) internal {
    if (from == address(0)) {
      revert ERC1155InvalidSender(address(0));
    }
    (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
    _updateWithAcceptanceCheck(from, address(0), ids, values, "");
  }

  /**
   * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
   *
   * Emits a {TransferBatch} event.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `from` must have at least `value` amount of tokens of type `id`.
   * - `ids` and `values` must have the same length.
   */
  function _burnBatch(address from, uint256[] memory ids, uint256[] memory values) internal {
    if (from == address(0)) {
      revert ERC1155InvalidSender(address(0));
    }
    _updateWithAcceptanceCheck(from, address(0), ids, values, "");
  }

  /**
   * @dev Approve `operator` to operate on all of `owner` tokens
   *
   * Emits an {ApprovalForAll} event.
   *
   * Requirements:
   *
   * - `operator` cannot be the zero address.
   */
  function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
    if (operator == address(0)) {
      revert ERC1155InvalidOperator(address(0));
    }
    _operatorApprovals[owner][operator] = approved;
    emit ApprovalForAll(owner, operator, approved);
  }

  /**
   * @dev Performs an acceptance check by calling {IERC1155-onERC1155Received} on the `to` address
   * if it contains code at the moment of execution.
   */
  function _doSafeTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256 id,
    uint256 value,
    bytes memory data
  ) internal virtual {
    if (to.code.length > 0) {
      try IERC1155Receiver(to).onERC1155Received(operator, from, id, value, data) returns (
        bytes4 response
      ) {
        if (response != IERC1155Receiver.onERC1155Received.selector) {
          // Tokens rejected
          revert ERC1155InvalidReceiver(to);
        }
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          // non-ERC1155Receiver implementer
          revert ERC1155InvalidReceiver(to);
        } else {
          /// @solidity memory-safe-assembly
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    }
  }

  /**
   * @dev Performs a batch acceptance check by calling {IERC1155-onERC1155BatchReceived} on the `to` address
   * if it contains code at the moment of execution.
   */
  function _doSafeBatchTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory values,
    bytes memory data
  ) private {
    if (to.code.length > 0) {
      try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, values, data) returns (
        bytes4 response
      ) {
        if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
          // Tokens rejected
          revert ERC1155InvalidReceiver(to);
        }
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          // non-ERC1155Receiver implementer
          revert ERC1155InvalidReceiver(to);
        } else {
          /// @solidity memory-safe-assembly
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    }
  }

  /**
   * @dev Creates an array in memory with only one value for each of the elements provided.
   */
  function _asSingletonArrays(
    uint256 element1,
    uint256 element2
  ) private pure returns (uint256[] memory array1, uint256[] memory array2) {
    /// @solidity memory-safe-assembly
    assembly {
      // Load the free memory pointer
      array1 := mload(0x40)
      // Set array length to 1
      mstore(array1, 1)
      // Store the single element at the next word after the length (where content starts)
      mstore(add(array1, 0x20), element1)

      // Repeat for next array locating it right after the first array
      array2 := add(array1, 0x40)
      mstore(array2, 1)
      mstore(add(array2, 0x20), element2)

      // Update the free memory pointer by pointing after the second array
      mstore(0x40, add(array2, 0x40))
    }
  }
}

abstract contract ERC1155Pausable is ERC1155, Pausable {
  /**
   * @dev See {ERC1155-_update}.
   *
   * Requirements:
   *
   * - the contract must not be paused.
   */
  function _update(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory values
  ) internal virtual override whenNotPaused {
    super._update(from, to, ids, values);
  }
}

abstract contract ERC1155Burnable is IERC1155Burnable, ERC1155 {
  function burn(address account, uint256 id, uint256 value) public virtual override {
    if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
      revert ERC1155MissingApprovalForAll(_msgSender(), account);
    }

    _burn(account, id, value);
  }

  function burnBatch(
    address account,
    uint256[] memory ids,
    uint256[] memory values
  ) public virtual {
    if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
      revert ERC1155MissingApprovalForAll(_msgSender(), account);
    }

    _burnBatch(account, ids, values);
  }
}

abstract contract ERC1155Supply is IERC1155Supply, ERC1155 {
  mapping(uint256 id => uint256) private _totalSupply;
  uint256 private _totalSupplyAll;

  /**
   * @dev Total value of tokens in with a given id.
   */
  function totalSupply(uint256 id) public view virtual returns (uint256) {
    return _totalSupply[id];
  }

  /**
   * @dev Total value of tokens.
   */
  function totalSupply() public view virtual returns (uint256) {
    return _totalSupplyAll;
  }

  /**
   * @dev Indicates whether any token exist with a given id, or not.
   */
  function exists(uint256 id) public view virtual returns (bool) {
    return totalSupply(id) > 0;
  }

  /**
   * @dev See {ERC1155-_update}.
   */
  function _update(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory values
  ) internal virtual override {
    super._update(from, to, ids, values);

    if (from == address(0)) {
      uint256 totalMintValue = 0;
      for (uint256 i = 0; i < ids.length; ++i) {
        uint256 value = values[i];
        // Overflow check required: The rest of the code assumes that totalSupply never overflows
        _totalSupply[ids[i]] += value;
        totalMintValue += value;
      }
      // Overflow check required: The rest of the code assumes that totalSupplyAll never overflows
      _totalSupplyAll += totalMintValue;
    }

    if (to == address(0)) {
      uint256 totalBurnValue = 0;
      for (uint256 i = 0; i < ids.length; ++i) {
        uint256 value = values[i];

        unchecked {
          // Overflow not possible: values[i] <= balanceOf(from, ids[i]) <= totalSupply(ids[i])
          _totalSupply[ids[i]] -= value;
          // Overflow not possible: sum_i(values[i]) <= sum_i(totalSupply(ids[i])) <= totalSupplyAll
          totalBurnValue += value;
        }
      }
      unchecked {
        // Overflow not possible: totalBurnValue = sum_i(values[i]) <= sum_i(totalSupply(ids[i])) <= totalSupplyAll
        _totalSupplyAll -= totalBurnValue;
      }
    }
  }
}

/**
 * @notice Base contract for gETH.
 * @dev Above contracts are taken from Openzeppelin.
 * @dev Only difference is _doSafeTransferAcceptanceCheck is being internal virtual instead of private, because we want to be able to override it in gETH:
 * ERC1155:
 * * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/cffb2f1ddcd87efd68effc92cfd336c5145acabd/contracts/token/ERC1155/ERC1155.sol#1
 * ERC1155Pausable:
 * * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/37afdc8910f2853426c20e504ecfe5d992e21813/contracts/token/ERC1155/extensions/ERC1155Pausable.sol#L1
 * ERC1155Burnable:
 * * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/37afdc8910f2853426c20e504ecfe5d992e21813/contracts/token/ERC1155/extensions/ERC1155Burnable.sol#L1
 * ERC1155Supply:
 * * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/37afdc8910f2853426c20e504ecfe5d992e21813/contracts/token/ERC1155/extensions/ERC1155Supply.sol#L1
 *
 * @dev Below contract ERC1155PausableBurnableSupply is created with openzeppelin wizard:
 * + Mintable
 * + Burnable
 * + Supply Tracking
 * + Pausable
 * + Updatable URI
 * + Roles
 * Additionally, its constructor is changed for some gas savings.
 */
contract ERC1155PausableBurnableSupply is
  IERC1155PausableBurnableSupply,
  ERC1155,
  AccessControl,
  ERC1155Pausable,
  ERC1155Burnable,
  ERC1155Supply
{
  bytes32 public immutable URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
  bytes32 public immutable PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public immutable MINTER_ROLE = keccak256("MINTER_ROLE");

  constructor(string memory uri_) ERC1155(uri_) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(keccak256("URI_SETTER_ROLE"), msg.sender);
    _grantRole(keccak256("PAUSER_ROLE"), msg.sender);
    _grantRole(keccak256("MINTER_ROLE"), msg.sender);
  }

  function setURI(string memory newuri) public override onlyRole(URI_SETTER_ROLE) {
    _setURI(newuri);
  }

  function pause() public override onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() public override onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function mint(
    address account,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public override onlyRole(MINTER_ROLE) {
    _mint(account, id, amount, data);
  }

  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) public override onlyRole(MINTER_ROLE) {
    _mintBatch(to, ids, amounts, data);
  }

  // The following functions are overrides required by Solidity.

  function _update(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory values
  ) internal override(ERC1155, ERC1155Pausable, ERC1155Supply) {
    super._update(from, to, ids, values);
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC1155, AccessControl, IERC165) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
