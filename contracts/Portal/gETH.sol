// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// external
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC1155SupplyMinterPauser} from "./helpers/ERC1155SupplyMinterPauser.sol";

/**
 * @title gETH : Geode Finance Liquid Staking Derivatives
*
 * @dev gETH is chain-agnostic, meaning it can be used on any evm chain 
 * * if given the correct name and symbol.
 *
 * @dev gETH is immutable, it can not be upgraded
 *
 * @dev gETH is a special ERC1155 contract with additional functionalities:
 *
 * Denominator
 * * ERC1155 does not have decimals and it is not wise to use the name convention
 * * but we need to provide some information on how to denominate the balances, price, etc.

 * PricePerShare
 * * Keeping track of the ratio between the derivative 
 * * and the underlaying staked asset, Ether.
 *
 * gETHMiddlewares
 * * Most important functionality gETH provides:
 * * Allowing any other contract to provide additional functionality 
 * * around the balance and price data, such as using an ID like ERC20.
 * * 
 * * This addition effectively result in changes in 
 * * safeTransferFrom(), burn(), _doSafeTransferAcceptanceCheck()
 * * functions, reasoning is in the comments.
 * 
 * Avoiders
 * * If one wants to remain unbound from gETHMiddlewares, 
 * * it can be done so by calling "avoidMiddlewares" function.
 *
 * @dev review first helpers/ERC1155SupplyMinterPauser.sol 
 *
 * @author Icebear & Crash Bandicoot
 */

contract gETH is ERC1155SupplyMinterPauser {
  using Address for address;

  /**
   * @dev                                     ** CONSTANTS **
   */
  bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
  uint256 internal constant _denominator = 1 ether;

  /**
   * @dev                                     ** VARIABLES **
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
   * @dev                                     ** EVENTS **
   */
  event PriceUpdated(uint256 id, uint256 pricePerShare, uint256 updateTimestamp);
  event MiddlewareChanged(address indexed newMiddleware, uint256 id, bool isSet);
  event MiddlewaresAvoided(address indexed avoider, uint256 id, bool isAvoid);

  /**
   * @dev                                     ** CONSTRUCTOR **
   */
  /**
   * @notice ID to timestamp, pointing the second that the latest price update happened
   * @dev ADDED for gETH
   * @param _name chain specific name: Geode Staked Ether, geode Staked Avax etc.
   * @param _symbol chain specific symbol of the staking derivative: gETH, gGNO, gAVAX, etc.
   * @param _uri ERC1155 uri
   **/
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _uri
  ) ERC1155SupplyMinterPauser(_uri) {
    name = _name;
    symbol = _symbol;

    _setupRole(ORACLE_ROLE, _msgSender());
  }

  /**
   * @dev                                     ** DENOMINATOR **
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
    return _denominator;
  }

  /**
   * @dev                                     ** MIDDLEWARES **
   */
  /**
   * @dev -> view
   */
  /**
   * @notice Check if an address is approved as an middleware for an ID
   * @dev ADDED for gETH
   */
  function isMiddleware(address middleware, uint256 id) public view virtual returns (bool) {
    require(middleware != address(0), "gETH: middleware query for the zero address");

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
  function setMiddleware(address middleware, uint256 id, bool isSet) external virtual {
    require(hasRole(MINTER_ROLE, _msgSender()), "gETH: must have MINTER_ROLE");
    require(middleware.isContract(), "gETH: middleware must be a contract");

    _setMiddleware(middleware, id, isSet);

    emit MiddlewareChanged(middleware, id, isSet);
  }

  /**
   * @dev                                     ** AVOIDERS **
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
    _avoiders[_msgSender()][id] = isAvoid;

    emit MiddlewaresAvoided(_msgSender(), id, isAvoid);
  }

  /**
   * @dev                                     ** PRICE **
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
  function setPricePerShare(uint256 price, uint256 id) external virtual {
    require(hasRole(ORACLE_ROLE, _msgSender()), "gETH: must have ORACLE to set");
    require(id != 0, "gETH: price query for the zero address");

    _setPricePerShare(price, id);

    emit PriceUpdated(id, price, block.timestamp);
  }

  /**
   * @dev                                     ** ROLES **
   */
  /**
   * @dev -> external :all
   */
  /**
   * @notice updates the authorized party for Minter operations related to minting
   * @dev Minter is basically a superUser, there can be only 1 at a given time,
   * @dev intended as "Portal"
   */
  function updateMinterRole(address Minter) external virtual {
    require(hasRole(MINTER_ROLE, _msgSender()), "gETH: must have MINTER_ROLE");

    renounceRole(MINTER_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, Minter);
  }

  /**
   * @notice updates the authorized party for Pausing operations.
   * @dev Pauser is basically a superUser, there can be only 1 at a given time,
   * @dev intended as "Portal"
   */
  function updatePauserRole(address Pauser) external virtual {
    require(hasRole(PAUSER_ROLE, _msgSender()), "gETH: must have PAUSER_ROLE");

    renounceRole(PAUSER_ROLE, _msgSender());
    _setupRole(PAUSER_ROLE, Pauser);
  }

  /**
   * @notice updates the authorized party for Oracle operations related to pricing.
   * @dev Oracle is basically a superUser, there can be only 1 at a given time,
   * @dev intended as "Portal"
   */
  function updateOracleRole(address Oracle) external virtual {
    require(hasRole(ORACLE_ROLE, _msgSender()), "gETH: must have ORACLE_ROLE");

    renounceRole(ORACLE_ROLE, _msgSender());
    _setupRole(ORACLE_ROLE, Oracle);
  }

  /**
   * @dev                                     ** OVERRIDES **
   */
  /**
   * @dev -> internal
   */
  /**
   * @notice middlewares should handle these checks internally
   * @dev See {IERC1155-safeTransferFrom}.
   * @dev CHANGED for gETH
   * @dev ADDED "&& !isMiddleware(operator,id)"
   */
  function _doSafeTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) internal virtual override {
    if (!isMiddleware(operator, id)) {
      super._doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }
  }

  /**
   * @dev -> external
   */
  /**
   * @dev See {IERC1155-safeTransferFrom}.
   * @dev middlewares can move your tokens without asking you
   * @dev CHANGED for gETH
   * @dev ADDED "|| (isMiddleware(_msgSender(), id) && !isAvoider(from))"
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public virtual override {
    require(
      from == _msgSender() ||
        isApprovedForAll(from, _msgSender()) ||
        (isMiddleware(_msgSender(), id) && !isAvoider(from, id)),
      "ERC1155: caller is not owner nor approved nor an allowed middleware"
    );

    _safeTransferFrom(from, to, id, amount, data);
  }

  /**
   * @dev See {IERC1155-safeTransferFrom}.
   * @dev CHANGED for gETH
   * @dev ADDED "|| (isMiddleware(_msgSender(), id) && !isAvoider(account))"
   */
  function burn(address account, uint256 id, uint256 value) public virtual override {
    require(
      account == _msgSender() ||
        isApprovedForAll(account, _msgSender()) ||
        (isMiddleware(_msgSender(), id) && !isAvoider(account, id)),
      "ERC1155: caller is not owner nor approved nor an allowed middleware"
    );

    _burn(account, id, value);
  }
}
