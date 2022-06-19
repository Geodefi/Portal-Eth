// SPDX-License-Identifier: MIT

pragma solidity =0.8.7;

import "@openzeppelin/contracts/utils/Context.sol";
import "../../../interfaces/IgETH.sol";

contract nonERC1155Receiver is Context {
    uint256 private immutable _id;
    IgETH private immutable _ERC1155;

    constructor(uint256 id_, address gETH_1155) {
        _id = id_;
        _ERC1155 = IgETH(gETH_1155);
    }

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
