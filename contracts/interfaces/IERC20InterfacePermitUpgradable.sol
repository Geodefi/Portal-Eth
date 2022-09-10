// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "./IgETH.sol";

interface IERC20InterfacePermitUpgradable {
    function initialize(
        uint256 id_,
        string memory name_,
        string memory symbol_,
        IgETH gETH_1155
    ) external;
}
