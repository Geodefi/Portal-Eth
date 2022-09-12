// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./DataStoreUtilsLib.sol";
import "../../interfaces/IgETH.sol";
import "../../interfaces/IMiniGovernance.sol";
import {IERC20InterfacePermitUpgradable as IgETHInterface} from "../../interfaces/IERC20InterfacePermitUpgradable.sol";
import "../../interfaces/ISwap.sol";
import "../../interfaces/ILPToken.sol";

/**
 * @title MaintainerUtils library to be used with a DataStore
 * @notice for Geode, there are different TYPEs active within Staking operations.
 * These types(4,5,6) always has a maintainer.
 * The staking logic is shaped around the control of maintainers over pools.
 *
 * @dev ALL "fee" variables are limited by PERCENTAGE_DENOMINATOR = 100%
 * Note refer to DataStoreUtils before reviewing
 */
library MaintainerUtils {
    using DataStoreUtils for DataStoreUtils.DataStore;

    event IdInitiated(uint256 id, uint256 TYPE);
    event MaintainerFeeSwitched(
        uint256 id,
        uint256 fee,
        uint256 effectiveTimestamp // the timestamp when the fee will start to be used after switch
    );
    event MaintainerChanged(uint256 id, address newMaintainer);

    /// @notice PERCENTAGE_DENOMINATOR represents 100%
    uint256 public constant PERCENTAGE_DENOMINATOR = 10**10;

    /// @notice when a maintainer changes the fee, it is effective after a delay
    uint256 public constant FEE_SWITCH_LATENCY = 7 days;

    /// @notice default DWP parameters
    uint256 public constant DEFAULT_A = 60;
    uint256 public constant DEFAULT_FEE = (4 * PERCENTAGE_DENOMINATOR) / 10000;
    uint256 public constant DEFAULT_ADMIN_FEE =
        (5 * PERCENTAGE_DENOMINATOR) / 10;

    modifier initiator(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _TYPE,
        uint256 _id,
        address _maintainer
    ) {
        require(
            msg.sender == DATASTORE.readAddressForId(_id, "CONTROLLER"),
            "StakeUtils: sender NOT CONTROLLER"
        );
        require(
            DATASTORE.readUintForId(_id, "TYPE") == _TYPE,
            "StakeUtils: id NOT correct TYPE"
        );
        require(
            DATASTORE.readUintForId(_id, "initiated") == 0,
            "StakeUtils: already initiated"
        );

        DATASTORE.writeAddressForId(_id, "maintainer", _maintainer);

        _;

        DATASTORE.writeUintForId(_id, "initiated", block.timestamp);

        emit IdInitiated(_id, _TYPE);
    }

    /**
     * @notice restricts the access to given function based on TYPE
     * @notice also allows onlyMaintainer check whenever required
     * @param expectMaintainer restricts the access to only maintainer
     * @param restrictionMap 0: Operator = TYPE(4), Planet = TYPE(5), Comet = TYPE(6),
     */
    function authenticate(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        bool expectMaintainer,
        bool[3] memory restrictionMap
    ) internal view {
        if (expectMaintainer) {
            require(
                msg.sender == DATASTORE.readAddressForId(id, "maintainer"),
                "StakeUtils: sender NOT maintainer"
            );
        }
        uint256 typeOfId = DATASTORE.readUintForId(id, "TYPE");
        if (typeOfId == 4) {
            require(restrictionMap[0] == true, "StakeUtils: TYPE NOT allowed");
        } else if (typeOfId == 5) {
            require(restrictionMap[1] == true, "StakeUtils: TYPE NOT allowed");
        } else if (typeOfId == 6) {
            require(restrictionMap[2] == true, "StakeUtils: TYPE NOT allowed");
        } else revert("StakeUtils: invalid TYPE");
    }

    /**
     * @notice                      ** Initiate ID functions **
     */

    /**
     * @notice initiates ID as a node operator
     * @dev requires ID to be approved as a node operator with a specific CONTROLLER
     * @param validatorPeriod the expected maximum staking interval
     * Operator can unstake at any given point before this period ends.
     * If operator disobeys this rule, it will be prisoned
     */
    function initiateOperator(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        uint256 fee,
        address maintainer,
        uint256 validatorPeriod
    ) external initiator(DATASTORE, 4, id, maintainer) {
        DATASTORE.writeUintForId(id, "fee", fee);
        DATASTORE.writeUintForId(id, "validatorPeriod", validatorPeriod);
    }

    /**
     * @notice initiates ID as a planet (public pool): deploys a miniGovernance, a Dynamic Withdrawal Pool, an ERC1155Interface
     * @dev requires ID to be approved as a planet with a specific CONTROLLER
     * @param uintSpecs 0:_id, 1:_fee, 2:_withdrawalBoost, 3:_MINI_GOVERNANCE_VERSION
     * @param addressSpecs 0:gETH, 1:_maintainer, 2:DEFAULT_gETH_INTERFACE_, 3:DEFAULT_DWP, 4:DEFAULT_LP_TOKEN
     * @param interfaceSpecs 0: interface name, 1: interface symbol
     */
    function initiatePlanet(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256[4] memory uintSpecs,
        address[5] memory addressSpecs,
        string[2] calldata interfaceSpecs
    )
        external
        initiator(DATASTORE, 5, uintSpecs[0], addressSpecs[1])
        returns (
            address miniGovernance,
            address gInterface,
            address withdrawalPool
        )
    {
        require(
            uintSpecs[2] <= PERCENTAGE_DENOMINATOR,
            "StakeUtils: withdrawalBoost > 100%"
        );

        DATASTORE.writeUintForId(uintSpecs[0], "fee", uintSpecs[1]);
        DATASTORE.writeUintForId(uintSpecs[0], "withdrawalBoost", uintSpecs[2]);

        {
            miniGovernance = _deployMiniGovernance(
                DATASTORE,
                addressSpecs[0],
                uintSpecs[0],
                uintSpecs[3],
                addressSpecs[1]
            );
        }
        {
            gInterface = Clones.clone(addressSpecs[2]);
            IgETHInterface(gInterface).initialize(
                uintSpecs[0],
                interfaceSpecs[0],
                interfaceSpecs[1],
                addressSpecs[0]
            );
        }
        {
            withdrawalPool = _deployWithdrawalPool(
                DATASTORE,
                uintSpecs[0],
                addressSpecs[0],
                addressSpecs[3],
                addressSpecs[4]
            );
        }
    }

    /**
     * @notice initiates ID as a comet (private pool)
     * @dev requires ID to be approved as comet with a specific CONTROLLER,
     * NOTE CONTROLLER check will be surpassed with portal.
     */
    function initiateComet(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id,
        uint256 fee,
        address maintainer
    ) external initiator(DATASTORE, 6, id, maintainer) {
        DATASTORE.writeUintForId(id, "fee", fee);
    }

    /**
     * @notice deploys a mini governance contract that will be used as a withdrawal credential
     * using an approved MINI_GOVERNANCE_VERSION
     * @return miniGovernance address which is deployed
     */
    function _deployMiniGovernance(
        DataStoreUtils.DataStore storage DATASTORE,
        address _gETH,
        uint256 _id,
        uint256 _versionId,
        address _maintainer
    ) internal returns (address miniGovernance) {
        ERC1967Proxy newGovernance = new ERC1967Proxy(
            DATASTORE.readAddressForId(_versionId, "CONTROLLER"),
            abi.encodeWithSelector(
                IMiniGovernance(address(0)).initialize.selector,
                _gETH,
                _id,
                address(this),
                _maintainer,
                _versionId
            )
        );
        DATASTORE.writeAddressForId(
            _id,
            "miniGovernance",
            address(newGovernance)
        );
        miniGovernance = address(newGovernance);
    }

    /**
     * @notice deploys a new withdrawal pool using DEFAULT_DWP
     * @dev sets the withdrawal pool and LP token for id
     * @return withdrawalPool address which is deployed
     */
    function _deployWithdrawalPool(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id,
        address _gETH,
        address _DEFAULT_DWP,
        address _DEFAULT_LP_TOKEN
    ) internal returns (address withdrawalPool) {
        withdrawalPool = Clones.clone(_DEFAULT_DWP);

        address WPToken = ISwap(withdrawalPool).initialize(
            IgETH(_gETH),
            _id,
            string(
                abi.encodePacked(
                    DATASTORE.readBytesForId(_id, "name"),
                    "-Geode WP Token"
                )
            ),
            string(
                abi.encodePacked(DATASTORE.readBytesForId(_id, "name"), "-WP")
            ),
            DEFAULT_A,
            DEFAULT_FEE,
            DEFAULT_ADMIN_FEE,
            _DEFAULT_LP_TOKEN
        );
        DATASTORE.writeAddressForId(_id, "withdrawalPool", withdrawalPool);
        DATASTORE.writeAddressForId(_id, "LPToken", WPToken);
    }

    /**
     * @notice "Maintainer" is a shared logic (like "name") by both operators and private or public pools.
     * Maintainers have permissiones to maintain the given id like setting a new fee or interface as
     * well as creating validators etc. for operators.
     * @dev every ID has one maintainer that is set by CONTROLLER
     */
    function getMaintainerFromId(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external view returns (address maintainer) {
        maintainer = DATASTORE.readAddressForId(id, "maintainer");
    }

    /**
     * @notice CONTROLLER of the ID can change the maintainer to any address other than ZERO_ADDRESS
     * @dev it is wise to change the CONTROLLER before the maintainer, in case of any migration
     * @dev handle with care
     * NOTE intended (suggested) usage is to set a contract address that will govern the id for maintainer,
     * while keeping the controller as a multisig or provide smt like 0x000000000000000000000000000000000000dEaD
     */
    function _changeMaintainer(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id,
        address _newMaintainer
    ) internal {
        require(
            msg.sender == DATASTORE.readAddressForId(_id, "CONTROLLER"),
            "StakeUtils: sender NOT CONTROLLER"
        );
        require(
            _newMaintainer != address(0),
            "StakeUtils: maintainer can NOT be zero"
        );

        DATASTORE.writeAddressForId(_id, "maintainer", _newMaintainer);
        emit MaintainerChanged(_id, _newMaintainer);
    }

    /**
     * @notice Gets fee percentage in terms of PERCENTAGE_DENOMINATOR.
     * @dev even if MAX_MAINTAINER_FEE is decreased later, it returns limited maximum.
     * @param id planet, comet or operator ID
     * @return fee = percentage * PERCENTAGE_DENOMINATOR / 100 as a perfcentage
     */
    function getMaintainerFee(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external view returns (uint256 fee) {
        fee = DATASTORE.readUintForId(id, "fee");
        if (DATASTORE.readUintForId(id, "feeSwitch") >= block.timestamp) {
            fee = DATASTORE.readUintForId(id, "priorFee");
        }
    }

    /**
     * @notice Changes the fee that is applied by distributeFee on Oracle Updates.
     * @dev advise that 100% == PERCENTAGE_DENOMINATOR
     * @param _id planet, comet or operator ID
     */
    function _switchMaintainerFee(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id,
        uint256 _newFee
    ) internal {
        DATASTORE.writeUintForId(
            _id,
            "priorFee",
            DATASTORE.readUintForId(_id, "fee")
        );
        DATASTORE.writeUintForId(
            _id,
            "feeSwitch",
            block.timestamp + FEE_SWITCH_LATENCY
        );
        DATASTORE.writeUintForId(_id, "fee", _newFee);

        emit MaintainerFeeSwitched(
            _id,
            _newFee,
            block.timestamp + FEE_SWITCH_LATENCY
        );
    }

    /**
     * @notice When a fee is collected it is put in the maintainer's wallet
     * @notice Maintainer wallet also keeps Ether put in Portal by Operator Maintainer to make proposeStake easier, instead of sending n ETH to contract
     * while preStaking for n validator(s) for each time. Operator can put some ETHs to their wallet
     * and from there, ETHs can be used to proposeStake. Then when it is approved and staked, it will be
     * added back to the wallet to be used for other proposeStake calls.
     * @param id the id of the Maintainer
     * @return walletBalance the balance of Operator with the given _operatorId has
     */
    function getMaintainerWalletBalance(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 id
    ) external view returns (uint256 walletBalance) {
        walletBalance = DATASTORE.readUintForId(id, "wallet");
    }

    /**
     * @notice To increase the balance of an Maintainer's wallet
     * @param _id the id of the Operator
     * @param _value Ether (in Wei) amount to increase the wallet balance.
     * @return success boolean value which is true if successful, should be used by Operator is Maintainer is a contract.
     */
    function _increaseMaintainerWallet(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id,
        uint256 _value
    ) internal returns (bool success) {
        DATASTORE.addUintForId(_id, "wallet", _value);
        return true;
    }

    /**
     * @notice To decrease the balance of an Operator's wallet
     * @dev only maintainer can decrease the balance
     * @param _id the id of the Operator
     * @param _value Ether (in Wei) amount to decrease the wallet balance and send back to Maintainer.
     * @return success boolean value which is "sent", should be used by Operator is Maintainer is a contract.
     */
    function _decreaseMaintainerWallet(
        DataStoreUtils.DataStore storage DATASTORE,
        uint256 _id,
        uint256 _value
    ) internal returns (bool success) {
        require(
            DATASTORE.readUintForId(_id, "wallet") >= _value,
            "StakeUtils: NOT enough balance in wallet"
        );

        DATASTORE.subUintForId(_id, "wallet", _value);
        return true;
    }
}
