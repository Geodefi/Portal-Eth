// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IERC20InterfacePermitUpgradable {
    function initialize(
        uint256 id_,
        string memory name_,
        string memory symbol_,
        address gETH_1155
    ) external;
}
