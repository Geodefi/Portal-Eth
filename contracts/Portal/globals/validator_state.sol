// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

/**
 * @notice VALIDATOR_STATE: keeping track of validators within The Staking Library.
 */
library VALIDATOR_STATE {
  /// @notice STATE 0: *invalid*
  uint8 internal constant NONE = 0;

  /// @notice STATE 1: validator is proposed, 1 ETH is sent from Operator to Deposit Contract.
  uint8 internal constant PROPOSED = 1;

  /// @notice STATE 2: proposal was approved, operator used pooled funds, 1 ETH is released back to Operator.
  uint8 internal constant ACTIVE = 2;

  /// @notice STATE 3: validator is called to be exited. Currently not used.
  uint8 internal constant EXIT_CALLED = 3;

  /// @notice STATE 3: validator is fully exited. Currently not used.
  uint8 internal constant EXIT_FILLED = 4;

  /// @notice STATE 69: proposal was malicious(alien). Maybe faulty signatures or probably (https://bit.ly/3Tkc6UC)
  uint8 internal constant ALIENATED = 69;
}
