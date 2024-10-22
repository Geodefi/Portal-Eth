// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IWithdrawalModule {
  function pause() external;

  function unpause() external;

  function setExitThreshold(uint256 newThreshold) external;

  function claimInfrastructureFees(address receiver) external returns (bool success);

  function WithdrawalParams()
    external
    view
    returns (
      address gETH,
      address portal,
      uint256 poolId,
      uint256 exitThreshold,
      uint256 gatheredInfrastructureFees
    );

  function QueueParams()
    external
    view
    returns (
      uint256 requested,
      uint256 realized,
      uint256 realizedEtherBalance,
      uint256 realizedPrice,
      uint256 fulfilled,
      uint256 fulfilledEtherBalance,
      uint256 commonPoll
    );

  function getRequest(
    uint256 index
  )
    external
    view
    returns (
      address owner,
      uint256 trigger,
      uint256 size,
      uint256 fulfilled,
      uint256 claimableEther
    );

  function getValidatorData(
    bytes calldata pubkey
  ) external view returns (uint256 beaconBalance, uint256 withdrawnBalance, uint256 poll);

  function canFinalizeExit(bytes memory pubkey) external view returns (bool);

  function validatorThreshold(bytes memory pubkey) external view returns (uint256 threshold);

  function enqueue(
    uint256 size,
    bytes calldata pubkey,
    address owner
  ) external returns (uint256 index);

  function enqueueBatch(
    uint256[] calldata sizes,
    bytes[] calldata pubkeys,
    address owner
  ) external returns (uint256[] memory indexes);

  function transferRequest(uint256 index, address newOwner) external;

  function fulfillable(uint256 index) external view returns (uint256);

  function fulfill(uint256 index) external;

  function fulfillBatch(uint256[] calldata indexes) external;

  function dequeue(uint256 index, address receiver) external;

  function dequeueBatch(uint256[] calldata indexes, address receiver) external;

  function processValidators(
    bytes[] calldata pubkeys,
    uint256[] calldata beaconBalances,
    uint256[] calldata withdrawnBalances,
    bytes32[][] calldata balanceProofs,
    uint256 price,
    bytes32[] calldata priceProof
  ) external;

  function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}
