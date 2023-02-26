// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../Portal/utils/DataStoreUtilsLib.sol";
import "../Portal/utils/GeodeUtilsLib.sol";
import "../Portal/utils/OracleUtilsLib.sol";
import "../Portal/utils/StakeUtilsLib.sol";

interface IPortal {
  function initialize(
    address _GOVERNANCE,
    address _SENATE,
    address _gETH,
    address _ORACLE_POSITION,
    address _DEFAULT_WITHDRAWAL_CONTRACT_MODULE,
    address _DEFAULT_LP_MODULE,
    address _DEFAULT_LP_TOKEN_MODULE,
    address[] calldata _ALLOWED_GETH_INTERFACE_MODULES,
    bytes[] calldata _ALLOWED_GETH_INTERFACE_MODULE_NAMES,
    uint256 _GOVERNANCE_FEE
  ) external;

  function getContractVersion() external view returns (uint256);

  function pause() external;

  function unpause() external;

  function pausegETH() external;

  function unpausegETH() external;

  function fetchWithdrawalContractUpgradeProposal(
    uint256 id
  ) external returns (uint256 withdrawalContractVersion);

  function gETH() external view returns (address);

  function gETHInterfaces(
    uint256 id,
    uint256 index
  ) external view returns (address);

  function allIdsByType(
    uint256 _type,
    uint256 _index
  ) external view returns (uint256);

  function generateId(
    string calldata _name,
    uint256 _type
  ) external pure returns (uint256 id);

  function getKey(
    uint256 _id,
    bytes32 _param
  ) external pure returns (bytes32 key);

  function readAddressForId(
    uint256 id,
    bytes32 key
  ) external view returns (address data);

  function readUintForId(
    uint256 id,
    bytes32 key
  ) external view returns (uint256 data);

  function readBytesForId(
    uint256 id,
    bytes32 key
  ) external view returns (bytes memory data);

  function readUintArrayForId(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view returns (uint256 data);

  function readBytesArrayForId(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view returns (bytes memory data);

  function readAddressArrayForId(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view returns (address data);

  function GeodeParams()
    external
    view
    returns (
      address SENATE,
      address GOVERNANCE,
      uint256 SENATE_EXPIRY,
      uint256 GOVERNANCE_FEE
    );

  function getProposal(
    uint256 id
  ) external view returns (GeodeUtils.Proposal memory proposal);

  function isElector(uint256 _TYPE) external view returns (bool);

  function isUpgradeAllowed(
    address proposedImplementation
  ) external view returns (bool);

  function setGovernanceFee(uint256 newFee) external;

  function setElectorType(uint256 _TYPE, bool isElector) external;

  function newProposal(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) external;

  function approveProposal(uint256 id) external;

  function changeSenate(address _newSenate) external;

  function changeIdCONTROLLER(uint256 id, address newCONTROLLER) external;

  function approveSenate(uint256 proposalId, uint256 electorId) external;

  function StakingParams()
    external
    view
    returns (
      uint256 VALIDATORS_INDEX,
      uint256 VERIFICATION_INDEX,
      uint256 MONOPOLY_THRESHOLD,
      uint256 EARLY_EXIT_FEE,
      uint256 ORACLE_UPDATE_TIMESTAMP,
      uint256 DAILY_PRICE_INCREASE_LIMIT,
      uint256 DAILY_PRICE_DECREASE_LIMIT,
      bytes32 PRICE_MERKLE_ROOT,
      address ORACLE_POSITION
    );

  function getDefaultModule(
    uint256 _type
  ) external view returns (uint256 _version);

  function isAllowedModule(
    uint256 _type,
    uint256 _version
  ) external view returns (bool);

  function getValidator(
    bytes calldata pubkey
  ) external view returns (StakeUtils.Validator memory);

  function getValidatorByPool(
    uint256 poolId,
    uint256 index
  ) external view returns (bytes memory);

  function getMaintenanceFee(uint256 id) external view returns (uint256 fee);

  // function operatorAllowance(
  //   uint256 poolId,
  //   uint256 operatorId
  // ) external view returns (uint256 allowance);

  function isPrisoned(uint256 operatorId) external view returns (bool);

  function isPrivatePool(uint256 poolId) external view returns (bool);

  function isPriceValid(uint256 poolId) external view returns (bool);

  function isMintingAllowed(uint256 poolId) external view returns (bool);

  function canStake(bytes calldata pubkey) external view returns (bool);

  function initiateOperator(
    uint256 id,
    uint256 fee,
    uint256 validatorPeriod,
    address maintainer
  ) external payable;

  function initiatePool(
    uint256 fee,
    uint256 interfaceVersion,
    address maintainer,
    bytes calldata NAME,
    bytes calldata interface_data,
    bool[3] calldata config
  ) external payable;

  function setPoolVisibility(uint256 poolId, bool isPrivate) external;

  function deployLiquidityPool(uint256 poolId) external;

  function changeMaintainer(uint256 id, address newMaintainer) external;

  function switchMaintenanceFee(uint256 id, uint256 newFee) external;

  function increaseWalletBalance(
    uint256 id
  ) external payable returns (bool success);

  function decreaseWalletBalance(
    uint256 id,
    uint256 value
  ) external returns (bool success);

  function switchValidatorPeriod(uint256 id, uint256 newPeriod) external;

  function blameOperator(bytes calldata pk) external;

  function setEarlyExitFee(uint256 fee) external;

  function releasePrisoned(uint256 operatorId) external;

  function approveOperators(
    uint256 poolId,
    uint256[] calldata operatorIds,
    uint256[] calldata allowances
  ) external;

  function setWhitelist(uint256 poolId, address whitelist) external;

  function deposit(
    uint256 poolId,
    uint256 mingETH,
    uint256 deadline,
    uint256 price,
    bytes32[] calldata priceProofs,
    address receiver
  ) external payable;

  function proposeStake(
    uint256 poolId,
    uint256 operatorId,
    bytes[] calldata pubkeys,
    bytes[] calldata signatures1,
    bytes[] calldata signatures31
  ) external;

  function beaconStake(uint256 operatorId, bytes[] calldata pubkeys) external;

  function updateVerificationIndex(
    uint256 validatorVerificationIndex,
    bytes[] calldata alienatedPubkeys
  ) external;

  function regulateOperators(
    uint256[] calldata feeThefts,
    bytes[] calldata stolenBlocks
  ) external;

  function reportOracle(
    bytes32 priceMerkleRoot,
    uint256 allValidatorsCount
  ) external;

  function priceSync(
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProofs
  ) external;

  function priceSyncBatch(
    uint256[] calldata poolIds,
    uint256[] calldata prices,
    bytes32[][] calldata priceProofs
  ) external;
}
