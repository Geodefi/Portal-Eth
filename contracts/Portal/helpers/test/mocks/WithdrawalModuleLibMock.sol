// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {StakeModule} from "../../../modules/StakeModule/StakeModule.sol";
import {StakeModuleLib} from "../../../modules/StakeModule/libs/StakeModuleLib.sol";
import {WithdrawalModule} from "../../../modules/WithdrawalModule/WithdrawalModule.sol";
import {WithdrawalModuleLib} from "../../../modules/WithdrawalModule/libs/WithdrawalModuleLib.sol";
import {InitiatorExtensionLib} from "../../../modules/StakeModule/libs/InitiatorExtensionLib.sol";
import {OracleExtensionLib} from "../../../modules/StakeModule/libs/OracleExtensionLib.sol";
import {DataStoreModuleLib} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";

contract WithdrawalModuleLibMock is WithdrawalModule {
  using WithdrawalModuleLib for WithdrawalModuleLib.PooledWithdrawal;

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
      uint256 claimableETH
    )
  {
    require(index < WITHDRAWAL.requests.length, "WMLM: index exceeds length");
    realIndex = WITHDRAWAL.requests.length - 1 - index;
    owner = WITHDRAWAL.requests[realIndex].owner;
    trigger = WITHDRAWAL.requests[realIndex].trigger;
    size = WITHDRAWAL.requests[realIndex].size;
    fulfilled = WITHDRAWAL.requests[realIndex].fulfilled;
    claimableETH = WITHDRAWAL.requests[realIndex].claimableETH;
  }

  function $validatorThreshold(bytes memory pubkey) external view returns (uint256) {
    return WITHDRAWAL.getValidatorThreshold(pubkey);
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

  function $_vote(bytes calldata pubkey, uint256 size) external {
    WITHDRAWAL._vote(pubkey, size);
  }

  function $_enqueue(uint256 trigger, uint256 size, address owner) external {
    WITHDRAWAL._enqueue(trigger, size, owner);
  }

  function $transferRequest(uint256 index, address newOwner) external {
    WITHDRAWAL.transferRequest(index, newOwner);
  }

  function $_distributeFees(
    bytes memory pubkey,
    uint256 reportedWithdrawn,
    uint256 processedWithdrawn
  ) external returns (uint256 extra) {
    extra = WITHDRAWAL._distributeFees(pubkey, reportedWithdrawn, processedWithdrawn);
  }
}
