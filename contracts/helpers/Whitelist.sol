// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IWhitelist} from "../interfaces/helpers/IWhitelist.sol";

/**
 * @title A minimal whitelisting contract
 *
 * @notice This contract is not used by any of the other contracts,
 * * but useful when testing or simply a referance for others.
 *
 * @dev Even though this is a fairly small contract, use it at your own risk.
 */
contract Whitelist is IWhitelist, Ownable {
  constructor() Ownable(msg.sender) {}

  mapping(address => bool) private _whitelist;

  event Listed(address indexed account, bool isWhitelisted);
  error AlreadySet();

  function isAllowed(address _address) external view virtual override returns (bool) {
    return _whitelist[_address];
  }

  function setAddress(address _address, bool allow) external virtual onlyOwner {
    if (_whitelist[_address] == allow) revert AlreadySet();

    _whitelist[_address] = allow;

    emit Listed(_address, allow);
  }
}
