// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import {IWhitelist} from "../../../interfaces/IWhitelist.sol";

// contract Whitelist is IWhitelist, Ownable {
//   mapping(address => bool) private whitelist;

//   event Listed(address indexed account, bool isWhitelisted);

//   function isAllowed(address _address) external view virtual override returns (bool) {
//     return whitelist[_address];
//   }

//   function setAddress(address _address, bool allow) external virtual onlyOwner {
//     require(whitelist[_address] != allow);

//     whitelist[_address] = allow;

//     emit Listed(_address, allow);
//   }
// }
