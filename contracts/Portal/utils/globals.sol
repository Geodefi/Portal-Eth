// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// PERCENTAGE_DENOMINATOR represents 100%
uint256 constant PERCENTAGE_DENOMINATOR = 10 ** 10;

/**
 * @notice ID_TYPE is like an ENUM, widely used within Portal and Modules like Withdrawal Contract
 * @dev Why not use enums, they basically do the same thing?
 * * We like using a explicit defined uints than linearly increasing ones.
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

  /// @notice TYPE 4: Node Operators
  uint256 internal constant OPERATOR = 4;

  /// @notice TYPE 5: Staking Pools
  uint256 internal constant POOL = 5;

  /// @notice TYPE 21: Module: Withdrawal Contract
  uint256 internal constant MODULE_WITHDRAWAL_CONTRACT = 21;

  /// @notice TYPE 31: Module: A new gETH interface
  uint256 internal constant MODULE_GETH_INTERFACE = 31;

  /// @notice TYPE 41: Module: A new Liquidity Pool
  uint256 internal constant MODULE_LIQUDITY_POOL = 41;

  /// @notice TYPE 42: Module: A new Liquidity Pool token
  uint256 internal constant MODULE_LIQUDITY_POOL_TOKEN = 42;
}

/**
 * @notice VALIDATOR_STATE keeping track of validators within The Staking Library
 */
library VALIDATOR_STATE {
  /// @notice STATE 0: *invalid*
  uint8 internal constant NONE = 0;

  /// @notice STATE 1: validator is proposed, 1 ETH is sent from Operator to Deposit Contract
  uint8 internal constant PROPOSED = 1;

  /// @notice STATE 2: proposal was approved, operator used pooled funds, 1 ETH is released back to Operator
  uint8 internal constant ACTIVE = 2;

  /// @notice STATE 3: validator is exited, not currently used much
  uint8 internal constant EXITED = 3;

  /// @notice STATE 69: proposal was malicious(alien), maybe faulty signatures or probably: (https://bit.ly/3Tkc6UC)
  uint8 internal constant ALIENATED = 69;
}
