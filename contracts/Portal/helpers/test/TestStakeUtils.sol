// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "../../utils/DataStoreLib.sol";
import "../../utils/StakeUtilsLib.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../../../interfaces/IgETH.sol";

contract TestStakeUtils is ERC1155Holder {
    using DataStoreUtils for DataStoreUtils.DataStore;
    using StakeUtils for StakeUtils.StakePool;
    DataStoreUtils.DataStore private DATASTORE;
    StakeUtils.StakePool private STAKEPOOL;
    uint256 public FEE_DENOMINATOR = 10**10;

    constructor(
        address _gETH,
        address _ORACLE,
        address _DEFAULT_DWP,
        address _DEFAULT_LP_TOKEN,
        address _DEFAULT_gETH_INTERFACE
    ) {
        STAKEPOOL.ORACLE = _ORACLE;
        STAKEPOOL.gETH = _gETH;
        STAKEPOOL.DEFAULT_DWP = _DEFAULT_DWP;
        STAKEPOOL.DEFAULT_LP_TOKEN = _DEFAULT_LP_TOKEN;
        STAKEPOOL.DEFAULT_gETH_INTERFACE = _DEFAULT_gETH_INTERFACE;
        STAKEPOOL.PERIOD_PRICE_INCREASE_LIMIT = (2 * FEE_DENOMINATOR) / 1e3;
        STAKEPOOL.MAX_MAINTAINER_FEE = (10 * FEE_DENOMINATOR) / 1e2; //10%
        STAKEPOOL.VERIFICATION_INDEX = 0;
        STAKEPOOL.VALIDATORS_INDEX = 0;
    }

    function getStakePoolParams()
        external
        view
        virtual
        returns (
            address ORACLE,
            address gETH,
            address DEFAULT_gETH_INTERFACE,
            address DEFAULT_DWP,
            address DEFAULT_LP_TOKEN,
            uint256 PERIOD_PRICE_INCREASE_LIMIT,
            uint256 MAX_MAINTAINER_FEE,
            uint256 VERIFICATION_INDEX,
            uint256 VALIDATORS_INDEX
        )
    {
        ORACLE = STAKEPOOL.ORACLE;
        gETH = STAKEPOOL.gETH;
        DEFAULT_gETH_INTERFACE = STAKEPOOL.DEFAULT_gETH_INTERFACE;
        DEFAULT_DWP = STAKEPOOL.DEFAULT_DWP;
        DEFAULT_LP_TOKEN = STAKEPOOL.DEFAULT_LP_TOKEN;
        PERIOD_PRICE_INCREASE_LIMIT = STAKEPOOL.PERIOD_PRICE_INCREASE_LIMIT;
        MAX_MAINTAINER_FEE = STAKEPOOL.MAX_MAINTAINER_FEE;
        VERIFICATION_INDEX = STAKEPOOL.VERIFICATION_INDEX;
        VALIDATORS_INDEX = STAKEPOOL.VALIDATORS_INDEX;
    }

    function getgETH() public view virtual returns (IgETH) {
        return STAKEPOOL.getgETH();
    }

    function changeOracle() public {
        STAKEPOOL.getgETH().updateOracleRole(msg.sender);
    }

    /**
     * Maintainer
     */
    function getMaintainerFromId(uint256 _id)
        external
        view
        virtual
        returns (address)
    {
        return StakeUtils.getMaintainerFromId(DATASTORE, _id);
    }

    function beController(uint256 _id) external {
        DATASTORE.writeAddressForId(_id, "CONTROLLER", msg.sender);
    }

    function setType(uint256 _id, uint256 _type) external {
        DATASTORE.writeUintForId(_id, "TYPE", _type);
    }

    function getERC1155() external view virtual returns (IgETH) {
        return STAKEPOOL.getgETH();
    }

    function mintgETH(
        address _to,
        uint256 _id,
        uint256 _amount
    ) external virtual {
        StakeUtils._mint(address(STAKEPOOL.getgETH()), _to, _id, _amount);
    }

    function buyback(
        address to,
        uint256 poolId,
        uint256 sellEth,
        uint256 minToBuy,
        uint256 deadline
    ) external returns (uint256 outAmount) {
        outAmount = STAKEPOOL._buyback(
            DATASTORE,
            to,
            poolId,
            sellEth,
            minToBuy,
            deadline
        );
    }

    function changeIdMaintainer(uint256 _id, address _newMaintainer)
        external
        virtual
    {
        StakeUtils.changeMaintainer(DATASTORE, _id, _newMaintainer);
    }

    function switchMaintainerFee(uint256 _id, uint256 _newFee)
        external
        virtual
    {
        STAKEPOOL.switchMaintainerFee(DATASTORE, _id, _newFee);
    }

    function setMaxMaintainerFee(uint256 _newMaxFee, address _governance)
        external
        virtual
    {
        STAKEPOOL.setMaxMaintainerFee(_governance, _newMaxFee);
    }

    function getMaintainerFee(uint256 _id)
        external
        view
        virtual
        returns (uint256)
    {
        return STAKEPOOL.getMaintainerFee(DATASTORE, _id);
    }

    function updateCometPeriod(uint256 _operatorId, uint256 _newPeriod)
        external
        virtual
    {
        StakeUtils.updateCometPeriod(DATASTORE, _operatorId, _newPeriod);
    }

    function getCometPeriod(uint256 _id)
        external
        view
        virtual
        returns (uint256)
    {
        return StakeUtils.getCometPeriod(DATASTORE, _id);
    }

    function setPricePerShare(uint256 price, uint256 _planetId) external {
        STAKEPOOL._setPricePerShare(price, _planetId);
    }

    function getPricePerShare(uint256 _planetId)
        external
        view
        returns (uint256)
    {
        return STAKEPOOL._getPricePerShare(_planetId);
    }

    function setInterface(uint256 _planetId, address _interface) external {
        STAKEPOOL.setInterface(DATASTORE, _planetId, _interface);
    }

    function unsetInterface(uint256 _planetId, uint256 _index) external {
        STAKEPOOL.unsetInterface(DATASTORE, _planetId, _index);
    }

    function allInterfaces(uint256 _planetId)
        external
        view
        returns (address[] memory)
    {
        return StakeUtils.allInterfaces(DATASTORE, _planetId);
    }

    function currentInterface(uint256 _id)
        external
        view
        virtual
        returns (address)
    {
        return DATASTORE.readAddressForId(_id, "currentInterface");
    }

    function isInitiated(uint256 _planetId)
        external
        view
        virtual
        returns (uint256)
    {
        return DATASTORE.readUintForId(_planetId, "initiated");
    }

    function initiateOperator(
        uint256 _planetId,
        uint256 _fee,
        address _maintainer,
        uint256 _cometPeriod
    ) external {
        STAKEPOOL.initiateOperator(
            DATASTORE,
            _planetId,
            _fee,
            _maintainer,
            _cometPeriod
        );
    }

    function initiatePlanet(
        uint256 _planetId,
        uint256 _fee,
        address _maintainer,
        address _governance,
        string memory _interfaceName,
        string memory _interfaceSymbol
    ) external {
        STAKEPOOL.initiatePlanet(
            DATASTORE,
            _planetId,
            _fee,
            _maintainer,
            _governance,
            _interfaceName,
            _interfaceSymbol
        );
    }

    function initiateComet(
        uint256 _planetId,
        uint256 _fee,
        address _maintainer
    ) external {
        STAKEPOOL.initiateComet(DATASTORE, _planetId, _fee, _maintainer);
    }

    function operatorAllowance(uint256 _planetId, uint256 _operatorId)
        external
        view
        returns (uint256 allowence)
    {
        allowence = StakeUtils.operatorAllowance(
            DATASTORE,
            _planetId,
            _operatorId
        );
    }

    function approveOperator(
        uint256 _planetId,
        uint256 _operatorId,
        uint256 _allowance
    ) external returns (bool success) {
        success = StakeUtils.approveOperator(
            DATASTORE,
            _planetId,
            _operatorId,
            _allowance
        );
    }

    function getOperatorWalletBalance(uint256 id)
        external
        view
        returns (uint256 balance)
    {
        balance = StakeUtils.getOperatorWalletBalance(DATASTORE, id);
    }

    function increaseOperatorWallet(uint256 id)
        external
        payable
        returns (bool success)
    {
        success = StakeUtils.increaseOperatorWallet(DATASTORE, id);
    }

    function decreaseOperatorWallet(uint256 id, uint256 value)
        external
        returns (bool success)
    {
        success = StakeUtils.decreaseOperatorWallet(DATASTORE, id, value);
    }

    function deployWithdrawalPool(uint256 _id)
        external
        returns (address WithdrawalPool)
    {
        WithdrawalPool = STAKEPOOL._deployWithdrawalPool(DATASTORE, _id);
    }

    function withdrawalPoolById(uint256 _id)
        external
        view
        virtual
        returns (address)
    {
        return address(StakeUtils.withdrawalPoolById(DATASTORE, _id));
    }

    function LPTokenById(uint256 _id) external view virtual returns (address) {
        return address(StakeUtils.LPTokenById(DATASTORE, _id));
    }

    function dailyMintBuffer(uint256 poolId) external view returns (uint256) {
        bytes32 dailyBufferKey = StakeUtils._getKey(
            block.timestamp - (block.timestamp % StakeUtils.ORACLE_PERIOD),
            "mintBuffer"
        );
        return DATASTORE.readUintForId(poolId, dailyBufferKey);
    }

    function surplusById(uint256 _planetId) external view returns (uint256) {
        return DATASTORE.readUintForId(_planetId, "surplus");
    }

    function securedById(uint256 _planetId) external view returns (uint256) {
        return DATASTORE.readUintForId(_planetId, "secured");
    }

    function proposedValidatorsById(uint256 _planetId, uint256 _operatorId)
        external
        view
        returns (uint256)
    {
        return
            DATASTORE.readUintForId(
                _planetId,
                StakeUtils._getKey(_operatorId, "proposedValidators")
            );
    }

    function totalProposedValidatorsById(uint256 _operatorId)
        external
        view
        returns (uint256)
    {
        return DATASTORE.readUintForId(_operatorId, "totalProposedValidators");
    }

    function activeValidatorsById(uint256 _planetId, uint256 _operatorId)
        external
        view
        returns (uint256)
    {
        return
            DATASTORE.readUintForId(
                _planetId,
                StakeUtils._getKey(_operatorId, "activeValidators")
            );
    }

    function isStakingPausedForPool(uint256 id) external view returns (bool) {
        return StakeUtils.isStakingPausedForPool(DATASTORE, id);
    }

    function pauseStakingForPool(uint256 id) external {
        StakeUtils.pauseStakingForPool(DATASTORE, id);
    }

    function unpauseStakingForPool(uint256 id) external {
        StakeUtils.unpauseStakingForPool(DATASTORE, id);
    }

    function stakePlanet(
        uint256 planetId,
        uint256 minGavax,
        uint256 deadline
    ) external payable virtual returns (uint256 totalgAvax) {
        totalgAvax = STAKEPOOL.stakePlanet(
            DATASTORE,
            planetId,
            minGavax,
            deadline
        );
        require(totalgAvax > 0, "Portal: unsuccesful deposit");
    }

    function canStake(bytes calldata pubkey)
        external
        view
        virtual
        returns (bool)
    {
        return STAKEPOOL.canStake(pubkey);
    }

    function proposeStake(
        uint256 planetId,
        uint256 operatorId,
        bytes[] calldata pubkeys,
        bytes[] calldata signatures
    ) external virtual {
        STAKEPOOL.proposeStake(
            DATASTORE,
            planetId,
            operatorId,
            pubkeys,
            signatures
        );
    }

    function beaconStake(uint256 operatorId, bytes[] calldata pubkeys)
        external
        virtual
    {
        STAKEPOOL.beaconStake(DATASTORE, operatorId, pubkeys);
    }

    function setSurplus(uint256 _id, uint256 _surplus) external {
        DATASTORE.writeUintForId(_id, "surplus", _surplus);
    }

    function setMONOPOLY_THRESHOLD(uint256 threshold) external virtual {
        STAKEPOOL.MONOPOLY_THRESHOLD = threshold;
    }

    function regulateOperators(
        uint256 all_validators_count,
        uint256 new_verification_index,
        bytes[] calldata alienPubkeys,
        bytes[] calldata curedPubkeys,
        uint256[] calldata prisonedIds
    ) external virtual {
        STAKEPOOL.regulateOperators(
            DATASTORE,
            all_validators_count,
            new_verification_index,
            alienPubkeys,
            curedPubkeys,
            prisonedIds
        );
    }

    function isPrisoned(uint256 operatorId)
        external
        view
        virtual
        returns (bool)
    {
        return StakeUtils.isPrisoned(DATASTORE, operatorId);
    }

    function releasePrisoned(uint256 operatorId, address governance)
        external
        virtual
    {
        StakeUtils.releasePrisoned(DATASTORE, governance, operatorId);
    }

    function alienatePubKey(bytes calldata pubkey) external virtual {
        STAKEPOOL.Validators[pubkey].state = 69;
    }

    function getValidatorData(bytes calldata pubkey)
        external
        view
        virtual
        returns (StakeUtils.Validator memory)
    {
        return STAKEPOOL.Validators[pubkey];
    }

    function getVALIDATORS_INDEX() external view virtual returns (uint256) {
        return STAKEPOOL.VALIDATORS_INDEX;
    }

    function getVERIFICATION_INDEX() external view virtual returns (uint256) {
        return STAKEPOOL.VERIFICATION_INDEX;
    }

    function getContractBalance() external view virtual returns (uint256) {
        return address(this).balance;
    }

    function setORACLE_UPDATE_TIMESTAMP(uint256 ts) external virtual {
        STAKEPOOL.ORACLE_UPDATE_TIMESTAMP = ts;
    }

    function isOracleActive() external view virtual returns (bool) {
        return STAKEPOOL._isOracleActive();
    }

    function sanityCheck(uint256 _id, uint256 _newPrice) external view {
        STAKEPOOL._sanityCheck(
            _id,
            (block.timestamp +
                StakeUtils.ORACLE_ACTIVE_PERIOD -
                STAKEPOOL.ORACLE_UPDATE_TIMESTAMP) / StakeUtils.ORACLE_PERIOD,
            _newPrice
        );
    }

    function priceSync(
        bytes32 merkleRoot,
        uint256 index,
        uint256 poolId,
        uint256 beaconBalance,
        uint256 periodsSinceUpdate,
        bytes32[] calldata priceProofs
    ) external virtual {
        bytes32 dailyBufferKey = StakeUtils._getKey(
            block.timestamp - (block.timestamp % StakeUtils.ORACLE_PERIOD),
            "mintBuffer"
        );
        STAKEPOOL.PRICE_MERKLE_ROOT = merkleRoot;
        STAKEPOOL._priceSync(
            DATASTORE,
            dailyBufferKey,
            index,
            poolId,
            beaconBalance,
            periodsSinceUpdate,
            priceProofs
        );
    }

    uint256 lastRealPrice;
    uint256 lastExpectedPrice;

    function getLastPrices() external view returns (uint256, uint256) {
        return (lastRealPrice, lastExpectedPrice);
    }

    function findPrices(uint256 poolId, uint256 beaconBalance)
        external
        returns (uint256 real, uint256 expected)
    {
        (real, expected) = STAKEPOOL._findPrices_ClearBuffer(
            DATASTORE,
            StakeUtils._getKey(
                block.timestamp - (block.timestamp % StakeUtils.ORACLE_PERIOD),
                "mintBuffer"
            ),
            poolId,
            beaconBalance
        );
        (lastRealPrice, lastExpectedPrice) = (real, expected);
    }

    function reportOracle(
        bytes32 merkleRoot,
        uint256[] calldata beaconBalances,
        bytes32[][] calldata priceProofs
    ) external {
        STAKEPOOL.reportOracle(
            DATASTORE,
            merkleRoot,
            beaconBalances,
            priceProofs
        );
    }

    function Receive() external payable {}
}
