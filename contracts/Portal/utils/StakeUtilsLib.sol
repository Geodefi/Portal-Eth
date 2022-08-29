// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DataStoreLib.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";
import "../gETHInterfaces/ERC20InterfacePermitUpgradable.sol";
import "../../interfaces/IgETH.sol";
import "../../interfaces/ISwap.sol";
import "../../interfaces/ILPToken.sol";

/**
 * @title StakeUtils library
 * @notice Exclusively contains functions related to ETH Liquid Staking designed by Geode Finance
 * @notice biggest part of the functionality is related to Withdrawal Pools
 * which relies on continuous buybacks for price peg with DEBT/SURPLUS calculations
 * @dev Contracts relying on this library must initialize StakeUtils.StakePool
 * @dev ALL "fee" variables are limited by FEE_DENOMINATOR. For ex, when fee is equal to FEE_DENOMINATOR/2, it means 50% fee
 * Note refer to DataStoreUtils before reviewing
 * Note *suggested* refer to GeodeUtils before reviewing
 * Note beware of the staking pool and operator implementations:
 *
 *
 * Type 4 stand for Operators, they maintain Beacon Chain Validators on behalf of Planets and Comets.
 * Operators have properties like fee(as a percentage), maintainer.
 *
 * Type 5 stand for Public Staking Pool (Planets).
 * Every Planet is also an Operator by design.
 * Planets inherits Operator functionalities and parameters, with additional
 * properties like staking pools - relates to params: stBalance, surplus, secured, withdrawalPool - relates to debt -
 * and liquid asset ID(gETH).
 * Everyone can stake and unstake using public pools.
 *
 * Type 6 stands for Private Staking Pools (Comets).
 * It is permissionless, one can directly create a Comet by simply choosing a name.
 * Portal adds -comet to the end the selected name, so if one sends my-amazing-DAO as name parameter,
 * its name will be my-amazing-DAO-comet.
 * Only Comet's maintainer can stake but everyone can unstake.
 * In Comets, there is a Withdrawal Queue instead of DWT.
 */

library StakeUtils {
    using DataStoreUtils for DataStoreUtils.DataStore;
    event IdInitiated(uint256 id, uint256 _type);
    event PriceChanged(uint256 id, uint256 pricePerShare);
    event MaintainerFeeUpdated(uint256 id, uint256 fee);
    event MaxMaintainerFeeUpdated(uint256 newMaxFee);
    event PausedPool(uint256 id);
    event UnpausedPool(uint256 id);
    event OperatorApproval(
        uint256 planetId,
        uint256 operatorId,
        uint256 allowance
    );
    event Alienation(bytes pubkey, bool isAlien);
    event VerificationIndexUpdated(uint256 newIndex);
    event PreStaked(bytes pubkey, uint256 planetId, uint256 operatorId);
    event BeaconStaked(bytes pubkey);

    /**
     * @param state 0: inactive, 1: proposed, 2: active, 3: withdrawn, 69: alien (https://bit.ly/3Tkc6UC)
     * @param index representing this validators placement on the chronological order of the proposed validators
     * @param planetId needed for withdrawal_credential
     * @param operatorId needed for staking after allowence
     * @param signature BLS12-381 signature of the validator
     **/
    struct Validator {
        uint8 state;
        uint256 index;
        uint256 planetId;
        uint256 operatorId;
        bytes signature;
    }
    /**
     * @notice StakePool includes the parameters related to multiple Staking Pool Contracts.
     * @notice A staking pool works with a *bound* Withdrawal Pool (DWP) to create best pricing
     * for the staking derivative. Withdrawal Pools (DWP) uses StableSwap algorithm with Dynamic Pegs.
     * @dev  gETH should not be changed, ever!
     * @param ORACLE https://github.com/Geodefi/Telescope-Eth
     * @param gETH ERC1155 contract that keeps the totalSupply, pricePerShare and balances of all StakingPools by ID
     * @param DEFAULT_gETH_INTERFACE
     * @param DEFAULT_DWP Dynamic Withdrawal Pool, a STABLESWAP pool that will be cloned to be used for given ID
     * @param DEFAULT_LP_TOKEN LP token implementation that will be cloned to be used for DWP of given ID
     * @param DEFAULT_A DWP parameter
     * @param DEFAULT_FEE DWP parameter
     * @param DEFAULT_ADMIN_FEE DWP parameter
     * @param MAX_MAINTAINER_FEE : limits fees, set by GOVERNANCE
     * @param VERIFICATION_INDEX the highest index of the validators that are verified to be activated. Updated by Telescope. set to 0 at start
     * @param VALIDATORS_INDEX total number of validators that are proposed at some point. includes all states of validators. set to 0 at start
     * @param Validators : pubKey to Validator
     * @dev changing any of address parameters (gETH, ORACLE, DEFAULT_DWP, DEFAULT_LP_TOKEN) MUST require a contract upgrade to ensure security. We can change this in the future with a better GeodeUtils design.
     **/
    struct StakePool {
        address ORACLE;
        address gETH;
        address DEFAULT_gETH_INTERFACE;
        address DEFAULT_DWP;
        address DEFAULT_LP_TOKEN;
        uint256 DEFAULT_A;
        uint256 DEFAULT_FEE;
        uint256 DEFAULT_ADMIN_FEE;
        uint256 MAX_MAINTAINER_FEE;
        uint256 PERIOD_PRICE_INCREASE_LIMIT;
        uint256 VERIFICATION_INDEX;
        uint256 VALIDATORS_INDEX;
        mapping(bytes => Validator) Validators;
    }

    /**
     * @notice gETH lacks *decimals*,
     * @dev gETH_DENOMINATOR makes sure that we are taking care of decimals on calculations related to gETH
     */
    uint256 public constant gETH_DENOMINATOR = 1e18;
    uint256 public constant IGNORABLE_DEBT = 1 ether;

    // TODO: type check?
    modifier onlyMaintainer(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) {
        require(
            msg.sender == _DATASTORE.readAddressForId(_id, "maintainer"),
            "StakeUtils: sender is NOT maintainer"
        );
        _;
    }

    modifier onlyOracle(StakePool storage self) {
        require(msg.sender == self.ORACLE, "StakeUtils: sender is NOT ORACLE");
        _;
    }

    modifier onlyGovernance(address GOVERNANCE) {
        require(
            msg.sender == GOVERNANCE,
            "StakeUtils: sender is NOT GOVERNANCE"
        );
        _;
    }

    modifier initiator(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _type,
        address _maintainer
    ) {
        require(
            msg.sender == _DATASTORE.readAddressForId(_id, "CONTROLLER"),
            "StakeUtils: sender is NOT CONTROLLER"
        );

        require(
            _DATASTORE.readUintForId(_id, "TYPE") == _type,
            "StakeUtils: id should be Operator TYPE"
        );
        require(
            _DATASTORE.readUintForId(_id, "initiated") == 0,
            "StakeUtils: already initiated"
        );

        _DATASTORE.writeAddressForId(_id, "maintainer", _maintainer);

        _;

        _DATASTORE.writeUintForId(_id, "initiated", 1);
        emit IdInitiated(_id, _type);
    }

    function _clone(address target) public returns (address) {
        return Clones.clone(target);
    }

    function _getKey(uint256 _id, string memory _param)
        internal
        pure
        returns (bytes32)
    {
        return bytes32(keccak256(abi.encodePacked(_id, _param)));
    }

    function getgETH(StakePool storage self) public view returns (IgETH) {
        return IgETH(self.gETH);
    }

    /**
     * @notice mints gETH tokens with given ID and amount.
     * @dev shouldn't be accesible publicly
     */
    function _mint(
        address _gETH,
        address _to,
        uint256 _id,
        uint256 _amount
    ) internal {
        require(_id > 0, "StakeUtils: _mint id should be > 0");
        IgETH(_gETH).mint(_to, _id, _amount, "");
    }

    /**
     *  @notice if a planet did not unset an old Interface, before setting a new one;
     *  & if new interface is unset, the old one will not be remembered!!
     *  use gETH.isInterface(interface,  id)
     * @param _Interface address of the new gETH ERC1155 interface for given ID
     * @param isSet true if new interface is going to be set, false if old interface is being unset
     */
    function _setInterface(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        address _Interface,
        bool isSet
    ) internal {
        getgETH(self).setInterface(_Interface, _id, isSet);
        if (isSet)
            _DATASTORE.writeAddressForId(_id, "currentInterface", _Interface);
        else if (
            _DATASTORE.readAddressForId(_id, "currentInterface") == _Interface
        ) _DATASTORE.writeAddressForId(_id, "currentInterface", address(0));
    }

    /**
     * @notice                      ** Initiate ID functions **
     */
    /**
     * @notice initiates ID as an node operator
     * @dev requires ID to be approved as a node operator with a specific CONTROLLER
     * @param _id
     * @param _cometPeriod
     */
    function initiateOperator(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        uint256 _cometPeriod
    ) external initiator(_DATASTORE, _id, 4, _maintainer) {
        setMaintainerFee(self, _DATASTORE, _id, _fee);
        updateCometPeriod(_DATASTORE, _id, _cometPeriod);
    }

    /**
     * @notice initiates ID as a planet (public pool)
     * @dev requires ID to be approved as a planet with a specific CONTROLLER
     * @param _id
     */
    function initiatePlanet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        address _GOVERNANCE,
        string memory _interfaceName,
        string memory _interfaceSymbol
    ) external initiator(_DATASTORE, _id, 5, _maintainer) {
        {
            address currentInterface = _clone(self.DEFAULT_gETH_INTERFACE);
            address gEth = address(getgETH(self));
            ERC20InterfacePermitUpgradable(currentInterface).initialize(
                _id,
                _interfaceName,
                _interfaceSymbol,
                gEth
            );
            _setInterface(self, _DATASTORE, _id, currentInterface, true);
        }

        setMaintainerFee(self, _DATASTORE, _id, _fee);

        address WithdrawalPool = _deployWithdrawalPool(self, _DATASTORE, _id);
        // transfer ownership of DWP to GEODE.GOVERNANCE
        Ownable(WithdrawalPool).transferOwnership(_GOVERNANCE);
        // approve token so we can use it in buybacks
        getgETH(self).setApprovalForAll(WithdrawalPool, true);
        // initially 1 ETHER = 1 ETHER
        _setPricePerShare(self, 1 ether, _id);
    }

    /**
     * @notice initiates ID as a comet (private pool)
     * @dev requires ID to be approved as comet with a specific CONTROLLER
     * @param _id
     */
    function initiateComet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer
    ) external initiator(_DATASTORE, _id, 6, _maintainer) {
        setMaintainerFee(self, _DATASTORE, _id, _fee);
    }

    /**
     * @notice                      ** Maintainer specific functions **
     */

    /**
     * @notice "Maintainer" is a shared logic (like "name") by both operators and private or public pools.
     * Maintainers have permissiones to maintain the given id like setting a new fee or interface as
     * well as creating validators etc. for operators.
     * @dev every ID has 1 maintainer that is set by CONTROLLER
     */
    function getMaintainerFromId(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) external view returns (address maintainer) {
        maintainer = _DATASTORE.readAddressForId(_id, "maintainer");
    }

    /**
     * @notice CONTROLLER of the ID can change the maintainer to any address other than ZERO_ADDRESS
     * @dev it is wise to change the CONTROLLER before the maintainer, in case of any migration
     * @dev handle with care
     * note, intended (suggested) usage is to set a contract address that will govern the id for maintainer,
     * while keeping the controller as a multisig or provide smt like 0x000000000000000000000000000000000000dEaD
     */
    function changeMaintainer(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        address _newMaintainer
    ) external {
        require(
            msg.sender == _DATASTORE.readAddressForId(_id, "CONTROLLER"),
            "StakeUtils: sender is NOT CONTROLLER"
        );

        require(
            _newMaintainer != address(0),
            "StakeUtils: maintainer can NOT be zero"
        );

        _DATASTORE.writeAddressForId(_id, "maintainer", _newMaintainer);
    }

    /**
     * @notice Gets fee percentage in terms of FEE_DENOMINATOR.
     * @dev even if MAX_MAINTAINER_FEE is decreased later, it returns limited maximum.
     * @param _id planet, comet or operator ID
     * @return fee = percentage * FEE_DENOMINATOR / 100
     */
    function getMaintainerFee(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (uint256 fee) {
        return
            _DATASTORE.readUintForId(_id, "fee") > self.MAX_MAINTAINER_FEE
                ? self.MAX_MAINTAINER_FEE
                : _DATASTORE.readUintForId(_id, "fee");
    }

    /**
     * @notice Changes the fee that is applied by distributeFee on Oracle Updates.
     * @dev to achieve 100% fee send FEE_DENOMINATOR
     * @param _id planet, comet or operator ID
     * @param _newFee new fee percentage in terms of FEE_DENOMINATOR,reverts if given more than MAX_MAINTAINER_FEE
     */
    function setMaintainerFee(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _newFee
    ) public onlyMaintainer(_DATASTORE, _id) {
        require(
            _newFee <= self.MAX_MAINTAINER_FEE,
            "StakeUtils: MAX_MAINTAINER_FEE ERROR"
        );
        _DATASTORE.writeUintForId(_id, "fee", _newFee);
        emit MaintainerFeeUpdated(_id, _newFee);
    }

    /**
     * @notice                      ** Governance specific functions **
     */

    /**
     * @notice Changes MAX_MAINTAINER_FEE, limits "fee" parameter of every ID.
     * @dev to achieve 100% fee send FEE_DENOMINATOR
     * @param _newMaxFee new fee percentage in terms of FEE_DENOMINATOR, reverts if more than FEE_DENOMINATOR
     * note onlyGovernance check
     */
    function setMaxMaintainerFee(
        StakePool storage self,
        address _GOVERNANCE,
        uint256 _FEE_DENOMINATOR,
        uint256 _newMaxFee
    ) external onlyGovernance(_GOVERNANCE) {
        require(
            _newMaxFee <= _FEE_DENOMINATOR,
            "StakeUtils: fee more than 100%"
        );
        self.MAX_MAINTAINER_FEE = _newMaxFee;
        emit MaxMaintainerFeeUpdated(_newMaxFee);
    }

    /**
     * note onlyGovernance check
     */
    function releasePrisoned(
        DataStoreUtils.DataStore storage _DATASTORE,
        address _GOVERNANCE,
        uint256 operatorId
    ) external onlyGovernance(_GOVERNANCE) {
        _DATASTORE.writeUintForId(operatorId, "released", 0);
    }

    /**
     * @notice                      ** Operator (TYPE 4) specific functions **
     */

    /** *
     * @notice operatorAllowence is the number of validators that the given Operator is allowed to create on behalf of the Planet
     * @dev an operator can not create new validators if,
     * allowence is 0 (zero) OR lower than the current number of validators.
     * But if operator withdraws a validator,then able to create a new one.
     * @dev prestake checks the approved validator count to make sure the number of validators are not bigger than allowence.
     * @dev allowence doesn't change when new validators created or old ones are unstaked.
     * @return allowance
     */
    function operatorAllowance(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _planetId,
        uint256 _operatorId
    ) public view returns (uint256 allowance) {
        allowance = _DATASTORE.readUintForId(
            _planetId,
            _getKey(_operatorId, "allowance")
        );
    }

    /**
     * @notice To allow a Node Operator run validators for your Planet with Max number of validators.
     * This number can be set again at any given point in the future.
     *
     * @dev If planet decreases the approved validator count, below current running validator,
     * operator can only withdraw until to that count (until 1 below that count).
     * @dev only maintainer of _planetId can approve an Operator
     * @param _planetId the gETH id of the Planet, only Maintainer can call this function
     * @param _operatorId the id of the Operator to allow them create validators for a given Planet
     * @param _allowance the MAX number of validators that can be created by the Operator for a given Planet
     */
    function approveOperator(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _planetId,
        uint256 _operatorId,
        uint256 _allowance
    ) external onlyMaintainer(_DATASTORE, _planetId) returns (bool) {
        _DATASTORE.writeUintForId(
            _planetId,
            _getKey(_operatorId, "allowance"),
            _allowance
        );
        emit OperatorApproval(_planetId, _operatorId, _allowance);
        return true;
    }

    /**
     * @notice Operator wallet keeps Ether put in Portal by Operator to make preStake easier, instead of sending n ETH to contract
     * while preStaking for n validator(s) for each time. Operator can put some ETHs to their wallet
     * and from there, ETHs can be used to preStake. Then when it is approved and staked, it will be
     * added back to the wallet to be used for other preStake calls.
     * @param _operatorId the id of the Operator
     * @return walletBalance the balance of Operator with the given _operatorId has
     */
    function getOperatorWalletBalance(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) public view returns (uint256 walletBalance) {
        walletBalance = _DATASTORE.readUintForId(_operatorId, "wallet");
    }

    /**
     * @notice To increase the balance of an Operator's wallet
     * @dev only maintainer can increase the balance
     * @param _operatorId the id of the Operator
     * @param value Ether (in Wei) amount to increase the wallet balance.
     * @return success boolean value which is true if successful, should be used by Operator is Maintainer is a contract.
     */
    function _increaseOperatorWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) internal returns (bool success) {
        _DATASTORE.writeUintForId(
            _operatorId,
            "wallet",
            _DATASTORE.readUintForId(_operatorId, "wallet") + value
        );
        return true;
    }

    /**
     * @notice external version of _increaseOperatorWallet()
     */
    function increaseOperatorWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) external onlyMaintainer(_DATASTORE, _operatorId) returns (bool success) {
        return _increaseOperatorWallet(_DATASTORE, _operatorId, msg.value);
    }

    /**
     * @notice To decrease the balance of an Operator's wallet
     * @dev only maintainer can decrease the balance
     * @param _operatorId the id of the Operator
     * @param value Ether (in Wei) amount to decrease the wallet balance and send back to Maintainer.
     * @return success boolean value which is "sent", should be used by Operator is Maintainer is a contract.
     */
    function _decreaseOperatorWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) internal returns (bool success) {
        uint256 _balance = _DATASTORE.readUintForId(_operatorId, "wallet");
        require(
            _balance >= value,
            "StakeUtils: Not enough resources in operatorWallet"
        );
        _balance -= value;
        _DATASTORE.writeUintForId(_operatorId, "wallet", _balance);
        return true;
    }

    /**
     * @notice external version of _decreaseOperatorWallet()
     */
    function decreaseOperatorWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) external onlyMaintainer(_DATASTORE, _operatorId) returns (bool success) {
        require(
            address(this).balance >= value,
            "StakeUtils: Not enough resources in Portal"
        );
        bool decreased = _decreaseOperatorWallet(
            _DATASTORE,
            _operatorId,
            value
        );

        (bool sent, ) = msg.sender.call{value: value}("");
        require(decreased && sent, "StakeUtils: Failed to send ETH");
        return sent;
    }

    function getCometPeriod(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) external view onlyMaintainer(_DATASTORE, _operatorId) returns (uint256) {
        return _DATASTORE.readUintForId(_operatorId, "cometPeriod");
    }

    function updateCometPeriod(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 _newPeriod
    ) public onlyMaintainer(_DATASTORE, _operatorId) {
        _DATASTORE.writeUintForId(_operatorId, "cometPeriod", _newPeriod);
    }

    function isPrisoned(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId
    ) public view returns (bool _isPrisoned) {
        _isPrisoned =
            block.timestamp > _DATASTORE.readUintForId(_operatorId, "released");
    }

    /**
     * @notice                      ** WITHDRAWAL POOL specific functions **
     */

    /**
     * @notice conducts a buyback using the given withdrawal pool,
     * @param to address to send bought gETH(id). burns the tokens if to=address(0), transfers if not
     * @param poolId id of the gETH that will be bought
     * @param sellEth ETH amount to sell
     * @param minToBuy TX is expected to revert by Swap.sol if not meet
     * @param deadline TX is expected to revert by Swap.sol if deadline has past
     * @dev this function assumes that pool is deployed by deployWithdrawalPool
     * as index 0 is eth and index 1 is Geth
     */
    function _buyback(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        address to,
        uint256 poolId,
        uint256 sellEth,
        uint256 minToBuy,
        uint256 deadline
    ) internal returns (uint256 outAmount) {
        // SWAP in WP
        outAmount = withdrawalPoolById(_DATASTORE, poolId).swap{value: sellEth}(
            0,
            1,
            sellEth,
            minToBuy,
            deadline
        );
        if (to == address(0)) {
            // burn
            getgETH(self).burn(address(this), poolId, outAmount);
        } else {
            // send back to user
            getgETH(self).safeTransferFrom(
                address(this),
                to,
                poolId,
                outAmount,
                ""
            );
        }
    }

    function withdrawalPoolById(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (ISwap) {
        return ISwap(_DATASTORE.readAddressForId(_id, "withdrawalPool"));
    }

    function LPTokenById(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (ILPToken) {
        return ILPToken(_DATASTORE.readAddressForId(_id, "LPToken"));
    }

    /**
     * @notice deploys a new withdrawal pool using DEFAULT_DWP
     * @dev sets the withdrawal pool and LP token for id
     */
    function _deployWithdrawalPool(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) internal returns (address WithdrawalPool) {
        WithdrawalPool = _clone(self.DEFAULT_DWP);

        address _WPToken = ISwap(WithdrawalPool).initialize(
            address(getgETH(self)),
            _id,
            string(
                abi.encodePacked(
                    _DATASTORE.readBytesForId(_id, "name"),
                    "-Geode WP Token"
                )
            ),
            string(
                abi.encodePacked(_DATASTORE.readBytesForId(_id, "name"), "-WP")
            ),
            self.DEFAULT_A,
            self.DEFAULT_FEE,
            self.DEFAULT_ADMIN_FEE,
            self.DEFAULT_LP_TOKEN
        );
        _DATASTORE.writeAddressForId(_id, "withdrawalPool", WithdrawalPool);
        _DATASTORE.writeAddressForId(_id, "LPToken", _WPToken);
    }

    /**
     * @notice pausing only prevents new staking operations.
     * when a pool is paused for staking there are NO new funds to be minted, NO surplus.
     * @dev minting is paused when stakePaused != 0
     */
    function isStakingPausedForPool(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (bool) {
        return _DATASTORE.readUintForId(_id, "stakePaused") != 0;
    }

    /**
     * @dev pausing requires pool to be NOT paused
     */
    function pauseStakingForPool(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) external onlyMaintainer(_DATASTORE, _id) {
        require(
            !isStakingPausedForPool(_DATASTORE, _id),
            "StakeUtils: staking is already paused for pool"
        );
        _DATASTORE.writeUintForId(_id, "stakePaused", 1); // meaning true
        emit PausedPool(_id);
    }

    /**
     * @dev pausing requires pool to be NOT paused
     */
    function unpauseStakingForPool(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) external onlyMaintainer(_DATASTORE, _id) {
        require(
            isStakingPausedForPool(_DATASTORE, _id),
            "StakeUtils: staking is already NOT paused for pool"
        );
        _DATASTORE.writeUintForId(_id, "stakePaused", 0); // meaning false
        emit UnpausedPool(_id);
    }

    /**
     * @notice                      ** ORACLE specific functions **
     */

    /**
     * @notice Batch validator verification
     */

    /**
     * @notice Updating VERIFICATION_INDEX, signaling that it is safe to allow
     * validators with lower index than VERIFICATION_INDEX to stake with staking pool funds.
     * @param new_index index of the highest validator that is verified to be activated
     * @param alienPubkeys array of validator pubkeys that are lower than new_index which also
     * either frontrunned preStake function thus alienated OR proven to be mistakenly alienated.
     */
    function updateVerificationIndex(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 new_index,
        bytes[] calldata alienPubkeys,
        bytes[] calldata curedPubkeys,
        bytes[] calldata prisonedIds
    ) external onlyOracle(self) {
        require(self.VALIDATORS_INDEX >= new_index);
        require(new_index >= self.VERIFICATION_INDEX);

        uint256 i;
        uint256 planetId;
        for (; i < alienPubkeys.length; ++i) {
            require(
                self.Validators[alienPubkeys[i]].state == 1,
                "StakeUtils: NOT all alienPubkeys are pending"
            );
            planetId = self.Validators[alienPubkeys[i]].planetId;
            self.Validators[alienPubkeys[i]].state = 69;

            _DATASTORE.writeUintForId(
                planetId,
                "secured",
                _DATASTORE.readUintForId(planetId, "secured") -
                    DCU.DEPOSIT_AMOUNT
            );
            _DATASTORE.writeUintForId(
                planetId,
                "surplus",
                _DATASTORE.readUintForId(planetId, "surplus") +
                    DCU.DEPOSIT_AMOUNT
            );

            emit Alienation(alienPubkeys[i], true);
        }

        for (i = 0; i < curedPubkeys.length; ++i) {
            require(
                self.Validators[curedPubkeys[i]].state == 69,
                "StakeUtils: NOT all curedPubkeys are alienated"
            );
            if (
                _DATASTORE.readUintForId(planetId, "surplus") >=
                DCU.DEPOSIT_AMOUNT
            ) {
                planetId = self.Validators[alienPubkeys[i]].planetId;
                self.Validators[curedPubkeys[i]].state = 1;

                _DATASTORE.writeUintForId(
                    planetId,
                    "surplus",
                    _DATASTORE.readUintForId(planetId, "surplus") -
                        DCU.DEPOSIT_AMOUNT
                );

                _DATASTORE.writeUintForId(
                    planetId,
                    "secured",
                    _DATASTORE.readUintForId(planetId, "secured") +
                        DCU.DEPOSIT_AMOUNT
                );

                emit Alienation(curedPubkeys[i], false);
            }
        }

        for (i = 0; i < prisonedIds.length; ++i) {
            _DATASTORE.writeUintForId(
                self.Validators[prisonedIds[i]].operatorId,
                "released",
                block.timestamp + 7 days
            );
        }

        self.VERIFICATION_INDEX = new_index;
        emit VerificationIndexUpdated(new_index);
    }

    /**
     * @notice Updating PricePerShare
     */

    /**
     * @notice sets pricePerShare parameter of gETH(id)
     * @dev only ORACLE should be able to reach this after sanity checks on a new price
     */
    function _setPricePerShare(
        StakePool storage self,
        uint256 pricePerShare_,
        uint256 _id
    ) internal {
        require(_id > 0, "StakeUtils: id should be > 0");
        getgETH(self).setPricePerShare(pricePerShare_, _id);
        emit PriceChanged(_id, pricePerShare_);
    }

    /**
     * @notice _getPricePerShare is a reliable source for any contract operation
     * @dev aka *mint price*
     */
    function _getPricePerShare(StakePool storage self, uint256 _id)
        internal
        view
        returns (uint256 _oraclePrice)
    {
        _oraclePrice = getgETH(self).pricePerShare(_id);
    }

    /**
     * @notice                      ** STAKING functions **
     */

    /**
     *  @notice Creation of a Validator takes 3 steps. Before entering stakeBeacon function,
     *  canStake verifies the eligibility of given pubKey that is proposed by an operator
     *  with Prestake function. Eligibility is defined by alienation, check alienate() for info.
     *
     *  @param pubkey BLS12-381 public key of the validator
     *  @return true if:
     *   - pubkey should be preStaked
     *   - validator's index should be lower than VERIFICATION_INDEX, updated by TELESCOPE
     *   - pubkey should not be alienated (https://bit.ly/3Tkc6UC)
     *  else:
     *      return false
     */
    function canStake(StakePool storage self, bytes calldata pubkey)
        public
        view
        returns (bool)
    {
        return
            self.Validators[pubkey].state == 1 &&
            self.Validators[pubkey].index <= self.VERIFICATION_INDEX;
    }

    /**
     * @notice staking function. buys if price is low, mints new tokens if a surplus is sent (extra ETH through msg.value)
     * @param poolId id of the staking pool, withdrawal pool and gETH to be used.
     * @param mingETH withdrawal pool parameter
     * @param deadline withdrawal pool parameter
     * // d  m.v
     * // 100 10 => buyback
     * // 100 100  => buyback
     * // 10 100  =>  buyback + mint
     * // 0 x => mint
     */
    function stakePlanet(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 poolId,
        uint256 mingETH,
        uint256 deadline
    ) external returns (uint256 totalgETH) {
        require(msg.value > 0, "StakeUtils: no eth given");
        require(
            !isStakingPausedForPool(_DATASTORE, poolId),
            "StakeUtils: minting is paused"
        );
        uint256 debt = withdrawalPoolById(_DATASTORE, poolId).getDebt();
        if (debt >= msg.value) {
            return
                _buyback(
                    self,
                    _DATASTORE,
                    msg.sender,
                    poolId,
                    msg.value,
                    mingETH,
                    deadline
                );
        } else {
            uint256 boughtgETH = 0;
            uint256 remEth = msg.value;
            if (debt > IGNORABLE_DEBT) {
                boughtgETH = _buyback(
                    self,
                    _DATASTORE,
                    msg.sender,
                    poolId,
                    debt,
                    0,
                    deadline
                );
                remEth -= debt;
            }
            uint256 mintgETH = (
                ((remEth * gETH_DENOMINATOR) / _getPricePerShare(self, poolId))
            );
            _mint(self.gETH, msg.sender, poolId, mintgETH);
            _DATASTORE.writeUintForId(
                poolId,
                "surplus",
                _DATASTORE.readUintForId(poolId, "surplus") + remEth
            );
            require(
                boughtgETH + mintgETH >= mingETH,
                "StakeUtils: less than mingETH"
            );
            return boughtgETH + mintgETH;
        }
    }

    /**
     *  @notice Validator Credentials Proposal function, first step of crating validators. Once a pubKey is proposed and not alienated for some time,
     *  it is optimistically allowed to take funds from staking pools.
     *  @param planetId the id of the staking pool whose TYPE can be 5 or 6.
     *  @param operatorId the id of the Operator whose maintainer calling this function
     *  @param pubkeys  Array of BLS12-381 public keys of the validators that will be proposed
     *  @param signatures Array of BLS12-381 signatures of the validators that will be proposed
     *
     *  @dev DEPOSIT_AMOUNT_PRESTAKE = 1 ether, which is the minimum number to create validator.
     *  31 Ether will be staked after verification of oracles. 32 in total.
     *  1 ether will e sent back to Node Operator when finalized deposit is successful.
     *  @dev Prestake requires enough allowance from Staking Pools to Operators.
     *  @dev Prestake requires enough funds within operatorWallet.
     *  @dev Max number of validators to propose is MAX_DEPOSITS_PER_CALL (currently 64)
     *  @return i = successful proposal count, starting from the first element of pubkeys. Even in occurance of one unsucessful deposit.
     */
    function preStake(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 planetId,
        uint256 operatorId,
        bytes[] calldata pubkeys,
        bytes[] calldata signatures
    ) external onlyMaintainer(_DATASTORE, operatorId) returns (uint256 i) {
        require(
            isPrisoned(_DATASTORE, operatorId),
            "StakeUtils: you are in prison, get in touch with governance"
        );
        require(
            _DATASTORE.readUintForId(planetId, "TYPE") == 5 ||
                _DATASTORE.readUintForId(planetId, "TYPE") == 6,
            "StakeUtils: There is no pool with id"
        );
        require(
            pubkeys.length == signatures.length,
            "StakeUtils: pubkeys and signatures should be same length"
        );
        require(
            pubkeys.length > 0 && pubkeys.length <= DCU.MAX_DEPOSITS_PER_CALL,
            "StakeUtils: 1 to 64 nodes per transaction"
        );

        uint256 createdValidators = _DATASTORE.readUintForId(
            planetId,
            _getKey(operatorId, "createdValidators")
        );

        require(
            operatorAllowance(_DATASTORE, planetId, operatorId) >=
                pubkeys.length + createdValidators,
            "StakeUtils: not enough allowance"
        );

        _decreaseOperatorWallet(
            _DATASTORE,
            operatorId,
            pubkeys.length * DCU.DEPOSIT_AMOUNT_PRESTAKE
        );

        uint256 surplus = _DATASTORE.readUintForId(planetId, "surplus");
        require(
            surplus <= DCU.DEPOSIT_AMOUNT * pubkeys.length,
            "StakeUtils: not enough surplus"
        );

        uint256 valIndex = self.VALIDATORS_INDEX;
        for (; i < pubkeys.length; ++i) {
            // TODO: discuss this alienated to be checked or not
            // possibly not needed since if the preStakeTimeStamp is 0
            // then there is no possibility that it is alienated
            require(
                self.Validators[pubkeys[i]].state == 0,
                "StakeUtils: Pubkey is already used or alienated"
            );
            require(
                pubkeys[i].length == DCU.PUBKEY_LENGTH,
                "StakeUtils: PUBKEY_LENGTH ERROR"
            );
            require(
                signatures[i].length == DCU.SIGNATURE_LENGTH,
                "StakeUtils: SIGNATURE_LENGTH ERROR"
            );
            {
                // TODO: there is no deposit contract, solve and open this comment
                // DCU.depositValidator(
                //     pubkeys[i],
                //     _DATASTORE.readBytesForId(planetId, "withdrawalCredential"),
                //     signatures[i],
                //     DCU.DEPOSIT_AMOUNT_PRESTAKE
                // );
            }

            valIndex += 1;
            self.Validators[pubkeys[i]] = Validator(
                1,
                valIndex,
                planetId,
                operatorId,
                signatures[i]
            );
            emit PreStaked(pubkeys[i], planetId, operatorId);
        }

        _DATASTORE.writeUintForId(
            planetId,
            _getKey(operatorId, "createdValidators"),
            createdValidators + i
        );

        _DATASTORE.writeUintForId(
            planetId,
            "surplus",
            surplus - DCU.DEPOSIT_AMOUNT * i
        );

        _DATASTORE.writeUintForId(
            planetId,
            "secured",
            _DATASTORE.readUintForId(planetId, "secured") +
                DCU.DEPOSIT_AMOUNT *
                i
        );

        self.VALIDATORS_INDEX = valIndex;
    }

    /**
     *  @notice Sends 31 Eth from staking pool to validators that are previously created with PreStake.
     *  1 Eth per successful validator boostraping is returned back to OperatorWallet.
     *
     *  @param operatorId the id of the Operator whose maintainer calling this function
     *  @param pubkeys  Array of BLS12-381 public keys of the validators that are already proposed with PreStake.
     *
     *  @dev To save gas cost, pubkeys should be arranged by planedIds.
     *  ex: [pk1, pk2, pk3, pk4, pk5, pk6, pk7]
     *  pk1, pk2, pk3 from planet1
     *  pk4, pk5 from planet2
     *  pk6 from planet3
     *  seperate them in similar groups as much as possible.
     *  @dev Max number of validators to boostrap is MAX_DEPOSITS_PER_CALL (currently 64)
     *  @dev A pubkey that is alienated will not get through. Do not frontrun during PreStake.
     *  @return i = successful deposit count, starting from the first element of pubkeys. Even in occurance of one unsucessful deposit.
     */
    function stakeBeacon(
        StakePool storage self,
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 operatorId,
        bytes[] calldata pubkeys
    ) external onlyMaintainer(_DATASTORE, operatorId) returns (uint256 i) {
        require(
            pubkeys.length > 0 && pubkeys.length <= DCU.MAX_DEPOSITS_PER_CALL,
            "StakeUtils: 1 to 64 nodes per transaction"
        );

        for (; i < pubkeys.length; ++i) {
            require(
                canStake(self, pubkeys[i]),
                "StakeUtils: NOT all pubkeys are stakeable"
            );
        }

        uint256 planetId = self.Validators[pubkeys[0]].planetId;
        uint256 secured = _DATASTORE.readUintForId(planetId, "secured");
        require(
            secured <= DCU.DEPOSIT_AMOUNT * pubkeys.length,
            "StakeUtils: not enough secured(?)"
        );
        bytes32 activeValKey = _getKey(operatorId, "activeValidators");

        bytes memory withdrawalCredential = _DATASTORE.readBytesForId(
            planetId,
            "withdrawalCredential"
        );

        bytes memory signature;
        uint256 lastPlanetChange;
        uint256 newActiveVal;
        for (i = 0; i < pubkeys.length; ++i) {
            if (planetId != self.Validators[pubkeys[i]].planetId) {
                _DATASTORE.writeUintForId(planetId, "secured", secured);

                newActiveVal =
                    _DATASTORE.readUintForId(planetId, activeValKey) +
                    i -
                    lastPlanetChange;
                _DATASTORE.writeUintForId(planetId, activeValKey, newActiveVal);

                lastPlanetChange = i;

                planetId = self.Validators[pubkeys[i]].planetId;
                withdrawalCredential = _DATASTORE.readBytesForId(
                    planetId,
                    "withdrawalCredential"
                );
                secured = _DATASTORE.readUintForId(planetId, "secured");
            }

            signature = self.Validators[pubkeys[i]].signature;

            // TODO: there is no deposit contract, solve and open this comment
            // DCU.depositValidator(
            //     pubkeys[i],
            //     withdrawalCredential,
            //     signature,
            //     DCU.DEPOSIT_AMOUNT - DCU.DEPOSIT_AMOUNT_PRESTAKE
            // );

            self.Validators[pubkeys[i]].state = 2;
            emit BeaconStaked(pubkeys[i]);
        }

        _DATASTORE.writeUintForId(
            planetId,
            "secured",
            secured - DCU.DEPOSIT_AMOUNT * i
        );

        newActiveVal =
            _DATASTORE.readUintForId(planetId, activeValKey) +
            i -
            lastPlanetChange;
        _DATASTORE.writeUintForId(planetId, activeValKey, newActiveVal);

        _increaseOperatorWallet(
            _DATASTORE,
            operatorId,
            DCU.DEPOSIT_AMOUNT_PRESTAKE * i
        );
    }
}
