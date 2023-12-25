// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// external - libraries
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
// external - contracts
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
// internal - interfaces
import {IgETH} from "../../interfaces/IgETH.sol";
import {IPortal} from "../../interfaces/IPortal.sol";
import {IWithdrawalModule} from "../../interfaces/modules/IWithdrawalModule.sol";
// internal - structs
import {WithdrawalModuleStorage} from "./structs/storage.sol";
// internal - libraries
import {WithdrawalModuleLib as WML} from "./libs/WithdrawalModuleLib.sol";

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
 * @dev 4 functions need to be overriden with access control when inherited:
 * * pause, unpause, setExitThreshold, claimInfrastructureFees
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
  ReentrancyGuardUpgradeable,
  PausableUpgradeable
{
  using WML for WithdrawalModuleStorage;
  /**
   * @custom:section                           ** VARIABLES **
   *
   * @dev Do not add any other variables here. Modules do not have a gap.
   * Library's main struct has a gap, providing up to 16 storage slots for this module.
   */
  // keccak256(abi.encode(uint256(keccak256("geode.storage.WithdrawalModuleStorage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant WithdrawalModuleStorageLocation =
    0x50605cc6f5170f0cdbb610edd2214831ea96f61cd1eba92cf58939f65736af00;

  function _getWithdrawalModuleStorage() internal pure returns (WithdrawalModuleStorage storage $) {
    assembly {
      $.slot := WithdrawalModuleStorageLocation
    }
  }

  /**
   * @custom:section                           ** EVENTS **
   */
  event NewExitThreshold(uint256 threshold);
  event Enqueue(uint256 indexed index, address owner);
  event RequestTransfer(uint256 indexed index, address oldOwner, address newOwner);
  event Fulfill(uint256 indexed index, uint256 fulfillAmount, uint256 claimableETH);
  event Dequeue(uint256 indexed index, uint256 claim);

  /**

  /**
   * @custom:section                           ** ABSTRACT FUNCTIONS **
   *
   * @dev these functions MUST be overriden for admin functionality.
   */

  function pause() external virtual override;

  function unpause() external virtual override;

  function setExitThreshold(uint256 newThreshold) external virtual override;

  function claimInfrastructureFees(
    address receiver
  ) external virtual override returns (bool success);

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

    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    $.gETH = IgETH(_gETH_position);
    $.PORTAL = _portal_position;
    $.POOL_ID = _poolId;
    $.EXIT_THRESHOLD = WML.MIN_EXIT_THRESHOLD;

    $.gETH.avoidMiddlewares(_poolId, true);
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
    returns (
      address gETH,
      address portal,
      uint256 poolId,
      uint256 exitThreshold,
      uint256 gatheredInfrastructureFees
    )
  {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    gETH = address($.gETH);
    portal = $.PORTAL;
    poolId = $.POOL_ID;
    exitThreshold = $.EXIT_THRESHOLD;
    gatheredInfrastructureFees = $.gatheredInfrastructureFees;
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
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    requested = $.queue.requested;
    realized = $.queue.realized;
    realizedEtherBalance = $.queue.realizedEtherBalance;
    realizedPrice = $.queue.realizedPrice;
    fulfilled = $.queue.fulfilled;
    fulfilledEtherBalance = $.queue.fulfilledEtherBalance;
    commonPoll = $.queue.commonPoll;
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
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    owner = $.requests[index].owner;
    trigger = $.requests[index].trigger;
    size = $.requests[index].size;
    fulfilled = $.requests[index].fulfilled;
    claimableEther = $.requests[index].claimableEther;
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
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    beaconBalance = $.validators[pubkey].beaconBalance;
    withdrawnBalance = $.validators[pubkey].withdrawnBalance;
    poll = $.validators[pubkey].poll;
  }

  /**
   * @custom:section                           ** EARLY EXIT **
   */

  /**
   * @custom:visibility -> view
   */
  function canFinalizeExit(bytes memory pubkey) external view virtual override returns (bool) {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    return $.canFinalizeExit(pubkey);
  }

  function validatorThreshold(
    bytes memory pubkey
  ) external view virtual override returns (uint256 threshold) {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    (threshold, ) = $.getValidatorThreshold(pubkey);
  }

  /**
   * @custom:section                           ** REQUESTS QUEUE **
   */
  /**
   * @custom:subsection                        ** ENQUEUE **
   *
   * @custom:visibility -> external
   */

  function enqueue(
    uint256 size,
    bytes calldata pubkey,
    address owner
  ) external virtual override returns (uint256 index) {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    index = $.enqueue(size, pubkey, owner);
  }

  function enqueueBatch(
    uint256[] calldata sizes,
    bytes[] calldata pubkeys,
    address owner
  ) external virtual override returns (uint256[] memory indexes) {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    indexes = $.enqueueBatch(sizes, pubkeys, owner);
  }

  function transferRequest(uint256 index, address newOwner) external virtual override {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    $.transferRequest(index, newOwner);
  }

  /**
   * @custom:subsection                        ** FULFILL **
   */

  /**
   * @custom:visibility -> view
   */

  function fulfillable(uint256 index) external view virtual override returns (uint256) {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    return $.fulfillable(index, $.queue.realized, $.queue.fulfilled);
  }

  /**
   * @custom:visibility -> external
   */
  function fulfill(uint256 index) external virtual override {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    $.fulfill(index);
  }

  function fulfillBatch(uint256[] calldata indexes) external virtual override {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    $.fulfillBatch(indexes);
  }

  /**
   * @custom:subsection                        ** DEQUEUE **
   */
  /**
   * @custom:visibility -> external
   */
  function dequeue(uint256 index, address receiver) external virtual override {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    $.dequeue(index, receiver);
  }

  function dequeueBatch(uint256[] calldata indexes, address receiver) external virtual override {
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    $.dequeueBatch(indexes, receiver);
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
    WithdrawalModuleStorage storage $ = _getWithdrawalModuleStorage();
    if (!IPortal($.PORTAL).isPriceValid($.POOL_ID)) {
      IPortal($.PORTAL).priceSync($.POOL_ID, price, priceProof);
    }
    $.processValidators(pubkeys, beaconBalances, withdrawnBalances, balanceProofs);
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
