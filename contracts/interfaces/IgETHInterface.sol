// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IgETHInterface {
  function initialize(uint256 id_, address erc1155_, bytes memory data) external returns (bool);
}
