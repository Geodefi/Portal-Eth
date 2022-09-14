// // SPDX-License-Identifier: MIT
// pragma solidity =0.8.7;
// import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
// import "../../utils/DataStoreUtilsLib.sol";
// import "../../utils/MaintainerUtilsLib.sol";
// import "../../utils/OracleUtilsLib.sol";
// import "../../utils/StakeUtilsLib.sol";
// import "../../../interfaces/IgETH.sol";

// contract TestStakeUtils is ERC1155Holder {
//     using MaintainerUtils for DataStoreUtils.DataStore;
//     using DataStoreUtils for DataStoreUtils.DataStore;
//     using OracleUtils for OracleUtils.Oracle;
//     using StakeUtils for StakeUtils.StakePool;

//     DataStoreUtils.DataStore private DATASTORE;
//     StakeUtils.StakePool private STAKEPOOL;

//     constructor(
//         address _gETH,
//         address _GOVERNANCE,
//         address _DEFAULT_DWP,
//         address _DEFAULT_LP_TOKEN,
//         address _DEFAULT_gETH_INTERFACE,
//         address _DEFAULT_MINI_GOVERNANCE,
//         uint256 _BOOSTRAP_PERIOD,
//         address _ORACLE_POSITION
//     ) {
//         STAKEPOOL.gETH = IgETH(_gETH);
//         STAKEPOOL.GOVERNANCE = _GOVERNANCE;
//         STAKEPOOL.DEFAULT_DWP = _DEFAULT_DWP;
//         STAKEPOOL.DEFAULT_LP_TOKEN = _DEFAULT_LP_TOKEN;
//         STAKEPOOL.DEFAULT_gETH_INTERFACE = _DEFAULT_gETH_INTERFACE;
//         STAKEPOOL.BOOSTRAP_PERIOD = _BOOSTRAP_PERIOD; //10%
//         STAKEPOOL.MAX_MAINTAINER_FEE =
//             (10 * StakeUtils.PERCENTAGE_DENOMINATOR) /
//             1e2; //10%

//         STAKEPOOL.TELESCOPE.gETH = IgETH(_gETH);
//         STAKEPOOL.TELESCOPE.ORACLE_POSITION = _ORACLE_POSITION;
//         STAKEPOOL.TELESCOPE.PERIOD_PRICE_INCREASE_LIMIT =
//             (2 * StakeUtils.PERCENTAGE_DENOMINATOR) /
//             1e3;
//         STAKEPOOL.TELESCOPE.PERIOD_PRICE_DECREASE_LIMIT =
//             (2 * StakeUtils.PERCENTAGE_DENOMINATOR) /
//             1e3;
//         STAKEPOOL.TELESCOPE.PRICE_MERKLE_ROOT = "";
//         STAKEPOOL.MINI_GOVERNANCE_VERSION = 31415926535;
//         DATASTORE.writeAddressForId(
//             STAKEPOOL.MINI_GOVERNANCE_VERSION,
//             "CONTROLLER",
//             _DEFAULT_MINI_GOVERNANCE
//         );
//     }

//     function getStakePoolParams()
//         external
//         view
//         virtual
//         returns (
//             address gETH,
//             address GOVERNANCE,
//             address DEFAULT_gETH_INTERFACE,
//             address DEFAULT_DWP,
//             address DEFAULT_LP_TOKEN,
//             uint256 MAX_MAINTAINER_FEE,
//             uint256 BOOSTRAP_PERIOD,
//             uint256 WITHDRAWAL_DELAY
//         )
//     {
//         gETH = address(STAKEPOOL.gETH);
//         GOVERNANCE = STAKEPOOL.GOVERNANCE;
//         DEFAULT_gETH_INTERFACE = STAKEPOOL.DEFAULT_gETH_INTERFACE;
//         DEFAULT_DWP = STAKEPOOL.DEFAULT_DWP;
//         DEFAULT_LP_TOKEN = STAKEPOOL.DEFAULT_LP_TOKEN;
//         MAX_MAINTAINER_FEE = STAKEPOOL.MAX_MAINTAINER_FEE;
//         BOOSTRAP_PERIOD = STAKEPOOL.BOOSTRAP_PERIOD;
//         WITHDRAWAL_DELAY = STAKEPOOL.TELESCOPE.WITHDRAWAL_DELAY;
//     }

//     function getOracleParams()
//         external
//         view
//         virtual
//         returns (
//             address ORACLE,
//             uint256 ORACLE_UPDATE_TIMESTAMP,
//             uint256 MONOPOLY_THRESHOLD, // max number of validators an operator is allowed to operate.
//             uint256 VALIDATORS_INDEX,
//             uint256 VERIFICATION_INDEX,
//             uint256 PERIOD_PRICE_INCREASE_LIMIT,
//             uint256 PERIOD_PRICE_DECREASE_LIMIT,
//             bytes32 PRICE_MERKLE_ROOT
//         )
//     {
//         ORACLE = STAKEPOOL.TELESCOPE.ORACLE_POSITION;
//         ORACLE_UPDATE_TIMESTAMP = STAKEPOOL.TELESCOPE.ORACLE_UPDATE_TIMESTAMP;
//         MONOPOLY_THRESHOLD = STAKEPOOL.TELESCOPE.MONOPOLY_THRESHOLD;
//         VALIDATORS_INDEX = STAKEPOOL.TELESCOPE.VALIDATORS_INDEX;
//         VERIFICATION_INDEX = STAKEPOOL.TELESCOPE.VERIFICATION_INDEX;
//         PERIOD_PRICE_INCREASE_LIMIT = STAKEPOOL
//             .TELESCOPE
//             .PERIOD_PRICE_INCREASE_LIMIT;
//         PERIOD_PRICE_DECREASE_LIMIT = STAKEPOOL
//             .TELESCOPE
//             .PERIOD_PRICE_DECREASE_LIMIT;
//         PRICE_MERKLE_ROOT = STAKEPOOL.TELESCOPE.PRICE_MERKLE_ROOT;
//     }

//     function changeOracle() public {
//         STAKEPOOL.gETH.updateOracleRole(msg.sender);
//     }

//     /**
//      * Maintainer
//      */
//     function getMaintainerFromId(uint256 _id)
//         external
//         view
//         virtual
//         returns (address)
//     {
//         return DATASTORE.getMaintainerFromId(_id);
//     }

//     function beController(uint256 _id) external {
//         DATASTORE.writeAddressForId(_id, "CONTROLLER", msg.sender);
//     }

//     function setType(uint256 _id, uint256 _type) external {
//         DATASTORE.writeUintForId(_id, "TYPE", _type);
//     }

//     function mintgETH(
//         address _to,
//         uint256 _id,
//         uint256 _amount
//     ) external virtual {
//         STAKEPOOL.gETH.mint(_to, _id, _amount, "");
//     }

//     function buyback(
//         address to,
//         uint256 poolId,
//         uint256 sellEth,
//         uint256 minToBuy,
//         uint256 deadline
//     ) external returns (uint256 outAmount) {
//         outAmount = STAKEPOOL._buyback(
//             DATASTORE,
//             to,
//             poolId,
//             sellEth,
//             minToBuy,
//             deadline
//         );
//     }

//     function changeIdMaintainer(uint256 _id, address _newMaintainer)
//         external
//         virtual
//     {
//         StakeUtils.changeOperatorMaintainer(DATASTORE, _id, _newMaintainer);
//     }

//     function switchMaintainerFee(uint256 _id, uint256 _newFee)
//         external
//         virtual
//     {
//         STAKEPOOL.switchMaintainerFee(DATASTORE, _id, _newFee);
//     }

//     function updateGovernanceParams(
//         address _DEFAULT_gETH_INTERFACE, // contract?
//         address _DEFAULT_DWP, // contract?
//         address _DEFAULT_LP_TOKEN, // contract?
//         uint256 _MAX_MAINTAINER_FEE, // < 100
//         uint256 _BOOSTRAP_PERIOD,
//         uint256 _PERIOD_PRICE_INCREASE_LIMIT,
//         uint256 _PERIOD_PRICE_DECREASE_LIMIT,
//         uint256 _WITHDRAWAL_DELAY
//     ) external virtual {
//         // do not forget only governance check
//         require(
//             _DEFAULT_gETH_INTERFACE.code.length > 0,
//             "StakeUtils: DEFAULT_gETH_INTERFACE NOT contract"
//         );
//         require(
//             _DEFAULT_DWP.code.length > 0,
//             "StakeUtils: DEFAULT_DWP NOT contract"
//         );
//         require(
//             _DEFAULT_LP_TOKEN.code.length > 0,
//             "StakeUtils: DEFAULT_LP_TOKEN NOT contract"
//         );
//         require(
//             _PERIOD_PRICE_INCREASE_LIMIT > 0,
//             "StakeUtils: incorrect PERIOD_PRICE_INCREASE_LIMIT"
//         );
//         require(
//             _PERIOD_PRICE_DECREASE_LIMIT > 0,
//             "StakeUtils: incorrect PERIOD_PRICE_DECREASE_LIMIT"
//         );
//         require(
//             _MAX_MAINTAINER_FEE > 0 &&
//                 _MAX_MAINTAINER_FEE <= StakeUtils.PERCENTAGE_DENOMINATOR,
//             "StakeUtils: incorrect MAX_MAINTAINER_FEE"
//         );
//         STAKEPOOL.DEFAULT_gETH_INTERFACE = _DEFAULT_gETH_INTERFACE;
//         STAKEPOOL.DEFAULT_DWP = _DEFAULT_DWP;
//         STAKEPOOL.DEFAULT_LP_TOKEN = _DEFAULT_LP_TOKEN;
//         STAKEPOOL.MAX_MAINTAINER_FEE = _MAX_MAINTAINER_FEE;
//         STAKEPOOL.BOOSTRAP_PERIOD = _BOOSTRAP_PERIOD;
//         STAKEPOOL
//             .TELESCOPE
//             .PERIOD_PRICE_INCREASE_LIMIT = _PERIOD_PRICE_INCREASE_LIMIT;
//         STAKEPOOL
//             .TELESCOPE
//             .PERIOD_PRICE_DECREASE_LIMIT = _PERIOD_PRICE_DECREASE_LIMIT;
//         STAKEPOOL.TELESCOPE.WITHDRAWAL_DELAY = _WITHDRAWAL_DELAY;
//     }

//     function getMaintainerFee(uint256 _id)
//         external
//         view
//         virtual
//         returns (uint256)
//     {
//         return DATASTORE.getMaintainerFee(_id);
//     }

//     function updateValidatorPeriod(uint256 _operatorId, uint256 _newPeriod)
//         external
//         virtual
//     {
//         StakeUtils.updateValidatorPeriod(DATASTORE, _operatorId, _newPeriod);
//     }

//     function getValidatorPeriod(uint256 _id)
//         external
//         view
//         virtual
//         returns (uint256)
//     {
//         return StakeUtils.getValidatorPeriod(DATASTORE, _id);
//     }

//     function setPricePerShare(uint256 price, uint256 _planetId) external {
//         STAKEPOOL.gETH.setPricePerShare(price, _planetId);
//     }

//     function getPricePerShare(uint256 _planetId)
//         external
//         view
//         returns (uint256)
//     {
//         return STAKEPOOL.gETH.pricePerShare(_planetId);
//     }

//     function setInterface(uint256 _planetId, address _interface) external {
//         STAKEPOOL.setInterface(DATASTORE, _planetId, _interface);
//     }

//     function unsetInterface(uint256 _planetId, uint256 _index) external {
//         STAKEPOOL.unsetInterface(DATASTORE, _planetId, _index);
//     }

//     function allInterfaces(uint256 _planetId)
//         external
//         view
//         returns (address[] memory)
//     {
//         return StakeUtils.allInterfaces(DATASTORE, _planetId);
//     }

//     function withdrawalBoost(uint256 _id)
//         external
//         view
//         virtual
//         returns (uint256)
//     {
//         return DATASTORE.readUintForId(_id, "withdrawalBoost");
//     }

//     function whenInitiated(uint256 _planetId)
//         external
//         view
//         virtual
//         returns (uint256)
//     {
//         return DATASTORE.readUintForId(_planetId, "initiated");
//     }

//     function initiateOperator(
//         uint256 _planetId,
//         uint256 _fee,
//         address _maintainer,
//         uint256 _cometPeriod
//     ) external {
//         STAKEPOOL.initiateOperator(
//             DATASTORE,
//             _planetId,
//             _fee,
//             _maintainer,
//             _cometPeriod
//         );
//     }

//     function initiatePlanet(
//         uint256 _planetId,
//         uint256 _fee,
//         uint256 _withdrawalBoost,
//         address _maintainer,
//         string memory _interfaceName,
//         string memory _interfaceSymbol
//     ) external {
//         STAKEPOOL.initiatePlanet(
//             DATASTORE,
//             _planetId,
//             _fee,
//             _withdrawalBoost,
//             _maintainer,
//             [_interfaceName, _interfaceSymbol]
//         );
//     }

//     function initiateComet(
//         uint256 _planetId,
//         uint256 _fee,
//         address _maintainer
//     ) external {
//         STAKEPOOL.initiateComet(DATASTORE, _planetId, _fee, _maintainer);
//     }

//     function operatorAllowance(uint256 _planetId, uint256 _operatorId)
//         external
//         view
//         returns (uint256 allowence)
//     {
//         allowence = StakeUtils.operatorAllowance(
//             DATASTORE,
//             _planetId,
//             _operatorId
//         );
//     }

//     function approveOperator(
//         uint256 _planetId,
//         uint256 _operatorId,
//         uint256 _allowance
//     ) external returns (bool success) {
//         success = StakeUtils.approveOperator(
//             DATASTORE,
//             _planetId,
//             _operatorId,
//             _allowance
//         );
//     }

//     function getMaintainerWalletBalance(uint256 id)
//         external
//         view
//         returns (uint256 balance)
//     {
//         balance = DATASTORE.getMaintainerWalletBalance(id);
//     }

//     function increaseMaintainerWallet(uint256 id)
//         external
//         payable
//         returns (bool success)
//     {
//         success = StakeUtils.increaseMaintainerWallet(DATASTORE, id);
//     }

//     function decreaseMaintainerWallet(uint256 id, uint256 value)
//         external
//         returns (bool success)
//     {
//         success = StakeUtils.decreaseMaintainerWallet(DATASTORE, id, value);
//     }

//     function deployWithdrawalPool(uint256 _id)
//         external
//         returns (address WithdrawalPool)
//     {
//         WithdrawalPool = DATASTORE._deployWithdrawalPool(
//             _id,
//             address(STAKEPOOL.gETH),
//             STAKEPOOL.DEFAULT_DWP,
//             STAKEPOOL.DEFAULT_LP_TOKEN
//         );
//     }

//     function withdrawalPoolById(uint256 _id)
//         external
//         view
//         virtual
//         returns (address)
//     {
//         return address(StakeUtils.withdrawalPoolById(DATASTORE, _id));
//     }

//     function LPTokenById(uint256 _id) external view virtual returns (address) {
//         return address(StakeUtils.LPTokenById(DATASTORE, _id));
//     }

//     function dailyMintBuffer(uint256 poolId) external view returns (uint256) {
//         bytes32 dailyBufferKey = DataStoreUtils.getKey(
//             block.timestamp - (block.timestamp % OracleUtils.ORACLE_PERIOD),
//             "mintBuffer"
//         );
//         return DATASTORE.readUintForId(poolId, dailyBufferKey);
//     }

//     function dailyBurnBuffer(uint256 poolId) external view returns (uint256) {
//         bytes32 dailyBufferKey = DataStoreUtils.getKey(
//             block.timestamp - (block.timestamp % OracleUtils.ORACLE_PERIOD),
//             "burnBuffer"
//         );
//         return DATASTORE.readUintForId(poolId, dailyBufferKey);
//     }

//     function surplusById(uint256 _planetId) external view returns (uint256) {
//         return DATASTORE.readUintForId(_planetId, "surplus");
//     }

//     function securedById(uint256 _planetId) external view returns (uint256) {
//         return DATASTORE.readUintForId(_planetId, "secured");
//     }

//     function proposedValidatorsById(uint256 _planetId, uint256 _operatorId)
//         external
//         view
//         returns (uint256)
//     {
//         return
//             DATASTORE.readUintForId(
//                 _planetId,
//                 DataStoreUtils.getKey(_operatorId, "proposedValidators")
//             );
//     }

//     function totalProposedValidatorsById(uint256 _operatorId)
//         external
//         view
//         returns (uint256)
//     {
//         return DATASTORE.readUintForId(_operatorId, "totalProposedValidators");
//     }

//     function activeValidatorsById(uint256 _planetId, uint256 _operatorId)
//         external
//         view
//         returns (uint256)
//     {
//         return
//             DATASTORE.readUintForId(
//                 _planetId,
//                 DataStoreUtils.getKey(_operatorId, "activeValidators")
//             );
//     }

//     function canDeposit(uint256 id) external view returns (bool) {
//         return StakeUtils.canDeposit(DATASTORE, id);
//     }

//     function pauseStakingForPool(uint256 id) external {
//         StakeUtils.pauseStakingForPool(DATASTORE, id);
//     }

//     function unpauseStakingForPool(uint256 id) external {
//         StakeUtils.unpauseStakingForPool(DATASTORE, id);
//     }

//     function donateBalancedFees(
//         uint256 poolId,
//         uint256 burnSurplus_,
//         uint256 burnGeth
//     ) external returns (uint256 ethDonation, uint256 gEthDonation) {
//         return
//             StakeUtils._donateBalancedFees(
//                 DATASTORE,
//                 poolId,
//                 burnSurplus_,
//                 burnGeth
//             );
//     }

//     function burnSurplus(uint256 poolId, uint256 withdrawnGeth)
//         external
//         returns (uint256, uint256)
//     {
//         return STAKEPOOL._burnSurplus(DATASTORE, poolId, withdrawnGeth);
//     }

//     uint256 public ethToSend;

//     function lastEthToSend() external view virtual returns (uint256) {
//         return ethToSend;
//     }

//     function withdrawPlanet(
//         uint256 poolId,
//         uint256 withdrawnGeth,
//         uint256 minETH,
//         uint256 deadline
//     ) external virtual {
//         ethToSend = STAKEPOOL.withdrawPlanet(
//             DATASTORE,
//             poolId,
//             withdrawnGeth,
//             minETH,
//             deadline
//         );
//     }

//     function depositPlanet(
//         uint256 planetId,
//         uint256 minGEth,
//         uint256 deadline
//     ) external payable virtual returns (uint256 totalgEth) {
//         totalgEth = STAKEPOOL.depositPlanet(
//             DATASTORE,
//             planetId,
//             minGEth,
//             deadline
//         );
//         require(totalgEth > minGEth, "Portal: unsuccesful deposit");
//     }

//     function canStake(bytes calldata pubkey)
//         external
//         view
//         virtual
//         returns (bool)
//     {
//         return STAKEPOOL.TELESCOPE.canStake(pubkey);
//     }

//     function proposeStake(
//         uint256 planetId,
//         uint256 operatorId,
//         bytes[] calldata pubkeys,
//         bytes[] calldata signatures
//     ) external virtual {
//         STAKEPOOL.proposeStake(
//             DATASTORE,
//             planetId,
//             operatorId,
//             pubkeys,
//             signatures
//         );
//     }

//     function beaconStake(uint256 operatorId, bytes[] calldata pubkeys)
//         external
//         virtual
//     {
//         STAKEPOOL.beaconStake(DATASTORE, operatorId, pubkeys);
//     }

//     function setSurplus(uint256 _id, uint256 _surplus) external {
//         DATASTORE.writeUintForId(_id, "surplus", _surplus);
//     }

//     function setMONOPOLY_THRESHOLD(uint256 threshold) external virtual {
//         STAKEPOOL.TELESCOPE.MONOPOLY_THRESHOLD = threshold;
//     }

//     function regulateOperators(
//         uint256 all_validators_count,
//         uint256 VERIFICATION_INDEX,
//         uint256 unstake_verification_index,
//         bytes[][] calldata regulatedPubkeys, //i = 0: alienated, 1: cured, 2: busted, 3: released
//         uint256[] calldata prisonedIds
//     ) external virtual {
//         STAKEPOOL.TELESCOPE.regulateOperators(
//             DATASTORE,
//             all_validators_count,
//             VERIFICATION_INDEX,
//             unstake_verification_index,
//             regulatedPubkeys,
//             prisonedIds
//         );
//     }

//     function isPrisoned(uint256 operatorId)
//         external
//         view
//         virtual
//         returns (bool)
//     {
//         return StakeUtils.isPrisoned(DATASTORE, operatorId);
//     }

//     function releasePrisoned(uint256 operatorId) external virtual {
//         STAKEPOOL.releasePrisoned(DATASTORE, operatorId);
//     }

//     function alienatePubKey(bytes calldata pubkey) external virtual {
//         STAKEPOOL.TELESCOPE._validators[pubkey].state = 69;
//     }

//     function getValidatorData(bytes calldata pubkey)
//         external
//         view
//         virtual
//         returns (OracleUtils.Validator memory)
//     {
//         return STAKEPOOL.TELESCOPE._validators[pubkey];
//     }

//     function getVALIDATORS_INDEX() external view virtual returns (uint256) {
//         return STAKEPOOL.TELESCOPE.VALIDATORS_INDEX;
//     }

//     function getVERIFICATION_INDEX() external view virtual returns (uint256) {
//         return STAKEPOOL.TELESCOPE.VERIFICATION_INDEX;
//     }

//     function getContractBalance() external view virtual returns (uint256) {
//         return address(this).balance;
//     }

//     function setORACLE_UPDATE_TIMESTAMP(uint256 ts) external virtual {
//         STAKEPOOL.TELESCOPE.ORACLE_UPDATE_TIMESTAMP = ts;
//     }

//     function isOracleActive() external view virtual returns (bool) {
//         return STAKEPOOL.TELESCOPE._isOracleActive();
//     }

//     function sanityCheck(uint256 _id, uint256 _newPrice) external view {
//         STAKEPOOL.TELESCOPE._sanityCheck(
//             _id,
//             (block.timestamp +
//                 OracleUtils.ORACLE_ACTIVE_PERIOD -
//                 STAKEPOOL.TELESCOPE.ORACLE_UPDATE_TIMESTAMP) /
//                 OracleUtils.ORACLE_PERIOD,
//             _newPrice
//         );
//     }

//     function priceSync(
//         bytes32 merkleRoot,
//         uint256 index,
//         uint256 poolId,
//         uint256 beaconBalance,
//         uint256 periodsSinceUpdate,
//         bytes32[] calldata priceProofs
//     ) external virtual {
//         bytes32[2] memory dailyBufferKeys = [
//             DataStoreUtils.getKey(
//                 block.timestamp - (block.timestamp % OracleUtils.ORACLE_PERIOD),
//                 "mintBuffer"
//             ),
//             DataStoreUtils.getKey(
//                 block.timestamp - (block.timestamp % OracleUtils.ORACLE_PERIOD),
//                 "burnBuffer"
//             )
//         ];
//         STAKEPOOL.TELESCOPE.PRICE_MERKLE_ROOT = merkleRoot;
//         STAKEPOOL.TELESCOPE._priceSync(
//             DATASTORE,
//             dailyBufferKeys,
//             index,
//             poolId,
//             beaconBalance,
//             periodsSinceUpdate,
//             priceProofs
//         );
//     }

//     uint256 lastRealPrice;
//     uint256 lastExpectedPrice;

//     function getLastPrices() external view returns (uint256, uint256) {
//         return (lastRealPrice, lastExpectedPrice);
//     }

//     function findPrices(uint256 poolId, uint256 beaconBalance)
//         external
//         returns (uint256 real, uint256 expected)
//     {
//         (real, expected) = STAKEPOOL.TELESCOPE._findPrices_ClearBuffer(
//             DATASTORE,
//             DataStoreUtils.getKey(
//                 block.timestamp - (block.timestamp % OracleUtils.ORACLE_PERIOD),
//                 "mintBuffer"
//             ),
//             DataStoreUtils.getKey(
//                 block.timestamp - (block.timestamp % OracleUtils.ORACLE_PERIOD),
//                 "burnBuffer"
//             ),
//             poolId,
//             beaconBalance
//         );
//         (lastRealPrice, lastExpectedPrice) = (real, expected);
//     }

//     function reportOracle(
//         bytes32 merkleRoot,
//         uint256[] calldata beaconBalances,
//         bytes32[][] calldata priceProofs
//     ) external {
//         STAKEPOOL.TELESCOPE.reportOracle(
//             DATASTORE,
//             merkleRoot,
//             beaconBalances,
//             priceProofs
//         );
//     }

//     function Receive() external payable {}

//     receive() external payable {}
// }
