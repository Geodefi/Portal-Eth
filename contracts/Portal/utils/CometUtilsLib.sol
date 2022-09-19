// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import {DataStoreUtils as DSU} from "./DataStoreUtilsLib.sol";
import {DepositContractUtils as DCU} from "./DepositContractUtilsLib.sol";
import {MaintainerUtils as MU} from "./MaintainerUtilsLib.sol";
import {OracleUtils as OU} from "./OracleUtilsLib.sol";
import {StakeUtils as SU} from "./StakeUtilsLib.sol";
import "../../interfaces/IgETH.sol";
import "../../interfaces/IMiniGovernance.sol";

/**
 * @author Icebear & Crash Bandicoot
 * @title StakeUtils library
 * @notice Exclusively contains functions related to ETH Liquid Staking design
 */

library CometUtils {
    event CometBoostUpdated(uint256 cometId, uint256 newBoost);
    event UnstakeSignal(bytes pubkey);

    using DSU for DSU.DataStore;
    using MU for DSU.DataStore;
    using OU for OU.Oracle;
    using SU for SU.StakePool;

    uint256 public constant PERCENTAGE_DENOMINATOR = 10**10;

    /// @notice min queue amount is 0.001 ether
    uint256 public constant MIN_QUEUE_SIZE = 1 ether / 1000;

    /// @notice
    uint256 public constant MAX_EARLY_EXIT_BOOST =
        (40 * PERCENTAGE_DENOMINATOR) / 100;

    function initiateComet(
        SU.StakePool storage self,
        DSU.DataStore storage DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        string[2] calldata _interfaceSpecs
    ) external {
        // require(condition); 32 ether needed put in to surplus?
        require(
            _fee <= self.MAX_MAINTAINER_FEE,
            "CometUtils: MAX_MAINTAINER_FEE ERROR"
        );

        (address miniGovernance, address gInterface) = DATASTORE.initiateComet(
            _id,
            _fee,
            _maintainer,
            address(self.gETH),
            self.DEFAULT_gETH_INTERFACE,
            self.MINI_GOVERNANCE_VERSION,
            _interfaceSpecs
        );

        SU.setInterface(self, DATASTORE, _id, gInterface);

        // initially 1 ETHER = 1 ETHER
        self.gETH.setPricePerShare(1 ether, _id);

        DATASTORE.writeBytesForId(
            _id,
            "withdrawalCredential",
            DCU.addressToWC(miniGovernance)
        );
    }

    /**
     * @notice                ** Comet (TYPE 6) specific functions **
     */

    /**
     * @notice sets ...
     */
    function setEarlyExitBoost(
        DSU.DataStore storage DATASTORE,
        uint256 cometId,
        uint256 operatorId,
        uint256 newBoost
    ) public {
        DATASTORE.authenticate(cometId, true, [false, false, true]);
        require(
            newBoost <= MAX_EARLY_EXIT_BOOST,
            "CometUtils: should be less than MAX_VALIDATOR_PERIOD"
        );
        DATASTORE.writeUintForId(
            cometId,
            DSU.getKey(operatorId, "earlyExitBoost"),
            newBoost
        );
        emit CometBoostUpdated(cometId, newBoost);
    }

    function isPriceValid(SU.StakePool storage self, uint256 cometId)
        internal
        view
        returns (bool validity)
    {
        validity =
            self.TELESCOPE.ORACLE_UPDATE_TIMESTAMP <
            self.gETH.priceUpdateTimestamp(cometId);
    }

    function priceSync(
        SU.StakePool storage self,
        DSU.DataStore storage DATASTORE,
        uint256 index,
        uint256 cometId,
        uint256 beaconBalance,
        bytes32[] calldata priceProofs // uint256 prices[]
    ) external returns (bool) {
        require(
            !isPriceValid(self, cometId),
            "CometUtils: Price is already valid"
        );
        uint256 periodsSinceUpdate = (block.timestamp +
            OU.ORACLE_ACTIVE_PERIOD -
            self.gETH.priceUpdateTimestamp(cometId)) / OU.ORACLE_PERIOD;

        bytes32[2] memory dailyBufferKeys = [
            DSU.getKey(
                block.timestamp - (block.timestamp % OU.ORACLE_PERIOD),
                "mintBuffer"
            ),
            DSU.getKey(
                block.timestamp - (block.timestamp % OU.ORACLE_PERIOD),
                "burnBuffer"
            )
        ];

        self.TELESCOPE._priceSync(
            DATASTORE,
            dailyBufferKeys,
            index,
            cometId,
            beaconBalance,
            periodsSinceUpdate,
            priceProofs
        );

        return true;
    }

    function depositComet(
        SU.StakePool storage self,
        DSU.DataStore storage DATASTORE,
        uint256 cometId,
        uint256 deadline
    ) external returns (uint256 mintedgETH) {
        DATASTORE.authenticate(cometId, true, [false, false, true]);

        require(deadline > block.timestamp, "CometUtils: Deadline not met");
        require(isPriceValid(self, cometId), "CometUtils: Price is invalid");

        uint256 value = msg.value;
        require(value > 1e15, "CometUtils: at least 0.001 eth ");

        mintedgETH = (
            ((value * self.gETH.denominator()) /
                self.gETH.pricePerShare(cometId))
        );

        self.gETH.mint(msg.sender, cometId, mintedgETH, "");
        DATASTORE.addUintForId(cometId, "surplus", value);

        if (self.TELESCOPE._isOracleActive()) {
            bytes32 dailyBufferKey = DSU.getKey(
                block.timestamp - (block.timestamp % OU.ORACLE_PERIOD),
                "mintBuffer"
            );
            DATASTORE.addUintForId(cometId, dailyBufferKey, mintedgETH);
        }
    }

    function enqueueWithdrawal() external {}

    function canDequeue(
        DSU.DataStore storage DATASTORE,
        uint256 cometId,
        uint256 index
    ) internal view returns (bool) {
        return
            DATASTORE.readUintForId(cometId, DSU.getKey(index, "trigger")) <
            DATASTORE.readUintForId(cometId, "withdrawn");
    }

    function getEnqueued(
        DSU.DataStore storage DATASTORE,
        uint256 cometId,
        uint256 index
    )
        internal
        view
        returns (
            address receiver,
            uint256 gAmount,
            uint256 trigger
        )
    {
        receiver = DATASTORE.readAddressForId(
            cometId,
            DSU.getKey(index, "receiver")
        );
        gAmount = DATASTORE.readUintForId(cometId, DSU.getKey(index, "amount"));
        trigger = DATASTORE.readUintForId(
            cometId,
            DSU.getKey(index, "trigger")
        );
    }

    function dequeueWithdrawal() external {}

    function fetchUnstake() external {}
}
