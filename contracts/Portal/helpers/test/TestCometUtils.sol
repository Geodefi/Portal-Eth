// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import {DataStoreUtils as DSU} from "../../utils/DataStoreUtilsLib.sol";
// import {DepositContractUtils as DCU} from "../../utils/DepositContractUtilsLib.sol";
// import {MaintainerUtils as MU} from "../../utils/MaintainerUtilsLib.sol";
// import {OracleUtils as OU} from "../../utils/OracleUtilsLib.sol";
import {StakeUtils as SU} from "../../utils/StakeUtilsLib.sol";
import {CometUtils as CU} from "../../utils/CometUtilsLib.sol";
import "../../../interfaces/IgETH.sol";
import "../../../interfaces/IMiniGovernance.sol";

contract TestCometUtils {
    using DSU for DSU.DataStore;
    // using MU for DSU.DataStore;
    // using OU for OU.Oracle;
    // using SU for SU.StakePool;
    using CU for SU.StakePool;

    DSU.DataStore private DATASTORE;
    SU.StakePool private STAKEPOOL;

    function initiateComet(
        bytes calldata _NAME,
        uint256 _fee,
        string[2] calldata _interfaceSpecs
    ) external virtual {
        STAKEPOOL.initiateComet(DATASTORE, _NAME, _fee, _interfaceSpecs);
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
        validity = STAKEPOOL.isPriceValid(_cometId);
    }

    function priceSync(
        uint256 _cometId,
        uint256 _beaconBalance,
        bytes32[] calldata _priceProofs // uint256 prices[]
    ) external virtual {
        STAKEPOOL.priceSync(DATASTORE, _cometId, _beaconBalance, _priceProofs);
    }

    function depositComet(uint256 _cometId) external virtual {
        STAKEPOOL.depositComet(DATASTORE, _cometId);
    }

    function enqueueWithdrawal(
        uint256 cometId,
        uint256 gAmount,
        address receiver
    ) external virtual {
        STAKEPOOL.enqueueWithdrawal(DATASTORE, cometId, gAmount, receiver);
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

    // TODO: if self is a parameter dont forget to call from STAKEPOOL not CU
    function dequeueWithdrawal() external virtual {
        CU.dequeueWithdrawal();
    }

    // TODO: if self is a parameter dont forget to call from STAKEPOOL not CU
    function fetchUnstake() external virtual {
        CU.fetchUnstake();
    }
}
