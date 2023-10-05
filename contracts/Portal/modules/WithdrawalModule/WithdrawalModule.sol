// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// interfaces
import {IgETH} from "../../interfaces/IgETH.sol";
import {IPortal} from "../../interfaces/IPortal.sol";
import {IWithdrawalModule} from "../../interfaces/modules/IWithdrawalModule.sol";
// libraries
import {WithdrawalModuleLib as WML, PooledWithdrawal} from "./libs/WithdrawalModuleLib.sol";
// external
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title WM: Withdrawal Module
 *
 * @notice Withdrawal Queue and voluntary exit elections.
 * * Processing the withdrawals
 * * Distributing the fees
 * * Queueing withdrawal requests
 * * Allowing (Instant Run-off) elections on which validators to exit.
 * @dev all done while preserving the validator segregation.
 *
 * @dev There is 1 additional functionality implemented apart from the library:
 * * if the price is not valid, user must prove it before processing validators.
 *
 * @dev review: this module delegates its functionality to WML (WithdrawalModuleLib).
 *
 * @dev 3 functions need to be overriden with access control when inherited:
 * * pause, unpause, setExitThreshold
 *
 * @dev __WithdrawalModule_init (or _unchained) call is NECESSARY when inherited.
 *
 * note This module does not implement necessary admin checks; or pausability overrides.
 * * If a package inherits WM, should implement it's own logic around those.
 *
 * @author Ice Bear & Crash Bandicoot
 */
abstract contract WithdrawalModule is
  IWithdrawalModule,
  ERC1155HolderUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable
{
  using WML for PooledWithdrawal;
  /**
   * @custom:section                           ** VARIABLES **
   *
   * @dev Do not add any other variables here. Modules do NOT have a gap.
   * Library's main struct has a gap, providing up to 16 storage slots for this module.
   */
  PooledWithdrawal internal WITHDRAWAL;

  /**
   * @custom:section                           ** EVENTS **
   */
  event NewExitThreshold(uint256 threshold);
  event Enqueue(uint256 indexed index, address owner);
  event RequestTransfer(uint256 indexed index, address oldOwner, address newOwner);
  event Dequeue(uint256 indexed index, uint256 claim);

  /**
   * @custom:section                           ** ABSTRACT FUNCTIONS **
   *
   * @dev these functions MUST be overriden for admin functionality.
   */

  function pause() external virtual override;

  function unpause() external virtual override;

  function setExitThreshold(uint256 newThreshold) external virtual override;

  /**
   * @custom:section                           ** INITIALIZING **
   */
  function __WithdrawalModule_init(
    address _gETH_position,
    address _portal_position,
    uint256 _poolId
  ) internal onlyInitializing {
    __ReentrancyGuard_init();
    __Pausable_init();
    __ERC1155Holder_init();
    __WithdrawalModule_init_unchained(_gETH_position, _portal_position, _poolId);
  }

  function __WithdrawalModule_init_unchained(
    address _gETH_position,
    address _portal_position,
    uint256 _poolId
  ) internal onlyInitializing {
    require(_gETH_position != address(0), "WM:gETH cannot be zero address");
    require(_portal_position != address(0), "WM:portal cannot be zero address");
    WITHDRAWAL.gETH = IgETH(_gETH_position);
    WITHDRAWAL.PORTAL = IPortal(_portal_position);
    WITHDRAWAL.POOL_ID = _poolId;
    WITHDRAWAL.EXIT_THRESHOLD = WML.MIN_EXIT_THRESHOLD;
  }

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   *
   * @custom:visibility -> view-external
   */
  function WithdrawalParams()
    external
    view
    virtual
    override
    returns (address gETH, address portal, uint256 poolId, uint256 exitThreshold)
  {
    gETH = address(WITHDRAWAL.gETH);
    portal = address(WITHDRAWAL.PORTAL);
    poolId = WITHDRAWAL.POOL_ID;
    exitThreshold = WITHDRAWAL.EXIT_THRESHOLD;
  }

  function QueueParams()
    external
    view
    virtual
    override
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

  function getRequest(
    uint256 index
  )
    external
    view
    virtual
    override
    returns (
      address owner,
      uint256 trigger,
      uint256 size,
      uint256 fulfilled,
      uint256 claimableEther
    )
  {
    owner = WITHDRAWAL.requests[index].owner;
    trigger = WITHDRAWAL.requests[index].trigger;
    size = WITHDRAWAL.requests[index].size;
    fulfilled = WITHDRAWAL.requests[index].fulfilled;
    claimableEther = WITHDRAWAL.requests[index].claimableEther;
  }

  function getValidatorData(
    bytes calldata pubkey
  )
    external
    view
    virtual
    override
    returns (uint256 beaconBalance, uint256 withdrawnBalance, uint256 poll)
  {
    beaconBalance = WITHDRAWAL.validators[pubkey].beaconBalance;
    withdrawnBalance = WITHDRAWAL.validators[pubkey].withdrawnBalance;
    poll = WITHDRAWAL.validators[pubkey].poll;
  }

  /**
   * @custom:section                           ** EARLY EXIT **
   */

  /**
   * @custom:visibility -> view
   */
  function canFinalizeExit(bytes memory pubkey) external view virtual override returns (bool) {
    return WITHDRAWAL.canFinalizeExit(pubkey);
  }

  function validatorThreshold(
    bytes memory pubkey
  ) external view virtual override returns (uint256 threshold) {
    (threshold, ) = WITHDRAWAL.getValidatorThreshold(pubkey);
  }

  /**
   * @custom:visibility -> external
   */
  function checkAndRequestExit(bytes memory pubkey) external virtual override returns (uint256) {
    return WITHDRAWAL.checkAndRequestExit(pubkey, WITHDRAWAL.queue.commonPoll);
  }

  /**
   * @custom:section                           ** REQUESTS QUEUE **
   */
  /**
   * @custom:subsection                        ** ENQUEUE **
   *
   * @custom:visibility -> external
   */

  function enqueue(uint256 size, bytes calldata pubkey, address owner) external virtual override {
    WITHDRAWAL.enqueue(size, pubkey, owner);
  }

  function enqueueBatch(
    uint256[] calldata sizes,
    bytes[] calldata pubkeys,
    address owner
  ) external virtual override {
    WITHDRAWAL.enqueueBatch(sizes, pubkeys, owner);
  }

  function transferRequest(uint256 index, address newOwner) external virtual override {
    WITHDRAWAL.transferRequest(index, newOwner);
  }

  /**
   * @custom:subsection                        ** FULFILL **
   */

  /**
   * @custom:visibility -> view
   */

  function fulfillable(
    uint256 index,
    uint256 Qrealized,
    uint256 Qfulfilled
  ) external view virtual override returns (uint256) {
    return WITHDRAWAL.fulfillable(index, Qrealized, Qfulfilled);
  }

  /**
   * @custom:visibility -> external
   */
  function fulfill(uint256 index) external virtual override {
    WITHDRAWAL.fulfill(index);
  }

  function fulfillBatch(uint256[] calldata indexes) external virtual override {
    WITHDRAWAL.fulfillBatch(indexes);
  }

  /**
   * @custom:subsection                        ** DEQUEUE **
   */
  /**
   * @custom:visibility -> external
   */
  function dequeue(uint256 index, address receiver) external virtual override {
    WITHDRAWAL.dequeue(index, receiver);
  }

  function dequeueBatch(uint256[] calldata indexes, address receiver) external virtual override {
    WITHDRAWAL.dequeueBatch(indexes, receiver);
  }

  /**
   * @custom:section                           ** PROCESS BALANCES MERKLE UPDATE **
   */
  function processValidators(
    bytes[] calldata pubkeys,
    uint256[] calldata beaconBalances,
    uint256[] calldata withdrawnBalances,
    bytes32[][] calldata balanceProofs,
    uint256 price,
    bytes32[] calldata priceProof
  ) external virtual override {
    if (!WITHDRAWAL.PORTAL.isPriceValid(WITHDRAWAL.POOL_ID)) {
      WITHDRAWAL.PORTAL.priceSync(WITHDRAWAL.POOL_ID, price, priceProof);
    }
    WITHDRAWAL.processValidators(pubkeys, beaconBalances, withdrawnBalances, balanceProofs);
  }

  /**
   * @custom:section                           ** MULTICALL **
   */

  /**
   * @dev Receives and executes a batch of function calls on this contract.
   * @dev This is necessary for the multistep operations done in this contract:
   * * Enqueue, Process, Fulfill, Dequeue.
   * @dev Using 'functionDelegateCall' so it does not cause any issues when using msg.sender etc.
   * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
   */
  function multicall(
    bytes[] calldata data
  ) external virtual override returns (bytes[] memory results) {
    results = new bytes[](data.length);
    for (uint256 i; i < data.length; ) {
      results[i] = Address.functionDelegateCall(address(this), data[i]);

      unchecked {
        i += 1;
      }
    }
    return results;
  }
}
