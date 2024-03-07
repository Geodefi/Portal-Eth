// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {IPortal} from "../../../interfaces/IPortal.sol";
import {WithdrawalModuleStorage} from "../../../modules/WithdrawalModule/structs/storage.sol";
import {StakeModule} from "../../../modules/StakeModule/StakeModule.sol";
import {StakeModuleLib} from "../../../modules/StakeModule/libs/StakeModuleLib.sol";
import {WithdrawalModule} from "../../../modules/WithdrawalModule/WithdrawalModule.sol";
import {WithdrawalModuleLib} from "../../../modules/WithdrawalModule/libs/WithdrawalModuleLib.sol";
import {InitiatorExtensionLib} from "../../../modules/StakeModule/libs/InitiatorExtensionLib.sol";
import {OracleExtensionLib} from "../../../modules/StakeModule/libs/OracleExtensionLib.sol";
import {DataStoreModuleLib} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";

contract WithdrawalModuleLibMock is WithdrawalModule {
  using WithdrawalModuleLib for WithdrawalModuleStorage;

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

  function claimInfrastructureFees(
    address receiver
  ) external virtual override(WithdrawalModule) returns (bool success) {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    (address governance, , , , ) = IPortal($.PORTAL).GeodeParams();
    require(msg.sender == governance);

    uint256 claimable = $.gatheredInfrastructureFees;

    (success, ) = payable(receiver).call{value: claimable}("");
    require(success, "SML:Failed to send ETH");
  }

  function setExitThreshold(uint256 newThreshold) external virtual override(WithdrawalModule) {
    _getWithdrawalModuleStorage().setExitThreshold(newThreshold);
  }

  function $getWithdrawalParams()
    external
    view
    returns (
      address gETH,
      address PORTAL,
      uint256 POOL_ID,
      uint256 EXIT_THRESHOLD,
      uint256 gatheredInfrastructureFees
    )
  {
    gETH = address(_getWithdrawalModuleStorage().gETH);
    PORTAL = _getWithdrawalModuleStorage().PORTAL;
    POOL_ID = _getWithdrawalModuleStorage().POOL_ID;
    EXIT_THRESHOLD = _getWithdrawalModuleStorage().EXIT_THRESHOLD;
    gatheredInfrastructureFees = _getWithdrawalModuleStorage().gatheredInfrastructureFees;
  }

  function $getValidatorData(
    bytes memory pubkey
  ) external view returns (uint256 beaconBalance, uint256 withdrawnBalance, uint256 poll) {
    beaconBalance = _getWithdrawalModuleStorage().validators[pubkey].beaconBalance;
    withdrawnBalance = _getWithdrawalModuleStorage().validators[pubkey].withdrawnBalance;
    poll = _getWithdrawalModuleStorage().validators[pubkey].poll;
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
    requested = _getWithdrawalModuleStorage().queue.requested;
    realized = _getWithdrawalModuleStorage().queue.realized;
    realizedEtherBalance = _getWithdrawalModuleStorage().queue.realizedEtherBalance;
    realizedPrice = _getWithdrawalModuleStorage().queue.realizedPrice;
    fulfilled = _getWithdrawalModuleStorage().queue.fulfilled;
    fulfilledEtherBalance = _getWithdrawalModuleStorage().queue.fulfilledEtherBalance;
    commonPoll = _getWithdrawalModuleStorage().queue.commonPoll;
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
    require(index < _getWithdrawalModuleStorage().requests.length, "WMLM: index exceeds length");
    realIndex = _getWithdrawalModuleStorage().requests.length - 1 - index;
    owner = _getWithdrawalModuleStorage().requests[realIndex].owner;
    trigger = _getWithdrawalModuleStorage().requests[realIndex].trigger;
    size = _getWithdrawalModuleStorage().requests[realIndex].size;
    fulfilled = _getWithdrawalModuleStorage().requests[realIndex].fulfilled;
    claimableEther = _getWithdrawalModuleStorage().requests[realIndex].claimableEther;
  }

  function $getValidatorThreshold(
    bytes memory pubkey
  ) external view returns (uint256 threshold, uint256 beaconBalancePriced) {
    (threshold, beaconBalancePriced) = _getWithdrawalModuleStorage().getValidatorThreshold(pubkey);
  }

  function $setMockValidatorData(
    bytes memory pubkey,
    uint256 beaconBalance,
    uint256 withdrawnBalance,
    uint256 poll
  ) external {
    _getWithdrawalModuleStorage().validators[pubkey].beaconBalance = beaconBalance;
    _getWithdrawalModuleStorage().validators[pubkey].withdrawnBalance = withdrawnBalance;
    _getWithdrawalModuleStorage().validators[pubkey].poll = poll;
  }

  function $setMockQueueData(
    uint256 requested,
    uint256 realized,
    uint256 fulfilled,
    uint256 realizedEtherBalance,
    uint256 realizedPrice,
    uint256 commonPoll
  ) external {
    _getWithdrawalModuleStorage().queue.requested = requested;
    _getWithdrawalModuleStorage().queue.realized = realized;
    _getWithdrawalModuleStorage().queue.fulfilled = fulfilled;
    _getWithdrawalModuleStorage().queue.realizedEtherBalance = realizedEtherBalance;
    _getWithdrawalModuleStorage().queue.realizedPrice = realizedPrice;
    _getWithdrawalModuleStorage().queue.commonPoll = commonPoll;
  }

  function $canFinalizeExit(bytes memory pubkey) external view returns (bool) {
    return _getWithdrawalModuleStorage().canFinalizeExit(pubkey);
  }

  function $checkAndRequestExit(
    bytes calldata pubkey,
    uint256 commonPoll
  ) external returns (uint256) {
    return _getWithdrawalModuleStorage()._checkAndRequestExit(pubkey, commonPoll);
  }

  function $_vote(bytes calldata pubkey, uint256 size) external {
    _getWithdrawalModuleStorage()._vote(pubkey, size);
  }

  function $_enqueue(uint256 trigger, uint256 size, address owner) external {
    _getWithdrawalModuleStorage()._enqueue(trigger, size, owner);
  }

  function $enqueueBatch(
    uint256[] calldata sizes,
    bytes[] calldata pubkeys,
    address owner
  ) external {
    _getWithdrawalModuleStorage().enqueueBatch(sizes, pubkeys, owner);
  }

  function $enqueue(uint256 size, bytes calldata pubkey, address owner) external {
    _getWithdrawalModuleStorage().enqueue(size, pubkey, owner);
  }

  function $transferRequest(uint256 index, address newOwner) external {
    _getWithdrawalModuleStorage().transferRequest(index, newOwner);
  }

  function $fulfillable(
    uint256 index,
    uint256 Qrealized,
    uint256 Qfulfilled
  ) external view returns (uint256) {
    return _getWithdrawalModuleStorage().fulfillable(index, Qrealized, Qfulfilled);
  }

  function $fulfill(uint256 index) external {
    _getWithdrawalModuleStorage().fulfill(index);
  }

  function $fulfillBatch(uint256[] calldata indexes) external {
    _getWithdrawalModuleStorage().fulfillBatch(indexes);
  }

  function $_dequeue(uint256 index) external returns (uint256 claimableETH) {
    return _getWithdrawalModuleStorage()._dequeue(index);
  }

  function $dequeue(uint256 index, address receiver) external {
    _getWithdrawalModuleStorage().dequeue(index, receiver);
  }

  function $dequeueBatch(uint256[] calldata indexes, address receiver) external {
    _getWithdrawalModuleStorage().dequeueBatch(indexes, receiver);
  }

  function $_realizeProcessedEther(uint256 processedBalance) external {
    _getWithdrawalModuleStorage()._realizeProcessedEther(processedBalance);
  }

  function $_distributeFees(
    bytes memory pubkey,
    uint256 reportedWithdrawn,
    uint256 processedWithdrawn
  ) external returns (uint256 extra) {
    extra = _getWithdrawalModuleStorage()._distributeFees(
      _getWithdrawalModuleStorage()._getPortal().getValidator(pubkey),
      reportedWithdrawn,
      processedWithdrawn
    );
  }

  function $processValidators(
    bytes[] calldata pubkeys,
    uint256[] calldata beaconBalances,
    uint256[] calldata withdrawnBalances,
    bytes32[][] calldata balanceProofs
  ) external {
    _getWithdrawalModuleStorage().processValidators(
      pubkeys,
      beaconBalances,
      withdrawnBalances,
      balanceProofs
    );
  }

  /**
   * @notice fallback functions
   */

  receive() external payable {}
}
