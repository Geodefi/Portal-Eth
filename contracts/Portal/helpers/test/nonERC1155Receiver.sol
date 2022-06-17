// SPDX-License-Identifier: MIT

pragma solidity =0.8.7;
import "@openzeppelin/contracts/utils/Context.sol";
import "../../../interfaces/IgETH.sol";

contract nonERC1155Receiver is Context {
    mapping(address => mapping(address => uint256)) private _allowances;
    string public constant name = "nonERC1155Receiver";
    uint256 private immutable _id;
    IgETH private immutable _ERC1155;

    constructor(uint256 id_, address gETH_1155) {
        _id = id_;
        _ERC1155 = IgETH(gETH_1155);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
        public
        virtual
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "burn from the zero address");

        unchecked {
            _ERC1155.burn(account, _id, amount);
        }
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        unchecked {
            _ERC1155.safeTransferFrom(sender, recipient, _id, amount, "");
        }
    }
}
