// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

/**
 * @param beaconBalance  Beacon Chain balance of the validator (current).
 * @param withdrawnBalance  Representing any Ether sent from Beacon Chain to a withdrawal package (cumulative).
 * @param poll size of the requests that specifically voted for given validator to exit. as in gETH.
 **/
struct ValidatorData {
  uint256 beaconBalance;
  uint256 withdrawnBalance;
  uint256 poll;
}

/**
 * @param owner the address that can dequeue the request. Ownership can be transferred.
 * @param trigger cumulative sum of the previous requests, as in gETH.
 * @param size size of the withdrawal request, as in gETH.
 * @param fulfilled part of the 'size' that became available after being processed relative to the 'realizedPrice'. as in gETH.
 * @param claimableEther current ETH amount that can be claimed by the Owner, increased in respect to 'fulfilled' and 'realizedPrice', decreased with dequeue.
 **/
struct Request {
  address owner;
  uint256 trigger;
  uint256 size;
  uint256 fulfilled;
  uint256 claimableEther;
}

/**
 * @param requested cumulative size of all requests, as in gETH.
 * ex: --- ------ ------ - - --- : 20 : there are 6 requests totaling up to 20 gETH.
 * @param realized cumulative size of gETH that is processed and can be used to fulfill Requests, as in gETH
 * ex: ----- -- -- - ----- --    : 17 : there are 17 gETH, processed as a response to the withdrawn funds.
 * @param fulfilled cumulative size of the fulfilled requests, claimed or claimable, as in gETH
 * ex: --- ----xx ------ x - ooo : 14 : there are 15 gETH being used to fulfill requests,including one that is partially filled. 3 gETH is still claimable.
 * @param realizedEtherBalance cumulative size of the withdrawn and realized balances. Note that, (realizedEtherBalance * realizedPrice != realized) as price changes constantly.
 * @param fulfilledEtherBalance cumulative size of the fulfilled requests.
 * @param realizedPrice current Price of the queue, used when fulfilling a Request, updated with processValidators.
 * @param commonPoll current size of requests that did not vote on any specific validator, as in gETH.
 **/
struct Queue {
  uint256 requested;
  uint256 realized;
  uint256 realizedEtherBalance;
  uint256 realizedPrice;
  uint256 fulfilled;
  uint256 fulfilledEtherBalance;
  uint256 commonPoll;
}
