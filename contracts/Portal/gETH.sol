// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// external
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC1155PausableBurnableSupply} from "./helpers/ERC1155SupplyMinterPauser.sol";

/**
 * @title gETH : Geode Finance Liquid Staking Derivatives
 *
 * @dev gETH is chain-agnostic, meaning it can be used on any evm chain
 * * if given the correct name and symbol.
 *
 * @dev gETH is immutable, it can not be upgraded.
 *
 * @dev gETH is a special ERC1155 contract with additional functionalities:
 * gETHMiddlewares:
 * * Most important functionality gETH provides:
 * * Allowing any other contract to provide additional functionality
 * * around the balance and price data, such as using an ID like ERC20.
 * * This addition effectively result in changes in
 * * safeTransferFrom(), burn(), _doSafeTransferAcceptanceCheck()
 * * functions, reasoning is in the comments.
 * Avoiders:
 * * If one wants to remain unbound from gETHMiddlewares,
 * * it can be done so by calling "avoidMiddlewares" function.
 * PricePerShare:
 * * Keeping track of the ratio between the derivative
 * * and the underlaying staked asset, Ether.
 * Denominator:
 * * ERC1155 does not have decimals and it is not wise to use the name convention
 * * but we need to provide some information on how to denominate the balances, price, etc.
 *
 * @dev review ERC1155PausableBurnableSupply, which is generated with Openzeppelin wizard.
 *
 * @author Ice Bear & Crash Bandicoot
 */

contract gETH is ERC1155PausableBurnableSupply {
  using Address for address;

  /**
   * @custom:section                           ** CONSTANTS **
   */
  /**
   * @dev both of these functions are
   */
  bytes32 public constant MIDDLEWARE_MANAGER_ROLE = keccak256("MIDDLEWARE_MANAGER_ROLE");
  bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
  uint256 internal constant DENOMINATOR = 1 ether;

  /**
   * @custom:section                           ** VARIABLES **
   */

  string public name;
  string public symbol;
  /**
   * @notice Mapping from pool IDs to gETHMiddleware implementation addresses
   * @dev There can be multiple Middlewares for 1 staking pool.
   * @dev ADDED for gETH
   **/
  mapping(uint256 => mapping(address => bool)) private _middlewares;

  /**
   * @notice Mapping of user addresses who chose to restrict the access of Middlewares
   * @dev ADDED for gETH
   **/
  mapping(address => mapping(uint256 => bool)) private _avoiders;

  /**
   * @notice shows the underlying ETH for 1 staked gETH for a given asset ID
   * @dev Freshly created IDs should return 1e18 since initally 1 ETH = 1 gETH
   * @dev ADDED for gETH
   **/
  mapping(uint256 => uint256) private _pricePerShare;
  /**
   * @notice ID to timestamp, pointing the second that the latest price update happened
   * @dev ADDED for gETH
   **/
  mapping(uint256 => uint256) private _priceUpdateTimestamp;

  /**
   * @custom:section                           ** EVENTS **
   */
  event PriceUpdated(uint256 id, uint256 pricePerShare, uint256 updateTimestamp);
  event MiddlewareSet(address indexed newMiddleware, uint256 id, bool isSet);
  event Avoided(address indexed avoider, uint256 id, bool isAvoid);

  /**
   * @custom:section                           ** CONSTRUCTOR **
   */
  /**
   * @notice ID to timestamp, pointing the second that the latest price update happened
   * @param _name chain specific name: Geode Staked Ether, geode Staked Avax etc.
   * @param _symbol chain specific symbol of the staking derivative: gETH, gGNO, gAVAX, etc.
   **/
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _uri
  ) ERC1155PausableBurnableSupply(_uri) {
    name = _name;
    symbol = _symbol;

    _grantRole(MIDDLEWARE_MANAGER_ROLE, msg.sender);
    _grantRole(ORACLE_ROLE, msg.sender);
  }

  /**
   * @custom:section                           ** DENOMINATOR **
   */
  /**
   * @dev -> view: all
   */
  /**
   * @notice a centralized denominator for all contract using gETH
   * @dev ERC1155 does not have a decimals, and it is not wise to use the same name
   * @dev ADDED for gETH
   */
  function denominator() external view virtual returns (uint256) {
    return DENOMINATOR;
  }

  /**
   * @custom:section                           ** MIDDLEWARES **
   */
  /**
   * @dev -> view
   */
  /**
   * @notice Check if an address is approved as an middleware for an ID
   * @dev ADDED for gETH
   */
  function isMiddleware(address middleware, uint256 id) public view virtual returns (bool) {
    return _middlewares[id][middleware];
  }

  /**
   * @dev -> internal
   */
  /**
   * @dev Only authorized parties should set the middleware
   * @dev ADDED for gETH
   */
  function _setMiddleware(address _middleware, uint256 _id, bool _isSet) internal virtual {
    require(_middleware != address(0), "gETH: middleware query for the zero address");
    _middlewares[_id][_middleware] = _isSet;
  }

  /**
   * @dev -> external
   */
  /**
   * @notice Set an address of a contract that will
   * act as an middleware on gETH contract for a spesific ID
   * @param middleware Address of the contract that will act as an middleware
   * @param isSet true: sets as an middleware, false: unsets
   * @dev ADDED for gETH
   */
  function setMiddleware(
    address middleware,
    uint256 id,
    bool isSet
  ) external virtual onlyRole(MIDDLEWARE_MANAGER_ROLE) {
    require(middleware.isContract(), "gETH: middleware must be a contract");

    _setMiddleware(middleware, id, isSet);

    emit MiddlewareSet(middleware, id, isSet);
  }

  /**
   * @custom:section                           ** AVOIDERS **
   */
  /**
   * @dev -> view
   */
  /**
   * @notice Checks if the given address restricts the affect of the middlewares on their gETH
   * @param account the potential avoider
   * @dev ADDED for gETH
   **/
  function isAvoider(address account, uint256 id) public view virtual returns (bool) {
    return _avoiders[account][id];
  }

  /**
   * @dev -> external
   */
  /**
   * @notice Restrict any affect of middlewares on the tokens of caller
   * @param isAvoid true: restrict middlewares, false: allow middlewares
   * @dev ADDED for gETH
   **/
  function avoidMiddlewares(uint256 id, bool isAvoid) external virtual {
    _avoiders[msg.sender][id] = isAvoid;

    emit Avoided(msg.sender, id, isAvoid);
  }

  /**
   * @custom:section                           ** PRICE **
   */
  /**
   * @dev -> view
   */
  /**
   * @dev ADDED for gETH
   * @return price of the derivative in terms of underlying token, Ether
   */
  function pricePerShare(uint256 id) external view virtual returns (uint256) {
    return _pricePerShare[id];
  }

  /**
   * @dev ADDED for gETH
   * @return timestamp of the latest price update for given ID
   */
  function priceUpdateTimestamp(uint256 id) external view virtual returns (uint256) {
    return _priceUpdateTimestamp[id];
  }

  /**
   * @dev -> internal
   */
  /**
   * @dev ADDED for gETH
   */
  function _setPricePerShare(uint256 _price, uint256 _id) internal virtual {
    _pricePerShare[_id] = _price;
    _priceUpdateTimestamp[_id] = block.timestamp;
  }

  /**
   * @dev -> external
   */
  /**
   * @notice Only ORACLE can call this function and set price
   * @dev ADDED for gETH
   */
  function setPricePerShare(uint256 price, uint256 id) external virtual onlyRole(ORACLE_ROLE) {
    require(id != 0, "gETH: price query for the zero address");

    _setPricePerShare(price, id);

    emit PriceUpdated(id, price, block.timestamp);
  }

  /**
   * @custom:section                           ** ROLES **
   */
  /**
   * @dev -> external :all
   */

  /**
   * @notice transfers the authorized party for setting a new uri.
   * @dev URI_SETTER is basically a superuser, there can be only 1 at a given time,
   * @dev intended as "Governance/DAO"
   */
  function transferUriSetterRole(address newUriSetter) external virtual {
    _grantRole(URI_SETTER_ROLE, newUriSetter);
    renounceRole(URI_SETTER_ROLE, msg.sender);
  }

  /**
   * @notice transfers the authorized party for Pausing operations.
   * @dev PAUSER is basically a superUser, there can be only 1 at a given time,
   * @dev intended as "Portal"
   */
  function transferPauserRole(address newPauser) external virtual {
    _grantRole(PAUSER_ROLE, newPauser);
    renounceRole(PAUSER_ROLE, msg.sender);
  }

  /**
   * @notice transfers the authorized party for Minting operations related to minting
   * @dev MINTER is basically a superUser, there can be only 1 at a given time,
   * @dev intended as "Portal"
   */
  function transferMinterRole(address newMinter) external virtual {
    _grantRole(MINTER_ROLE, newMinter);
    renounceRole(MINTER_ROLE, msg.sender);
  }

  /**
   * @notice transfers the authorized party for Oracle operations related to pricing
   * @dev ORACLE is basically a superUser, there can be only 1 at a given time,
   * @dev intended as "Portal"
   */
  function transferOracleRole(address newOracle) external virtual {
    _grantRole(ORACLE_ROLE, newOracle);
    renounceRole(ORACLE_ROLE, msg.sender);
  }

  /**
   * @notice transfers the authorized party for middleware management
   * @dev MIDDLEWARE MANAGER is basically a superUser, there can be only 1 at a given time,
   * @dev intended as "Portal"
   */
  function transferMiddlewareManagerRole(address newMiddlewareManager) external virtual {
    renounceRole(MIDDLEWARE_MANAGER_ROLE, msg.sender);
    _grantRole(MIDDLEWARE_MANAGER_ROLE, newMiddlewareManager);
  }

  /**
   * @custom:section                           ** OVERRIDES **
   *
   * @dev middleware of a specific ID can move funds between accounts without approval.
   * So, we will be overriding 2 functions:
   * * safeTransferFrom
   * * burn
   * note safeBatchTransferFrom is not need to be overriden,
   * as a middleware should not do batch transfers.
   *
   * @dev middlewares should handle transfer checks internally.
   * Because of this we want to remove the SafeTransferAcceptanceCheck if the caller is a middleware.
   * However, overriding _doSafeTransferAcceptanceCheck is not possible.
   * So, we will override the two functions that these checks are done:
   * * _safeTransferFrom
   * * _mint
   * note _doSafeBatchTransferAcceptanceCheck is not need to be overriden,
   * as a middleware should not do batch transfers.
   */

  /**
   * @dev -> internal
   */

  /**
   * @dev CHANGED for gETH
   * @dev ADDED if (!isMiddleware) check at the end.
   * @dev See ERC1155 _safeTransferFrom:
   * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/cf86fd9962701396457e50ab0d6cc78aa29a5ebc/contracts/token/ERC1155/ERC1155.sol#L157
   */
  function _safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) internal virtual {
    require(to != address(0), "ERC1155: transfer to the zero address");

    address operator = _msgSender();
    uint256[] memory ids = _asSingletonArray(id);
    uint256[] memory amounts = _asSingletonArray(amount);

    _beforeTokenTransfer(operator, from, to, ids, amounts, data);

    uint256 fromBalance = _balances[id][from];
    require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
    unchecked {
      _balances[id][from] = fromBalance - amount;
    }
    _balances[id][to] += amount;

    emit TransferSingle(operator, from, to, id, amount);

    _afterTokenTransfer(operator, from, to, ids, amounts, data);

    if (!isMiddleware) {
      _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }
  }

  /**
   * @dev CHANGED for gETH
   * @dev ADDED if (!isMiddleware) check at the end.
   * @dev See ERC1155 _mint:
   * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/cf86fd9962701396457e50ab0d6cc78aa29a5ebc/contracts/token/ERC1155/ERC1155.sol#L263   * @dev CHANGED for gETH
   */
  function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
    require(to != address(0), "ERC1155: mint to the zero address");

    address operator = _msgSender();
    uint256[] memory ids = _asSingletonArray(id);
    uint256[] memory amounts = _asSingletonArray(amount);

    _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

    _balances[id][to] += amount;
    emit TransferSingle(operator, address(0), to, id, amount);

    _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

    if (!isMiddleware) {
      _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }
  }

  /**
   * @dev -> external
   */

  /**
   * @dev CHANGED for gETH
   * @dev ADDED "|| (isMiddleware(_msgSender(), id) && !isAvoider(from, id))"
   * @dev See ERC1155 safeTransferFrom:
   * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/cf86fd9962701396457e50ab0d6cc78aa29a5ebc/contracts/token/ERC1155/ERC1155.sol#L114
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public virtual override {
    require(
      (from == _msgSender()) ||
        (isApprovedForAll(from, _msgSender())) ||
        (isMiddleware(_msgSender(), id) && !isAvoider(from, id)),
      "ERC1155: caller is not token owner or approved or a middleware"
    );
    _safeTransferFrom(from, to, id, amount, data);
  }

  /**
   * @dev CHANGED for gETH
   * @dev ADDED "|| (isMiddleware(_msgSender(), id) && !isAvoider(from, id))"
   * @dev See ERC1155Burnable burn:
   * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/cf86fd9962701396457e50ab0d6cc78aa29a5ebc/contracts/token/ERC1155/extensions/ERC1155Burnable.sol#L15
   */
  function burn(address account, uint256 id, uint256 value) public virtual {
    require(
      (from == _msgSender()) ||
        (isApprovedForAll(from, _msgSender())) ||
        (isMiddleware(_msgSender(), id) && !isAvoider(from, id)),
      "ERC1155: caller is not token owner or approved or a middleware"
    );

    _burn(account, id, value);
  }
}
