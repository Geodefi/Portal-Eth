// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

interface ILPToken {
  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function balanceOf(address account) external view returns (uint256);

  function burn(uint256 amount) external;

  function burnFrom(address account, uint256 amount) external;

  function decimals() external view returns (uint8);

  function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

  function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

  function initialize(string memory name, string memory symbol) external;

  function mint(address recipient, uint256 amount) external;

  function name() external view returns (string memory);

  function owner() external view returns (address);

  function renounceOwnership() external;

  function symbol() external view returns (string memory);

  function totalSupply() external view returns (uint256);

  function transfer(address to, uint256 amount) external returns (bool);

  function transferFrom(address from, address to, uint256 amount) external returns (bool);

  function transferOwnership(address newOwner) external;
}
