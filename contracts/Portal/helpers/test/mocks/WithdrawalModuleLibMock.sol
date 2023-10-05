// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {StakeModule} from "../../../modules/StakeModule/StakeModule.sol";
import {StakeModuleLib} from "../../../modules/StakeModule/libs/StakeModuleLib.sol";
import {WithdrawalModule} from "../../../modules/WithdrawalModule/WithdrawalModule.sol";
import {WithdrawalModuleLib, PooledWithdrawal} from "../../../modules/WithdrawalModule/libs/WithdrawalModuleLib.sol";
import {InitiatorExtensionLib} from "../../../modules/StakeModule/libs/InitiatorExtensionLib.sol";
import {OracleExtensionLib} from "../../../modules/StakeModule/libs/OracleExtensionLib.sol";
import {DataStoreModuleLib} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";

contract WithdrawalModuleLibMock is WithdrawalModule {
  using WithdrawalModuleLib for PooledWithdrawal;

  function initialize(
    address _gETH_position,
    address _portal_position,
    uint256 _poolId
  ) external initializer {
    __WithdrawalModule_init(_gETH_position, _portal_position, _poolId);
  }

  function pause() external virtual override(WithdrawalModule) {
    _pause();
  }

  function unpause() external virtual override(WithdrawalModule) {
    _unpause();
  }

  function setExitThreshold(uint256 newThreshold) external virtual override(WithdrawalModule) {
    WITHDRAWAL.setExitThreshold(newThreshold);
  }

  function $getWithdrawalParams()
    external
    view
    returns (address gETH, address PORTAL, uint256 POOL_ID, uint256 EXIT_THRESHOLD)
  {
    gETH = address(WITHDRAWAL.gETH);
    PORTAL = address(WITHDRAWAL.PORTAL);
    POOL_ID = WITHDRAWAL.POOL_ID;
    EXIT_THRESHOLD = WITHDRAWAL.EXIT_THRESHOLD;
  }

  function $getValidatorData(
    bytes memory pubkey
  ) external view returns (uint256 beaconBalance, uint256 withdrawnBalance, uint256 poll) {
    beaconBalance = WITHDRAWAL.validators[pubkey].beaconBalance;
    withdrawnBalance = WITHDRAWAL.validators[pubkey].withdrawnBalance;
    poll = WITHDRAWAL.validators[pubkey].poll;
  }

  function $getQueueData()
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
    )
  {
    requested = WITHDRAWAL.queue.requested;
    realized = WITHDRAWAL.queue.realized;
    realizedEtherBalance = WITHDRAWAL.queue.realizedEtherBalance;
    realizedPrice = WITHDRAWAL.queue.realizedPrice;
    fulfilled = WITHDRAWAL.queue.fulfilled;
    fulfilledEtherBalance = WITHDRAWAL.queue.fulfilledEtherBalance;
    commonPoll = WITHDRAWAL.queue.commonPoll;
  }

  function $getRequestFromLastIndex(
    uint256 index
  )
    external
    view
    returns (
      uint256 realIndex,
      address owner,
      uint256 trigger,
      uint256 size,
      uint256 fulfilled,
      uint256 claimableEther
    )
  {
    require(index < WITHDRAWAL.requests.length, "WMLM: index exceeds length");
    realIndex = WITHDRAWAL.requests.length - 1 - index;
    owner = WITHDRAWAL.requests[realIndex].owner;
    trigger = WITHDRAWAL.requests[realIndex].trigger;
    size = WITHDRAWAL.requests[realIndex].size;
    fulfilled = WITHDRAWAL.requests[realIndex].fulfilled;
    claimableEther = WITHDRAWAL.requests[realIndex].claimableEther;
  }

  function $getValidatorThreshold(
    bytes memory pubkey
  ) external view returns (uint256 threshold, uint256 beaconBalancePriced) {
    (threshold, beaconBalancePriced) = WITHDRAWAL.getValidatorThreshold(pubkey);
  }

  function $setMockValidatorData(
    bytes memory pubkey,
    uint256 beaconBalance,
    uint256 withdrawnBalance,
    uint256 poll
  ) external {
    WITHDRAWAL.validators[pubkey].beaconBalance = beaconBalance;
    WITHDRAWAL.validators[pubkey].withdrawnBalance = withdrawnBalance;
    WITHDRAWAL.validators[pubkey].poll = poll;
  }

  function $setMockQueueData(
    uint256 requested,
    uint256 realized,
    uint256 fulfilled,
    uint256 realizedEtherBalance,
    uint256 realizedPrice,
    uint256 commonPoll
  ) external {
    WITHDRAWAL.queue.requested = requested;
    WITHDRAWAL.queue.realized = realized;
    WITHDRAWAL.queue.fulfilled = fulfilled;
    WITHDRAWAL.queue.realizedEtherBalance = realizedEtherBalance;
    WITHDRAWAL.queue.realizedPrice = realizedPrice;
    WITHDRAWAL.queue.commonPoll = commonPoll;
  }

  function $canFinalizeExit(bytes memory pubkey) external view returns (bool) {
    return WITHDRAWAL.canFinalizeExit(pubkey);
  }

  function $checkAndRequestExit(
    bytes calldata pubkey,
    uint256 commonPoll
  ) external returns (uint256) {
    return WITHDRAWAL.checkAndRequestExit(pubkey, commonPoll);
  }

  function $_vote(bytes calldata pubkey, uint256 size) external {
    WITHDRAWAL._vote(pubkey, size);
  }

  function $_enqueue(uint256 trigger, uint256 size, address owner) external {
    WITHDRAWAL._enqueue(trigger, size, owner);
  }

  function $enqueueBatch(
    uint256[] calldata sizes,
    bytes[] calldata pubkeys,
    address owner
  ) external {
    WITHDRAWAL.enqueueBatch(sizes, pubkeys, owner);
  }

  function $enqueue(uint256 size, bytes calldata pubkey, address owner) external {
    WITHDRAWAL.enqueue(size, pubkey, owner);
  }

  function $transferRequest(uint256 index, address newOwner) external {
    WITHDRAWAL.transferRequest(index, newOwner);
  }

  function $fulfillable(
    uint256 index,
    uint256 Qrealized,
    uint256 Qfulfilled
  ) external view returns (uint256) {
    return WITHDRAWAL.fulfillable(index, Qrealized, Qfulfilled);
  }

  function $fulfill(uint256 index) external {
    WITHDRAWAL.fulfill(index);
  }

  function $fulfillBatch(uint256[] calldata indexes) external {
    WITHDRAWAL.fulfillBatch(indexes);
  }

  function $_dequeue(uint256 index) external returns (uint256 claimableETH) {
    return WITHDRAWAL._dequeue(index);
  }

  function $dequeue(uint256 index, address receiver) external {
    WITHDRAWAL.dequeue(index, receiver);
  }

  function $dequeueBatch(uint256[] calldata indexes, address receiver) external {
    WITHDRAWAL.dequeueBatch(indexes, receiver);
  }

  function $_realizeProcessedEther(uint256 processedBalance) external {
    WITHDRAWAL._realizeProcessedEther(processedBalance);
  }

  function $_distributeFees(
    bytes memory pubkey,
    uint256 reportedWithdrawn,
    uint256 processedWithdrawn
  ) external returns (uint256 extra) {
    extra = WITHDRAWAL._distributeFees(pubkey, reportedWithdrawn, processedWithdrawn);
  }

  function $processValidators(
    bytes[] calldata pubkeys,
    uint256[] calldata beaconBalances,
    uint256[] calldata withdrawnBalances,
    bytes32[][] calldata balanceProofs
  ) external {
    WITHDRAWAL.processValidators(pubkeys, beaconBalances, withdrawnBalances, balanceProofs);
  }

  /**
   * @notice fallback functions
   */

  receive() external payable {}
}
