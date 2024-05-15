// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IgETHMiddleware {
  function initialize(uint256 id_, address erc1155_, bytes memory data) external;

  function ERC1155() external view returns (address);

  function ERC1155_ID() external view returns (uint256);

  function pricePerShare() external view returns (uint256);
}
