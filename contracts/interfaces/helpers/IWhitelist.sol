// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

interface IWhitelist {
  function isAllowed(address) external view returns (bool);
}
