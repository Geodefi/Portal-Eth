// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IDataStoreModule} from "./IDataStoreModule.sol";
import {Validator} from "../../modules/StakeModule/structs/utils.sol";

interface IStakeModule is IDataStoreModule {
  function pause() external;

  function unpause() external;

  function setInfrastructureFee(uint256 _type, uint256 fee) external;

  function setBeaconDelays(uint256 entry, uint256 exit) external;

  function setInitiationDeposit(uint256 newInitiationDeposit) external;

  function StakeParams()
    external
    view
    returns (
      address gETH,
      address oraclePosition,
      uint256 validatorsIndex,
      uint256 verificationIndex,
      uint256 monopolyThreshold,
      uint256 beaconDelayEntry,
      uint256 beaconDelayExit,
      uint256 initiationDeposit,
      uint256 oracleUpdateTimestamp,
      uint256 dailyPriceIncreaseLimit,
      uint256 dailyPriceDecreaseLimit
    );

  function getValidator(bytes calldata pubkey) external view returns (Validator memory);

  function getPackageVersion(uint256 _type) external view returns (uint256);

  function getPriceMerkleRoot() external view returns (bytes32);

  function getBalancesMerkleRoot() external view returns (bytes32);

  function isMiddleware(uint256 _type, uint256 _version) external view returns (bool);

  function getInfrastructureFee(uint256 _type) external view returns (uint256);

  function initiateOperator(
    uint256 id,
    uint256 fee,
    uint256 validatorPeriod,
    address maintainer
  ) external payable;

  function deployLiquidityPackage(uint256 poolId) external;

  function initiatePool(
    uint256 fee,
    uint256 middlewareVersion,
    address maintainer,
    bytes calldata NAME,
    bytes calldata middleware_data,
    bool[3] calldata config
  ) external payable returns (uint256 poolId);

  function setPoolVisibility(uint256 poolId, bool makePrivate) external;

  function setWhitelist(uint256 poolId, address whitelist) external;

  function setYieldReceiver(uint256 poolId, address yieldReceiver) external;

  function changeMaintainer(uint256 id, address newMaintainer) external;

  function getMaintenanceFee(uint256 id) external view returns (uint256);

  function switchMaintenanceFee(uint256 id, uint256 newFee) external;

  function increaseWalletBalance(uint256 id) external payable returns (bool);

  function decreaseWalletBalance(uint256 id, uint256 value) external returns (bool);

  function isPrisoned(uint256 operatorId) external view returns (bool);

  function blameExit(
    bytes calldata pk,
    uint256 beaconBalance,
    uint256 withdrawnBalance,
    bytes32[] calldata balanceProof
  ) external;

  function blameProposal(bytes calldata pk) external;

  function getValidatorPeriod(uint256 id) external view returns (uint256);

  function switchValidatorPeriod(uint256 operatorId, uint256 newPeriod) external;

  function setFallbackOperator(
    uint256 poolId,
    uint256 operatorId,
    uint256 fallbackThreshold
  ) external;

  function operatorAllowance(uint256 poolId, uint256 operatorId) external view returns (uint256);

  function delegate(
    uint256 poolId,
    uint256[] calldata operatorIds,
    uint256[] calldata allowances
  ) external;

  function isWhitelisted(uint256 poolId, address staker) external view returns (bool);

  function isPrivatePool(uint256 poolId) external view returns (bool);

  function isPriceValid(uint256 poolId) external view returns (bool);

  function isMintingAllowed(uint256 poolId) external view returns (bool);

  function deposit(
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProof,
    uint256 mingETH,
    uint256 deadline,
    address receiver
  ) external payable returns (uint256 boughtgETH, uint256 mintedgETH);

  function canStake(bytes calldata pubkey) external view returns (bool);

  function proposeStake(
    uint256 poolId,
    uint256 operatorId,
    bytes[] calldata pubkeys,
    bytes[] calldata signatures1,
    bytes[] calldata signatures31
  ) external;

  function stake(uint256 operatorId, bytes[] calldata pubkeys) external;

  function requestExit(uint256 poolId, bytes memory pk) external returns (bool);

  function finalizeExit(uint256 poolId, bytes memory pk) external;

  function updateVerificationIndex(
    uint256 validatorVerificationIndex,
    bytes[] calldata alienatedPubkeys
  ) external;

  function regulateOperators(uint256[] calldata feeThefts, bytes[] calldata proofs) external;

  function reportBeacon(
    bytes32 priceMerkleRoot,
    bytes32 balanceMerkleRoot,
    uint256 allValidatorsCount
  ) external;

  function priceSync(uint256 poolId, uint256 price, bytes32[] calldata priceProof) external;

  function priceSyncBatch(
    uint256[] calldata poolIds,
    uint256[] calldata prices,
    bytes32[][] calldata priceProofs
  ) external;
}
