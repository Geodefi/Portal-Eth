// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

/**
 * @notice ID_TYPE is like an ENUM, widely used within Portal and Modules like Withdrawal Contract
 * @dev Why not use enums, they basically do the same thing?
 * * We like using explicitly defined uints than linearly increasing ones.
 * @dev all LIMIT parameters are exclusive, this aims to prevent double usage.
 */
library ID_TYPE {
  /// @notice TYPE 0: *invalid*
  uint256 internal constant NONE = 0;

  /// @notice TYPE 1: Senate
  uint256 internal constant SENATE = 1;

  /// @notice TYPE 2: Contract Upgrade
  uint256 internal constant CONTRACT_UPGRADE = 2;

  /// @notice TYPE 3: *gap*: formally represented the admin contract, now reserved to be never used
  uint256 internal constant __GAP__ = 3;

  /// @notice TYPE 4: USER: Node Operators
  uint256 internal constant OPERATOR = 4;

  /// @notice TYPE 5: USER: Staking Pools
  uint256 internal constant POOL = 5;

  /// --

  /// @notice TYPE 10000: LIMIT: exclusive, minimum TYPE that will be percieved as a default module
  uint256 internal constant LIMIT_DEFAULT_MODULE_MIN = 10000;

  /// @notice TYPE 10011: Module: The Withdrawal Contract
  uint256 internal constant DEFAULT_MODULE_WITHDRAWAL_CONTRACT = 10011;

  /// @notice TYPE 10021: Module: A Liquidity Pool
  uint256 internal constant DEFAULT_MODULE_LIQUDITY_POOL = 10021;

  // /// @notice TYPE 10021: Module: A Liquidity Pool Token
  // uint256 internal constant DEFAULT_MODULE_LIQUDITY_POOL_TOKEN = 10022;

  /// @notice TYPE 19999: LIMIT: exclusive, maximum TYPE that will be percieved as a default module
  uint256 internal constant LIMIT_DEFAULT_MODULE_MAX = 19999;

  /// --

  /// @notice TYPE 20000: LIMIT: exclusive, minimum TYPE that will be percieved as a allowed module
  uint256 internal constant LIMIT_ALLOWED_MODULE_MIN = 20000;

  /// @notice TYPE 20031: Module: A new gETH interface
  uint256 internal constant ALLOWED_MODULE_GETH_INTERFACE = 20031;

  /// @notice TYPE 29999: LIMIT: exclusive, maximum TYPE that will be percieved as a allowed module
  uint256 internal constant LIMIT_ALLOWED_MODULE_MAX = 29999;
}
