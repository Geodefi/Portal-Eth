// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "./helpers/ERC1155SupplyMinterPauser.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title gETH : Geode Finance Liquid Staking Derivatives
 * gETH is a special ERC1155 contract with additional functionalities:
 *
 * Denominator
 * * ERC1155 does not have decimals and it is not wise to use the name convention
 * * but we need to provide some information on how to denominate the balances, price, etc.

 * PricePerShare
 * * Keeping track of the ratio between the derivative 
 * * and the underlaying staked asset, Ether.
 *
 * gETHInterfaces
 * * Most important functionality gETH provides:
 * * Allowing any other contract to provide additional functionality 
 * * around the balance and price data, such as using an ID like ERC20.
 * * 
 * * This addition effectively result in changes in 
 * * safeTransferFrom(), burn(), _doSafeTransferAcceptanceCheck()
 * * functions, reasoning is in the comments.
 * 
 * Avoiders
 * * If one wants to remain unbound from gETHInterfaces, 
 * * it can be done so by calling "avoidInterfaces" function.
 *
 * @dev review first helpers/ERC1155SupplyMinterPauser.sol 
 */

contract gETH is ERC1155SupplyMinterPauser {
    using Address for address;

    event PriceUpdated(
        uint256 id,
        uint256 pricePerShare,
        uint256 updateTimestamp
    );

    event InterfaceChanged(
        address indexed newInterface,
        uint256 id,
        bool isSet
    );
    event InterfacesAvoided(address indexed avoider, uint256 id, bool isAvoid);

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    string public constant name = "Geode Staked Ether";
    string public constant symbol = "gETH";
    uint256 private constant _denominator = 1 ether;

    /**
     * @notice Mapping from pool IDs to gETHınterface implementation addresses
     * @dev There can be multiple Interfaces for 1 staking pool.
     * @dev ADDED for gETH
     **/
    mapping(uint256 => mapping(address => bool)) private _interfaces;

    /**
     * @notice Mapping of user addresses who chose to restrict the access of interfaces
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

    constructor(string memory uri) ERC1155SupplyMinterPauser(uri) {
        _setupRole(ORACLE_ROLE, _msgSender());
    }

    /**
    *                                       ** DENOMINATOR **
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
    *                                       ** INTERFACES **
    */

    /**
     * @notice Check if an address is approved as an interface for an ID
     * @dev ADDED for gETH
     */
    function isInterface(
        address _interface,
        uint256 id
    ) public view virtual returns (bool) {
        require(
            _interface != address(0),
            "gETH: interface query for the zero address"
        );

        return _interfaces[id][_interface];
    }

    /**
     * @dev Only authorized parties should set the interface
     * @dev ADDED for gETH
     */
    function _setInterface(
        address _interface,
        uint256 _id,
        bool _isSet
    ) internal virtual {
        require(
            _interface != address(0),
            "gETH: interface query for the zero address"
        );

        _interfaces[_id][_interface] = _isSet;
    }

    /**
     * @notice Set an address of a contract that will
     * act as an interface on gETH contract for a spesific ID
     * @param _interface Address of the contract that will act as an interface
     * @param isSet true: sets as an interface, false: unsets
     * @dev ADDED for gETH
     */
    function setInterface(
        address _interface,
        uint256 id,
        bool isSet
    ) external virtual {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "gETH: must have MINTER_ROLE"
        );
        require(_interface.isContract(), "gETH: _interface must be a contract");

        _setInterface(_interface, id, isSet);

        emit InterfaceChanged(_interface, id, isSet);
    }

    /**
     * @notice Checks if the given address restricts the affect of the interfaces on their gETH
     * @param account the potential avoider
     * @dev ADDED for gETH
     **/
    function isAvoider(
        address account,
        uint256 id
    ) public view virtual returns (bool) {
        return _avoiders[account][id];
    }

    /**
     * @notice Restrict any affect of interfaces on the tokens of caller
     * @param isAvoid true: restrict interfaces, false: allow interfaces
     * @dev ADDED for gETH
     **/
    function avoidInterfaces(uint256 id, bool isAvoid) external virtual {
        _avoiders[_msgSender()][id] = isAvoid;

        emit InterfacesAvoided(_msgSender(), id, isAvoid);
    }

    /**
     * @dev ADDED for gETH
     * @return price of the derivative in terms of underlying token, Ether
     */
    function pricePerShare(uint256 id) external virtual view returns (uint256) {
        return _pricePerShare[id];
    }

    /**
     * @dev ADDED for gETH
     * @return timestamp of the latest price update for given ID
     */
    function priceUpdateTimestamp(uint256 id) external virtual view returns (uint256) {
        return _priceUpdateTimestamp[id];
    }

    /**
     * @dev ADDED for gETH
     */
    function _setPricePerShare(uint256 _price, uint256 _id) internal virtual {
        _pricePerShare[_id] = _price;
        _priceUpdateTimestamp[_id] = block.timestamp;
    }

    /**
     * @notice Only ORACLE can call this function and set price
     * @dev ADDED for gETH
     */
    function setPricePerShare(uint256 price, uint256 id) external virtual {
        require(
            hasRole(ORACLE_ROLE, _msgSender()),
            "gETH: must have ORACLE to set"
        );
        require(id != 0, "gETH: price query for the zero address");

        _setPricePerShare(price, id);

        emit PriceUpdated(id, price, block.timestamp);
    }

    /**
     * @notice updates the authorized party for Minter operations related to minting
     * @dev Minter is basically a superUser, there can be only 1 at a given time,
     * @dev intended as "Portal"
     */
    function updateMinterRole(address Minter) external virtual {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "gETH: must have MINTER_ROLE"
        );

        renounceRole(MINTER_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, Minter);
    }

    /**
     * @notice updates the authorized party for Pausing operations.
     * @dev Pauser is basically a superUser, there can be only 1 at a given time,
     * @dev intended as "Portal"
     */
    function updatePauserRole(address Pauser) external virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "gETH: must have PAUSER_ROLE"
        );

        renounceRole(PAUSER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, Pauser);
    }

    /**
     * @notice updates the authorized party for Oracle operations related to pricing.
     * @dev Oracle is basically a superUser, there can be only 1 at a given time,
     * @dev intended as "Portal"
     */
    function updateOracleRole(address Oracle) external virtual {
        require(
            hasRole(ORACLE_ROLE, _msgSender()),
            "gETH: must have ORACLE_ROLE"
        );

        renounceRole(ORACLE_ROLE, _msgSender());
        _setupRole(ORACLE_ROLE, Oracle);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     * @dev interfaces can move your tokens without asking you
     * @dev CHANGED for gETH
     * @dev ADDED "|| (isInterface(_msgSender(), id) && !isAvoider(from))"
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
                (isInterface(_msgSender(), id) && !isAvoider(from, id)),
            "ERC1155: caller is not owner nor approved nor an allowed interface"
        );

        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     * @dev CHANGED for gETH
     * @dev ADDED "|| (isInterface(_msgSender(), id) && !isAvoider(account))"
     */
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public virtual override {
        require(
            account == _msgSender() ||
                isApprovedForAll(account, _msgSender()) ||
                (isInterface(_msgSender(), id) && !isAvoider(account, id)),
            "ERC1155: caller is not owner nor approved nor an allowed interface"
        );

        _burn(account, id, value);
    }

    /**
     * @notice interfaces should handle these checks internally
     * @dev See {IERC1155-safeTransferFrom}.
     * @dev CHANGED for gETH
     * @dev ADDED "&& !isInterface(operator,id))"
     */
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual override {
        if (to.isContract() && !isInterface(operator, id)) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
}
