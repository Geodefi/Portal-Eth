// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {PERCENTAGE_DENOMINATOR, gETH_DENOMINATOR} from "../../../globals/macros.sol";
import {VALIDATOR_STATE} from "../../../globals/validator_state.sol";
// libraries
import {DepositContractLib as DCL} from "../../StakeModule/libs/DepositContractLib.sol";
import {StakeModuleLib as SML} from "../../StakeModule/libs/StakeModuleLib.sol";
// interfaces
import {IgETH} from "../../../interfaces/IgETH.sol";
import {IPortal} from "../../../interfaces/IPortal.sol";
// external
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title WML: Withdrawal Module Library
 *
 * @notice Improved validator withdrawals (and exits), while preserving the validator segregation.
 *
 * @notice Intended implementation scope:
 * 1. Processing the withdrawals (partial and exits).
 * * `processValidators` function handles any balance changes that is reflected from the Beacon Chain.
 * * If a validator's balance on the Beacon Chain is ZERO, it exited (forced or voluntary).
 *
 * 2. Distributing the fees.
 * * Pool and Operator fees are distributed whenever the validator is processed.
 * * Note that if the validator is slashed before being processed, fees can be lost along with the stakers' profit.
 * * TODO: governanceFee.
 *
 * 3. Queueing withdrawal requests.
 * * Users can request a withdrawal by forfeiting their gETH tokens.
 * * Requests would be put in a queue (First-In-First-Out).
 * * As the validators are processed, requests become claimable.
 * * Users can dequeue partially or fully.
 *
 * 4. Allowing (Instant Run-off) elections on which validators to exit.
 * * While getting into the queue, caller can vote on a validator, increasing it's 'poll'.
 * * If a validator is not specified, vote goes to 'commonPoll'. It can be used for any validator to top-up the EXIT_THRESHOLD
 * * If a validator is called for exit but there are remaining votes in it, it is transferred to the commonPoll.
 * * Note that, elections are basically just stating a preference:
 * * * Exit of the voted validator does not change the voter's priority in the queue.
 *
 * @dev The Queue
 * Lets say every '-' is representing 1 gETH.
 * Queue: --- -- ---------- -- --- --- - --- -- ---- ----- - ------- ---- -- -- - - -------- --
 * There are 20 requests in this queue, adding up to 65 gETH, this is 'requested'.
 * Every request has a 'size', first request' is 3 gETH , second' is 2 gETH.
 * Every request has a 'trigger', pointing it's kickoff point. Thus, 3rd request' is 5 gETH.
 * Let's say, there are 8 ETH processed in the contract, we burn 8 ETH worth of gETH.
 * Let's say 8 ETH is 4 gETH. Then the first request can exit fully, and second one can exit for 1 gETH.
 *
 * @dev This process creates a unique question:
 * Considering that profit processing, price updates and queue operations are ASYNC,
 * how can we make sure that we are paying the correct price?
 * We have determined 3 possible points that we can 'derisk' a Request:
 * Enqueue -> ProcessValidators -> Dequeue
 * 1. We derisk the Request when it is enqueued:
 * * This would cause 2 issues:
 * * a. Best case, we would prevent the queued Request from profiting while they are in the queue.
 * * b. Since there is a slashing risk, we can not promise a fixed Ether amount without knowing what would be the future price.
 * 2. We derisk the Request when validators are processed, with the latest price for the derivative:
 * * This is the correct approach as we REALIZE the price at this exact point: by increasing the cumulative claimable gETH.
 * * However, we would need to insert an 'unbound for loop' through 'realized' Requests, when a 'processValidators' operation is finalized.
 * * We can not, nor should, enforce an 'unbound for loop' on requests array.
 * 3. We derisk the Request when it is dequeued:
 * * Simply, price changes would have unpredictable effects on the Queue: A request can be claimable now, but might become unclaimable later.
 * * Derisked Requests that are waiting to be claimed, would hijack the real stakers' APR, while sitting on top of some allocated Ether.
 * * Unclaimed Requests can prevent the latter requests since there would be no way to keep track of the previous unclaimed requests without enforcing the order.
 * We do not want to promise vague returns, we do not want for loops over requests array or price checkpoints, we do not want APR hijacking.
 * Thus, none of these points can be implemented without utilizing a trusted third party, like an Oracle.
 * However, we want Withdrawal logic to have the minimum Third Party risk as Geode Developers.
 * As a result, we have came up with a logic that will allow stakers to maintain their profitability without disrupting the 'derisk' moment.
 * * a. We keep track of an internal price, stating the ratio of the claimable ETH and processed gETH: realizedPrice.
 * * b. We derisk the Queue on 'processValidators' by increasing the cumulative gETH that can be claimed.
 * * * We also adjust the realizedPrice considering the pricePerShare of the currently derisked asset amount.
 * * c. Requests can be fulfilled in respect to the internal price BY ANYONE at any point after they become claimable.
 * * d. Fulfilled requests, including partially fulfilled ones, can be claimed (ONLY) BY THE OWNER.
 * Why using an internal Price instead of 'enforcing the PricePerShare' makes sense:
 * * All Requests, without considering their index, are in the same pool until they are derisked through price processing.
 * * If all of the claimable requests are fulfilled periodically (via a script etc.), we would expect internal price to be equal to 'PricePerShare'.
 * * This way, a well maintained pool can prevent APR hijacking by fulfilling neglected Requests, while it is not enforced for all of the pools.
 * However, this is a gas-heavy process so it might not be needed after every 'processValidators' operation.
 * Similarly, 'processValidators' is expensive as well, we would advise calling it when there is a dequeue opportunity.
 * As a conclusion, if all requests are fulfilled immediately after the off-chain calculation signals them being claimable;
 * None of these approaches will be expensive, nor will disrupt the internal pricing for the latter requests.
 *
 * @dev while conducting the price calculations, a part of the balance within this contract should be taken into consideration.
 * This balance can be calculated as: sum(lambda x: requests[x].withdrawnBalance) - realizedBalance
 *
 * @dev Contracts relying on this library must initialize WithdrawalModuleLib.PooledWithdrawal
 *
 * @dev There are 'owner' checks on 'transferRequest', _dequeue (used by dequeue, dequeueBatch).
 * However, we preferred to not use a modifier for that.
 *
 * @dev all parameters related to balance are denominated in gETH; except realizedBalance and claimableETH:
 * (requested, realized, fulfilled, commonPoll, trigger, size, fulfilled)
 * @author Ice Bear & Crash Bandicoot
 */
library WithdrawalModuleLib {
  /**
   * @custom:section                           ** STRUCTS **
   */

  /**
   * @param requested cumulative size of all requests, as in gETH.
   * ex: --- ------ ------ - - --- : 20 : there are 6 requests totaling up to 20 gETH.
   * @param realized cumulative size of gETH that is processed and can be used to fulfill Requests, as in gETH
   * ex: ----- -- -- - ----- --    : 17 : there are 17 gETH, processed as a response to the withdrawn funds.
   * @param fulfilled cumulative size of the fulfilled requests, claimed or claimable, as in gETH
   * ex: --- ----xx ------ x - ooo : 14 : there are 15 gETH being used to fulfill requests,including one that is partially filled. 3 gETH is still claimable.
   * @param realizedBalance cumulative size of the withdrawn and realized balances. Note that, (realizedBalance * realizedPrice != realized) as price changes constantly.
   * @param realizedPrice current Price of the queue, used when fulfilling a Request, updated with processValidators.
   * @param commonPoll current size of requests that did not vote on any specific validator, as in gETH.
   **/
  struct Queue {
    uint256 requested;
    uint256 realized;
    uint256 fulfilled;
    uint256 realizedBalance;
    uint256 realizedPrice;
    uint256 commonPoll;
  }

  /**
   * @param owner the address that can dequeue the request. Ownership can be transferred.
   * @param trigger cumulative sum of the previous requests, as in gETH.
   * @param size size of the withdrawal request, as in gETH.
   * @param fulfilled part of the 'size' that became available after being processed relative to the 'realizedPrice'. as in gETH.
   * @param claimableETH current ETH amount that can be claimed by the Owner, increased in respect to 'fulfilled' and 'realizedPrice', decreased with dequeue.
   **/
  struct Request {
    address owner;
    uint256 trigger;
    uint256 size;
    uint256 fulfilled;
    uint256 claimableETH;
  }

  /**
   * @param beaconBalance  Beacon Chain balance of the validator (current).
   * @param withdrawnBalance  Representing any Ether sent from Beacon Chain to a withdrawal contract (cumulative).
   * @param poll size of the requests that specifically voted for given validator to exit. as in gETH.
   **/
  struct ValidatorData {
    uint256 beaconBalance;
    uint256 withdrawnBalance;
    uint256 poll;
  }

  /**
   * @param gETH constant, ERC1155, all Geode Staking Derivatives.
   * @param PORTAL constant, address of the PORTAL.
   * @param POOL_ID constant, ID of the pool, also the token ID of represented gETH.
   * @param EXIT_THRESHOLD variable, current exit threshold that is set by the owner.
   * @param queue main variables related to Enqueue-Dequeue operations.
   * @param requests an array of requests
   * @param validators as pubkey being the key, the related data for the validators of the given pool. Updated on processValidators.
   **/
  struct PooledWithdrawal {
    IgETH gETH;
    IPortal PORTAL;
    uint256 POOL_ID;
    uint256 EXIT_THRESHOLD;
    Queue queue;
    Request[] requests;
    mapping(bytes => ValidatorData) validators;
    uint256[9] __gap;
  }

  /**
   * @custom:section                           ** CONSTANTS **
   */
  /// @notice EXIT_THRESHOLD should be at least 60% and at most 100%
  uint256 internal constant MIN_EXIT_THRESHOLD = (6 * PERCENTAGE_DENOMINATOR) / 10;
  // minimum withdrawal request is 0.05 ETH
  uint256 internal constant MIN_REQUEST_SIZE = 5e16;

  /**
   * @custom:section                           ** EVENTS **
   */
  event NewExitThreshold(uint256 threshold);
  event Enqueue(uint256 indexed index, address owner);
  event RequestTransfer(uint256 indexed index, address oldOwner, address newOwner);
  event Dequeue(uint256 indexed index, uint256 claim);

  /**
   * @custom:section                           ** EARLY EXIT REQUESTS **
   */

  /**
   * @custom:visibility -> view
   */
  /**
   * @notice checks if given validator is exited, according to the information provided by Balances Merkle Root.
   * @dev an external view function, just as an helper.
   */
  function canFinalizeExit(
    PooledWithdrawal storage self,
    bytes memory pubkey
  ) external view returns (bool) {
    if (self.validators[pubkey].beaconBalance != 0) {
      return false;
    }

    SML.Validator memory val = self.PORTAL.getValidator(pubkey);
    if (val.state != VALIDATOR_STATE.ACTIVE && val.state != VALIDATOR_STATE.EXIT_REQUESTED) {
      return false;
    }

    return true;
  }

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice notifies Portal to change validator state from ACTIVE to EXIT_REQUESTED
   * @param pubkey public key of the given validator.
   */
  function _requestExit(PooledWithdrawal storage self, bytes memory pubkey) internal {
    self.PORTAL.requestExit(self.POOL_ID, pubkey);
  }

  /**
   * @notice notifies Portal to change validator state from ACTIVE or EXIT_REQUESTED, to EXITED.
   * @dev no additional checks are needed as processValidators and PORTAL.finalizeExit has propser checks.
   * @param pubkey public key of the given validator.
   */
  function _finalizeExit(PooledWithdrawal storage self, bytes memory pubkey) internal {
    self.PORTAL.finalizeExit(self.POOL_ID, pubkey);
  }

  /**
   * @notice if the poll is above the threshold, calls Portal to request a voluntary exit.
   * @param pubkey public key of the checked validator.
   * @param commonPoll cached commonPoll
   * @dev passing commonPoll around helps on gas on batch TXs.
   */
  function checkAndRequestExit(
    PooledWithdrawal storage self,
    bytes calldata pubkey,
    uint256 commonPoll
  ) public returns (uint256) {
    uint256 threshold = getValidatorThreshold(self, pubkey);
    uint256 validatorPoll = self.validators[pubkey].poll;

    if (commonPoll + validatorPoll > threshold) {
      // meaning it can request withdrawal
      if (validatorPoll > threshold) {
        commonPoll += validatorPoll - threshold;
      } else if (threshold > validatorPoll) {
        commonPoll -= threshold - validatorPoll;
      }

      _requestExit(self, pubkey);
    }

    return commonPoll;
  }

  /**
   * @custom:visibility -> external
   */
  /**
   * @notice allowing EXIT_THRESHOLD to be set by the contract owner.
   * @param newThreshold as percentage, denominated in PERCENTAGE_DENOMINATOR.
   * @dev caller should be governed on module contract.
   */
  function setExitThreshold(PooledWithdrawal storage self, uint256 newThreshold) external {
    require(newThreshold >= MIN_EXIT_THRESHOLD, "WML:min threshold is 60%");
    require(newThreshold <= PERCENTAGE_DENOMINATOR, "WML:max threshold is 100%");

    self.EXIT_THRESHOLD = newThreshold;
    emit NewExitThreshold(newThreshold);
  }

  /**
   * @custom:subsection                           ** VOTE **
   */

  /**
   * @custom:visibility -> view
   */
  /**
   * @notice figuring out the applied exit threshold, as in gETH, for a given validator.
   * @param pubkey public key of the given validator.
   */
  function getValidatorThreshold(
    PooledWithdrawal storage self,
    bytes calldata pubkey
  ) public view returns (uint256 threshold) {
    uint256 threshold_ETH = (self.validators[pubkey].beaconBalance * self.EXIT_THRESHOLD) /
      PERCENTAGE_DENOMINATOR;

    uint256 price = self.gETH.pricePerShare(self.POOL_ID);
    threshold = (((threshold_ETH * gETH_DENOMINATOR) / price));
  }

  /**
   * @custom:visibility -> internal
   */
  /**
   * @notice a validator is chosen to be the next exit by enqueued Request
   * @param pubkey public key of the voted validator.
   * @param size specified gETH amount
   */
  function _vote(PooledWithdrawal storage self, bytes calldata pubkey, uint256 size) internal {
    SML.Validator memory val = self.PORTAL.getValidator(pubkey);

    require(val.poolId == self.POOL_ID, "SML:vote for an unknown pool");
    require(val.state == VALIDATOR_STATE.ACTIVE, "SML:voted for inactive validator");

    self.validators[pubkey].poll += size;
  }

  /**
   * @custom:section                           ** REQUESTS QUEUE **
   */

  /**
   * @custom:subsection                        ** ENQUEUE **
   */
  /**
   * @custom:visibility -> internal
   */
  /**
   * @notice internal function to push a new Request into Queue
   * @param trigger the kickoff point for the Request
   * @param size specified gETH amount
   */
  function _enqueue(
    PooledWithdrawal storage self,
    uint256 trigger,
    uint256 size,
    address owner
  ) internal {
    require(size >= MIN_REQUEST_SIZE, "WML:min 0.01 gETH");
    require(owner != address(0), "WML:owner can not be zero address");

    self.requests.push(
      Request({owner: owner, trigger: trigger, size: size, fulfilled: 0, claimableETH: 0})
    );

    emit Enqueue(self.requests.length - 1, owner);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice queues a Request into Queue, processes the vote, exits the validator in case of a run-off.
   * @param pubkey voted validator, vote goes into commonPoll if bytes(0) is given.
   * @param owner allows caller to directly transfer the Request on creation
   */
  function enqueue(
    PooledWithdrawal storage self,
    uint256 size,
    bytes calldata pubkey,
    address owner
  ) external {
    uint256 requestedgETH = self.queue.requested;
    _enqueue(self, requestedgETH, size, owner);

    if (pubkey.length == 0) {
      self.queue.commonPoll += size;
    } else {
      _vote(self, pubkey, size);
      self.queue.commonPoll = checkAndRequestExit(self, pubkey, self.queue.commonPoll);
    }

    self.queue.requested = requestedgETH + size;

    self.gETH.safeTransferFrom(msg.sender, address(this), self.POOL_ID, size, "");
  }

  /**
   * @notice enqueue() with batch optimizations
   * @param sizes array of gETH amount that are sent to enqueue multiple Requests.
   * @param pubkeys array of voted validators, vote goes into commonPoll if bytes(0) is given.
   * @param owner the owner for all the Requests being created
   * @dev TODO:  create and use _requestExitBatch to save gas
   */
  function enqueueBatch(
    PooledWithdrawal storage self,
    uint256[] calldata sizes,
    bytes[] calldata pubkeys,
    address owner
  ) external {
    uint256 len = sizes.length;
    require(len == pubkeys.length, "WML:invalid input length");

    uint256 commonPoll = self.queue.commonPoll;
    uint256 requestedgETH = self.queue.requested;
    uint256 totalSize;

    for (uint256 i; i < len; ) {
      _enqueue(self, requestedgETH, sizes[i], owner);

      if (pubkeys[i].length == 0) {
        commonPoll += sizes[i];
      } else {
        _vote(self, pubkeys[i], sizes[i]);
        commonPoll = checkAndRequestExit(self, pubkeys[i], commonPoll);
      }
      requestedgETH = requestedgETH + sizes[i];
      totalSize += sizes[i];

      unchecked {
        i += 1;
      }
    }

    self.queue.commonPoll = commonPoll;
    self.queue.requested = requestedgETH;

    self.gETH.safeTransferFrom(msg.sender, address(this), self.POOL_ID, totalSize, "");
  }

  /**
   * @notice transferring the ownership of a Request to a new address
   * @param index placement of the Request within the requests array.
   * @param newOwner new address that will be eligible to dequeue a Request.
   * @dev only current Owner can change the owner
   */
  function transferRequest(
    PooledWithdrawal storage self,
    uint256 index,
    address newOwner
  ) external {
    address oldOwner = self.requests[index].owner;
    require(msg.sender == oldOwner, "WML:not owner");
    require(newOwner != address(0), "WML:cannot transfer to zero address");

    self.requests[index].owner = newOwner;

    emit RequestTransfer(index, oldOwner, newOwner);
  }

  /**
   * @custom:subsection                        ** FULFILL **
   */
  /**
   * @custom:visibility -> view
   */
  /**
   * @notice given a request, figure out the fulfillable gETH amount, limited up to its size.
   * @param index placement of the Request within the requests array.
   * @param qRealized self.queue.realized, might also be hot value for Batch optimizations
   * @param qFulfilled self.queue.fulfilled, might also be a hot value for Batch optimizations
   * @dev taking the previously fulfilled amount into consideration as it is the previously claimed part.
   */
  function fulfillable(
    PooledWithdrawal storage self,
    uint256 index,
    uint256 qRealized,
    uint256 qFulfilled
  ) public view returns (uint256) {
    if (qRealized > qFulfilled) {
      uint256 rTrigger = self.requests[index].trigger;
      uint256 rSize = self.requests[index].size;
      uint256 rFulfilled = self.requests[index].fulfilled;

      uint256 rFloor = rTrigger + rFulfilled;
      uint256 rCeil = rTrigger + rSize;

      if (qRealized > rCeil) {
        return rSize - rFulfilled;
      } else if (qRealized > rFloor) {
        return qRealized - rFloor;
      } else {
        return 0;
      }
    } else {
      return 0;
    }
  }

  /**
   * @custom:visibility -> internal
   */
  /**
   * @notice by using the realized size that is burned, we fulfill a single request by making use of the internal pricing.
   */
  function _fulfill(PooledWithdrawal storage self, uint256 index) internal {
    uint256 toFulfill = fulfillable(self, index, self.queue.realized, self.queue.fulfilled);
    if (toFulfill > 0) {
      self.requests[index].claimableETH +=
        (toFulfill * self.queue.realizedPrice) /
        gETH_DENOMINATOR;
      self.requests[index].fulfilled += toFulfill;
      self.queue.fulfilled += toFulfill;
    }
  }

  /**
   * @notice _fulfill with Batch optimizations
   * @param qRealized queue.realized, as a hot value.
   * @param qFulfilled queue.fulfilled, as a hot value.
   * @param qPrice queue.realizedPrice, as a hot value.
   */
  function _fulfillBatch(
    PooledWithdrawal storage self,
    uint256[] calldata indexes,
    uint256 qRealized,
    uint256 qFulfilled,
    uint256 qPrice
  ) internal {
    uint256 indexesLen = indexes.length;
    for (uint256 i; i < indexesLen; ) {
      uint256 toFulfill = fulfillable(self, indexes[i], qRealized, qFulfilled);
      if (toFulfill > 0) {
        self.requests[indexes[i]].claimableETH += (toFulfill * qPrice) / gETH_DENOMINATOR;
        self.requests[indexes[i]].fulfilled += toFulfill;
        qFulfilled += toFulfill;
      }

      unchecked {
        i += 1;
      }
    }
    self.queue.fulfilled = qFulfilled;
  }

  /**
   * @custom:visibility -> external
   */
  function fulfill(PooledWithdrawal storage self, uint256 index) external {
    _fulfill(self, index);
  }

  function fulfillBatch(PooledWithdrawal storage self, uint256[] calldata indexes) external {
    _fulfillBatch(
      self,
      indexes,
      self.queue.realized,
      self.queue.fulfilled,
      self.queue.realizedPrice
    );
  }

  /**
   * @custom:subsection                        ** DEQUEUE **
   */

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice given a Request from the requests array, remove the part that is currently claimable.
   * @param index placement of the Request within the requests array.
   * @dev only owner can call this function
   */
  function _dequeue(
    PooledWithdrawal storage self,
    uint256 index
  ) internal returns (uint256 claimableETH) {
    require(msg.sender == self.requests[index].owner, "WML:not owner");

    claimableETH = self.requests[index].claimableETH;
    require(claimableETH > 0, "WML:not claimable");

    self.requests[index].claimableETH = 0;

    emit Dequeue(index, claimableETH);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice given a Request from the requests array, claim the part that is currently claimable and forward the ether amount to the given receiver.
   * @param index placement of the Request within the requests array.
   * @dev only owner can call this function
   */
  function dequeue(PooledWithdrawal storage self, uint256 index, address receiver) external {
    require(receiver != address(0), "WML:receiver can not be zero address");

    _fulfill(self, index);
    uint256 claimableETH = _dequeue(self, index);

    // send ETH
    (bool sent, ) = payable(receiver).call{value: claimableETH}("");
    require(sent, "WML:Failed to send Ether");
  }

  /**
   * @notice dequeue() with batch optimizations
   * @dev we burn the realized size of the Queue here because we do not want this process to mess with price
   * * calculations of the oracle.
   */
  function dequeueBatch(
    PooledWithdrawal storage self,
    uint256[] calldata indexes,
    address receiver
  ) external {
    require(receiver != address(0), "WML:receiver can not be zero address");

    _fulfillBatch(
      self,
      indexes,
      self.queue.realized,
      self.queue.fulfilled,
      self.queue.realizedPrice
    );

    uint256 claimableETH;
    uint256 indexesLen = indexes.length;
    for (uint256 i; i < indexesLen; ) {
      claimableETH += _dequeue(self, indexes[i]);

      unchecked {
        i += 1;
      }
    }

    // send ETH
    (bool sent, ) = payable(receiver).call{value: claimableETH}("");
    require(sent, "WML:Failed to send Ether");
  }

  /**
   * @custom:section                           ** PROCESS BALANCES MERKLE UPDATE **
   */

  /**
   * @custom:visibility -> internal
   */
  /**
   * @notice
   * @param pubkey public key of the given validator.
   * @param reportedWithdrawn withdrawn Ether amount according to the fresh Merkle root.
   * @param processedWithdrawn previously reported withdrawn amount.
   * @dev can not overflow since max fee is 10%, if we change fee structure ever, we need to reconsider the math there! 
   * * Note that if a validator is EXITED, we would assume 32 ETH that the pool put is also accounted for.
   @return extra calculated profit since the last time validator was processed
   */
  function _distributeFees(
    PooledWithdrawal storage self,
    bytes memory pubkey,
    uint256 reportedWithdrawn,
    uint256 processedWithdrawn
  ) internal returns (uint256 extra) {
    if (reportedWithdrawn > processedWithdrawn) {
      uint256 profit = reportedWithdrawn - processedWithdrawn;
      SML.Validator memory val = self.PORTAL.getValidator(pubkey);

      uint256 poolProfit = (profit * val.poolFee) / PERCENTAGE_DENOMINATOR;
      uint256 operatorProfit = (profit * val.operatorFee) / PERCENTAGE_DENOMINATOR;
      extra = (profit - poolProfit) - operatorProfit;

      self.PORTAL.increaseWalletBalance{value: poolProfit}(val.poolId);
      self.PORTAL.increaseWalletBalance{value: operatorProfit}(val.operatorId);
    }
  }

  /**
   * @notice acting like queue is one entity, we sell it some gETH in respect to Oracle price.
   * * by using the Ether from the latest withdrawals.
   */
  function _realizeProcessedEther(
    PooledWithdrawal storage self,
    uint256 processedBalance
  ) internal {
    uint256 pps = self.gETH.pricePerShare(self.POOL_ID);

    uint256 processedgETH = ((processedBalance * gETH_DENOMINATOR) / pps);
    uint256 newPrice = pps;

    uint256 internalPrice = self.queue.realizedPrice;
    if (internalPrice > 0) {
      uint256 claimable = self.queue.realized - self.queue.fulfilled;
      if (claimable > 0) {
        newPrice =
          ((claimable * internalPrice) + (processedBalance * gETH_DENOMINATOR)) /
          (claimable + processedgETH);
      }
    }

    self.queue.realized += processedgETH;
    self.queue.realizedBalance += processedBalance;
    self.queue.realizedPrice = newPrice;

    // burn gETH
    self.gETH.burn(address(this), self.POOL_ID, processedgETH);
  }

  /**
   * @custom:visibility -> external
   */
  /**
   * @notice main function of this library, processing given information about the provided validators.
   * @dev not all validators need to be processed all the time, process them as you need.
   * @dev We do NOT check if validators should be processed at all.
   * Because its up to user if they want to pay extra for unnecessary operations.
   * We should not be charging others extra to save their gas.
   */
  function processValidators(
    PooledWithdrawal storage self,
    bytes[] calldata pubkeys,
    uint256[] calldata beaconBalances,
    uint256[] calldata withdrawnBalances,
    bytes32[][] calldata balanceProofs
  ) external {
    uint256 pkLen = pubkeys.length;
    require(
      pkLen == beaconBalances.length &&
        pkLen == withdrawnBalances.length &&
        pkLen == balanceProofs.length,
      "WML:invalid lengths"
    );

    bytes32 balanceMerkleRoot = self.PORTAL.getBalancesMerkleRoot();
    for (uint256 i; i < pkLen; ) {
      // verify balances
      bytes32 leaf = keccak256(
        bytes.concat(keccak256(abi.encode(pubkeys[i], beaconBalances[i], withdrawnBalances[i])))
      );
      require(
        MerkleProof.verify(balanceProofs[i], balanceMerkleRoot, leaf),
        "WML:NOT all proofs are valid"
      );

      unchecked {
        i += 1;
      }
    }

    uint256 commonPoll = self.queue.commonPoll;
    uint256 processed;
    for (uint256 j; j < pkLen; ) {
      uint256 oldWitBal = self.validators[pubkeys[j]].withdrawnBalance;

      self.validators[pubkeys[j]].beaconBalance = beaconBalances[j];
      self.validators[pubkeys[j]].withdrawnBalance = withdrawnBalances[j];

      if (beaconBalances[j] == 0) {
        // exit
        processed += _distributeFees(
          self,
          pubkeys[j],
          withdrawnBalances[j],
          oldWitBal + DCL.DEPOSIT_AMOUNT
        );
        _finalizeExit(self, pubkeys[j]);
      } else {
        // check if should request exit
        processed += _distributeFees(self, pubkeys[j], withdrawnBalances[j], oldWitBal);
        commonPoll = checkAndRequestExit(self, pubkeys[j], commonPoll);
      }

      unchecked {
        j += 1;
      }
    }
    self.queue.commonPoll = commonPoll;

    if (processed > 0) {
      _realizeProcessedEther(self, processed);
    }
  }
}
