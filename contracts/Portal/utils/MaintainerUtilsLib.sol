// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./DataStoreLib.sol";
import "../../interfaces/IgETH.sol";
import "../../interfaces/IMiniGovernance.sol";
import {IERC20InterfacePermitUpgradable as IgETHInterface} from "../../interfaces/IERC20InterfacePermitUpgradable.sol";
import "../../interfaces/ISwap.sol";
import "../../interfaces/ILPToken.sol";

library MaintainerUtils {
    event IdInitiated(uint256 id, uint256 _type);
    event MaintainerFeeUpdated(uint256 id, uint256 fee);
    using DataStoreUtils for DataStoreUtils.DataStore;

    /// @notice PERCENTAGE_DENOMINATOR represents 100%
    uint256 public constant PERCENTAGE_DENOMINATOR = 10**10;

    /// @notice comments here
    uint256 public constant FEE_SWITCH_LATENCY = 7 days;

    /// @notice default DWP parameters
    uint256 public constant DEFAULT_A = 60;
    uint256 public constant DEFAULT_FEE = (4 * PERCENTAGE_DENOMINATOR) / 10000;
    uint256 public constant DEFAULT_ADMIN_FEE =
        (5 * PERCENTAGE_DENOMINATOR) / 10;

    modifier initiator(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _type,
        uint256 _id,
        address _maintainer
    ) {
        require(
            msg.sender == _DATASTORE.readAddressForId(_id, "CONTROLLER"),
            "StakeUtils: sender NOT CONTROLLER"
        );

        require(
            _DATASTORE.readUintForId(_id, "TYPE") == _type,
            "StakeUtils: id NOT correct TYPE"
        );
        require(
            _DATASTORE.readUintForId(_id, "initiated") == 0,
            "StakeUtils: already initiated"
        );

        _DATASTORE.writeAddressForId(_id, "maintainer", _maintainer);
        _;

        _DATASTORE.writeUintForId(_id, "initiated", block.timestamp);
        emit IdInitiated(_id, _type);
    }

    function _authenticate(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        bool expectMaintainer,
        bool[3] memory restrictionMap
    ) internal view {
        if (expectMaintainer) {
            require(
                msg.sender == _DATASTORE.readAddressForId(_id, "maintainer"),
                "StakeUtils: sender NOT maintainer"
            );
        }
        uint256 typeOfId = _DATASTORE.readUintForId(_id, "TYPE");
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
     * @notice initiates ID as an node operator
     * @dev requires ID to be approved as a node operator with a specific CONTROLLER
     * @param _id --
     * @param _validatorPeriod --
     */
    function initiateOperator(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        uint256 _validatorPeriod
    ) external initiator(_DATASTORE, 4, _id, _maintainer) {
        _DATASTORE.writeUintForId(_id, "fee", _fee);
        _DATASTORE.writeUintForId(_id, "validatorPeriod", _validatorPeriod);
    }

    /**
     * @notice initiates ID as a planet (public pool)
     * @dev requires ID to be approved as a planet with a specific CONTROLLER
     */
    // uintSpecs: 0:_id, 1:_fee, 2:_withdrawalBoost, 3:_MINI_GOVERNANCE_VERSION
    // addressSpecs: 0:gETH, 1:_maintainer, 2:DEFAULT_gETH_INTERFACE_, 3:DEFAULT_DWP, 4:DEFAULT_LP_TOKEN
    function initiatePlanet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256[4] memory uintSpecs,
        address[5] memory addressSpecs,
        string[2] calldata _interfaceSpecs
    )
        external
        initiator(_DATASTORE, 5, uintSpecs[0], addressSpecs[1])
        returns (
            address miniGovernance,
            address gInterface,
            address WithdrawalPool
        )
    {
        require(
            uintSpecs[2] <= PERCENTAGE_DENOMINATOR,
            "StakeUtils: withdrawalBoost > 100%"
        );

        _DATASTORE.writeUintForId(uintSpecs[0], "fee", uintSpecs[1]);
        _DATASTORE.writeUintForId(
            uintSpecs[0],
            "withdrawalBoost",
            uintSpecs[2]
        );

        {
            miniGovernance = _deployMiniGovernance(
                _DATASTORE,
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
                _interfaceSpecs[0],
                _interfaceSpecs[1],
                addressSpecs[0]
            );
        }
        {
            WithdrawalPool = _deployWithdrawalPool(
                _DATASTORE,
                addressSpecs[0],
                uintSpecs[0],
                addressSpecs[3],
                addressSpecs[4]
            );
        }
        // return (miniGovernance, address(newInterface), WithdrawalPool);
    }

    /**
     * @notice initiates ID as a comet (private pool)
     * @dev requires ID to be approved as comet with a specific CONTROLLER
     * @param _id --
     */
    function initiateComet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer
    ) external initiator(_DATASTORE, 6, _id, _maintainer) {
        _DATASTORE.writeUintForId(_id, "fee", _fee);
    }

    function _deployMiniGovernance(
        DataStoreUtils.DataStore storage _DATASTORE,
        address gETH,
        uint256 _id,
        uint256 _versionId,
        address _maintainer
    ) internal returns (address miniGovernance) {
        ERC1967Proxy newGovernance = new ERC1967Proxy(
            _DATASTORE.readAddressForId(_versionId, "CONTROLLER"),
            abi.encodeWithSelector(
                IMiniGovernance(address(0)).initialize.selector,
                gETH,
                _id,
                address(this),
                _maintainer,
                _versionId
            )
        );
        _DATASTORE.writeAddressForId(
            _id,
            "miniGovernance",
            address(newGovernance)
        );
        miniGovernance = address(newGovernance);
    }

    /**
     * @notice deploys a new withdrawal pool using DEFAULT_DWP
     * @dev sets the withdrawal pool and LP token for id
     */
    function _deployWithdrawalPool(
        DataStoreUtils.DataStore storage _DATASTORE,
        address gETH,
        uint256 _id,
        address DEFAULT_DWP,
        address DEFAULT_LP_TOKEN
    ) internal returns (address WithdrawalPool) {
        WithdrawalPool = Clones.clone(DEFAULT_DWP);

        address WPToken = ISwap(WithdrawalPool).initialize(
            IgETH(gETH),
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
            DEFAULT_A,
            DEFAULT_FEE,
            DEFAULT_ADMIN_FEE,
            DEFAULT_LP_TOKEN
        );
        _DATASTORE.writeAddressForId(_id, "withdrawalPool", WithdrawalPool);
        _DATASTORE.writeAddressForId(_id, "LPToken", WPToken);
    }

    /**
     * @notice CONTROLLER of the ID can change the maintainer to any address other than ZERO_ADDRESS
     * @dev it is wise to change the CONTROLLER before the maintainer, in case of any migration
     * @dev handle with care
     * note, intended (suggested) usage is to set a contract address that will govern the id for maintainer,
     * while keeping the controller as a multisig or provide smt like 0x000000000000000000000000000000000000dEaD
     */
    function _changeMaintainer(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        address _newMaintainer
    ) internal {
        require(
            msg.sender == _DATASTORE.readAddressForId(_id, "CONTROLLER"),
            "StakeUtils: sender NOT CONTROLLER"
        );
        require(
            _newMaintainer != address(0),
            "StakeUtils: maintainer can NOT be zero"
        );
        _DATASTORE.writeAddressForId(_id, "maintainer", _newMaintainer);
    }

    /**
     * @notice Gets fee percentage in terms of PERCENTAGE_DENOMINATOR.
     * @dev even if MAX_MAINTAINER_FEE is decreased later, it returns limited maximum.
     * @param _id planet, comet or operator ID
     * @return fee = percentage * PERCENTAGE_DENOMINATOR / 100
     */
    function getMaintainerFee(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id
    ) public view returns (uint256 fee) {
        fee = _DATASTORE.readUintForId(_id, "fee");
        if (_DATASTORE.readUintForId(_id, "feeSwitch") >= block.timestamp) {
            fee = _DATASTORE.readUintForId(_id, "priorFee");
        }
    }

    /**
     * @notice Changes the fee that is applied by distributeFee on Oracle Updates.
     * @dev to achieve 100% fee send PERCENTAGE_DENOMINATOR
     * @param _id planet, comet or operator ID
     * @param _newFee new fee percentage in terms of PERCENTAGE_DENOMINATOR,reverts if given more than MAX_MAINTAINER_FEE
     */
    function _switchMaintainerFee(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _id,
        uint256 _newFee
    ) internal {
        _DATASTORE.writeUintForId(
            _id,
            "priorFee",
            _DATASTORE.readUintForId(_id, "fee")
        );
        _DATASTORE.writeUintForId(
            _id,
            "feeSwitch",
            block.timestamp + FEE_SWITCH_LATENCY
        );
        _DATASTORE.writeUintForId(_id, "fee", _newFee);
        emit MaintainerFeeUpdated(_id, _newFee);
    }

    /**
     * @notice To increase the balance of an Operator's wallet
     * @dev only maintainer can increase the balance
     * @param _operatorId the id of the Operator
     * @param value Ether (in Wei) amount to increase the wallet balance.
     * @return success boolean value which is true if successful, should be used by Operator is Maintainer is a contract.
     */
    function _increaseMaintainerWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) internal returns (bool success) {
        _DATASTORE.addUintForId(_operatorId, "wallet", value);
        return true;
    }

    /**
     * @notice To decrease the balance of an Operator's wallet
     * @dev only maintainer can decrease the balance
     * @param _operatorId the id of the Operator
     * @param value Ether (in Wei) amount to decrease the wallet balance and send back to Maintainer.
     * @return success boolean value which is "sent", should be used by Operator is Maintainer is a contract.
     */
    function _decreaseMaintainerWallet(
        DataStoreUtils.DataStore storage _DATASTORE,
        uint256 _operatorId,
        uint256 value
    ) internal returns (bool success) {
        require(
            _DATASTORE.readUintForId(_operatorId, "wallet") >= value,
            "StakeUtils: NOT enough balance in wallet"
        );
        _DATASTORE.subUintForId(_operatorId, "wallet", value);
        return true;
    }
}
