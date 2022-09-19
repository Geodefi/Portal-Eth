// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import {DataStoreUtils as DSU} from "../../utils/DataStoreUtilsLib.sol";
import {DepositContractUtils as DCU} from "../../utils/DepositContractUtilsLib.sol";
import {MaintainerUtils as MU} from "../../utils/MaintainerUtilsLib.sol";
import {OracleUtils as OU} from "../../utils/OracleUtilsLib.sol";
import {StakeUtils as SU} from "../../utils/StakeUtilsLib.sol";
import {CometUtils as CU} from "../../utils/CometUtilsLib.sol";
import "../../../interfaces/IgETH.sol";
import "../../../interfaces/IMiniGovernance.sol";

contract TestCometUtils {
    using DSU for DSU.DataStore;
    using MU for DSU.DataStore;
    using OU for OU.Oracle;
    using SU for SU.StakePool;

    DSU.DataStore private DATASTORE;
    SU.StakePool private STAKEPOOL;

    function initiateComet(
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        string[2] calldata _interfaceSpecs
    ) external virtual {
        CU.initiateComet(
            STAKEPOOL,
            DATASTORE,
            _id,
            _fee,
            _maintainer,
            _interfaceSpecs
        );
    }

    function setEarlyExitBoost(
        uint256 _cometId,
        uint256 _operatorId,
        uint256 _newBoost
    ) external virtual {
        CU.setEarlyExitBoost(DATASTORE, _cometId, _operatorId, _newBoost);
    }

    function isPriceValid(uint256 _cometId)
        external
        view
        virtual
        returns (bool validity)
    {
        validity = CU.isPriceValid(STAKEPOOL, _cometId);
    }

    function priceSync(
        uint256 _index,
        uint256 _cometId,
        uint256 _beaconBalance,
        bytes32[] calldata _priceProofs // uint256 prices[]
    ) external virtual returns (bool) {
        return
            CU.priceSync(
                STAKEPOOL,
                DATASTORE,
                _index,
                _cometId,
                _beaconBalance,
                _priceProofs
            );
    }

    function depositComet(
        uint256 _cometId,
        uint256 _mingETH,
        uint256 _deadline
    ) external virtual {
        CU.depositComet(STAKEPOOL, DATASTORE, _cometId, _deadline);
    }

    function enqueueWithdrawal() external virtual {
        CU.enqueueWithdrawal();
    }

    function canDequeue(uint256 cometId, uint256 index)
        internal
        view
        returns (bool)
    {
        return CU.canDequeue(DATASTORE, cometId, index);
    }

    function getEnqueued(uint256 _cometId, uint256 _index)
        external
        virtual
        returns (
            address,
            uint256,
            uint256
        )
    {
        return CU.getEnqueued(DATASTORE, _cometId, _index);
    }

    function dequeueWithdrawal() external virtual {
        CU.dequeueWithdrawal();
    }

    function fetchUnstake() external virtual {
        CU.fetchUnstake();
    }
}
