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
 * @title CometUtils library, an extension to StakeUtils
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
    uint256 public constant INITIATION_PERIOD = 24 hours;

    /// @notice
    uint256 public constant MAX_EARLY_EXIT_BOOST =
        (40 * PERCENTAGE_DENOMINATOR) / 100;

    function _initiateComet(
        SU.StakePool storage self,
        DSU.DataStore storage DATASTORE,
        uint256 _id,
        uint256 _fee,
        address _maintainer,
        string[2] calldata _interfaceSpecs
    ) internal {
        // require(condition); 32 ether needed put in to surplus?
        require(
            _fee <= self.MAX_MAINTAINER_FEE,
            "CometUtils: MAX_MAINTAINER_FEE ERROR"
        );

        address[3] memory addressSpecs = [
            address(self.gETH),
            _maintainer,
            self.DEFAULT_gETH_INTERFACE
        ];
        uint256[3] memory uintSpecs = [_id, _fee, self.MINI_GOVERNANCE_VERSION];

        (address miniGovernance, address gInterface) = DATASTORE.initiateComet(
            uintSpecs,
            addressSpecs,
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

    function initiateComet(
        SU.StakePool storage self,
        DSU.DataStore storage DATASTORE,
        bytes calldata NAME,
        uint256 fee,
        string[2] calldata _interfaceSpecs
    ) external {
        uint256 value = msg.value;
        require(
            value >= 32 ether,
            "CometUtils: requires at least 32 ether to initiate"
        );

        //GeodeUtils._generateId(_NAME, _TYPE);
        uint256 TYPE = 6;
        uint256 id = uint256(keccak256(abi.encodePacked(NAME, TYPE)));

        require(
            DATASTORE.readAddressForId(id, "CONTROLLER") == address(0),
            "CometUtils: name is already claimed"
        );
        DATASTORE.writeUintForId(id, "TYPE", TYPE);
        DATASTORE.writeBytesForId(id, "NAME", NAME);
        DATASTORE.writeAddressForId(id, "CONTROLLER", msg.sender);

        _initiateComet(self, DATASTORE, id, fee, msg.sender, _interfaceSpecs);
        DATASTORE.addUintForId(id, "surplus", value);
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
        uint256 cometId,
        uint256 beaconBalance,
        bytes32[] calldata priceProofs // uint256 prices[]
    ) external {
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
            cometId,
            beaconBalance,
            periodsSinceUpdate,
            priceProofs
        );
    }

    // it is not possible to put the newly acquired funds to queue, but it can be taken from surplus with enqueueWithdrawal.
    function depositComet(
        SU.StakePool storage self,
        DSU.DataStore storage DATASTORE,
        uint256 cometId
    ) external returns (uint256 mintedgETH) {
        DATASTORE.authenticate(cometId, true, [false, false, true]);

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

    function canDequeue(
        DSU.DataStore storage DATASTORE,
        uint256 cometId,
        uint256 index
    ) internal view returns (bool) {
        return
            DATASTORE.readUintForId(cometId, DSU.getKey(index, "trigger")) <=
            DATASTORE.readUintForId(cometId, "unstaked");
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

    // users should be aware of the surplus (from frontend etc.), if amount is bigger than surplus it will be queued.
    // user can decrease the amount in that case to avoid queue
    function enqueueWithdrawal(
        SU.StakePool storage self,
        DSU.DataStore storage DATASTORE,
        uint256 cometId,
        uint256 gAmount,
        address receiver
    ) external {
        require(gAmount > MIN_QUEUE_SIZE, "CometUtils: at least 0.001 eth");
        require(
            block.timestamp >
                DATASTORE.readUintForId(cometId, "initiated") +
                    INITIATION_PERIOD
        );
        {
            // transfer token first
            uint256 beforeBalance = self.gETH.balanceOf(address(this), cometId);
            self.gETH.safeTransferFrom(
                msg.sender,
                address(this),
                cometId,
                gAmount,
                ""
            );

            // Use the transferred amount
            gAmount =
                beforeBalance -
                self.gETH.balanceOf(address(this), cometId);
        }

        // surplus check => if surplus, burn surplus
        uint256 EthToSend = gAmount * self.gETH.pricePerShare(cometId);
        if (DATASTORE.readUintForId(cometId, "surplus") >= EthToSend) {
            DATASTORE.subUintForId(cometId, "surplus", EthToSend);
            (bool sent, ) = payable(msg.sender).call{value: EthToSend}("");
            require(sent, "CometUtils: Failed to send Ether");
        } else {
            DATASTORE.addUintForId(cometId, "queueSum", gAmount);
            DATASTORE.addUintForId(cometId, "queueSize", 1);

            uint256 index = DATASTORE.readUintForId(cometId, "queueSize");

            DATASTORE.writeUintForId(
                cometId,
                DSU.getKey(index, "amount"),
                gAmount
            );
            DATASTORE.writeUintForId(
                cometId,
                DSU.getKey(index, "trigger"),
                DATASTORE.readUintForId(cometId, "queueSum")
            );
            DATASTORE.writeAddressForId(
                cometId,
                DSU.getKey(index, "receiver"),
                receiver
            );
        }
    }

    function finalizeDequeu(
        DSU.DataStore storage DATASTORE,
        uint256 cometId,
        uint256 index,
        uint256 etherToSend,
        uint256 remgETH
    ) internal {
        address receiver = DATASTORE.readAddressForId(
            cometId,
            DSU.getKey(index, "receiver")
        );
        (bool sent, ) = payable(receiver).call{value: etherToSend}("");
        require(sent, "CometUtils: Failed to send Ether");
        DATASTORE.writeUintForId(cometId, DSU.getKey(index, "amount"), remgETH);
    }

    // it is assumed cpPrice can never be 0
    // bufferGeth meaning amount between 2 cp
    function dequeueWithdrawal(
        DSU.DataStore storage DATASTORE,
        uint256 cometId,
        uint256 index,
        uint256 priceIndex
    ) external {
        uint256 gAmount = DATASTORE.readUintForId(
            cometId,
            DSU.getKey(index, "amount")
        );
        uint256 trigger = DATASTORE.readUintForId(
            cometId,
            DSU.getKey(index, "trigger")
        );

        uint256 bufferGeth;
        uint256 cpUnstaked_0 = DATASTORE.readUintForId(
            cometId,
            DSU.getKey(priceIndex, "cpUnstaked")
        );
        {
            uint256 initAmount = trigger - gAmount;
            require(
                DATASTORE.readUintForId(
                    cometId,
                    DSU.getKey(priceIndex - 1, "cpUnstaked")
                ) <= initAmount
            );

            require(cpUnstaked_0 > initAmount);

            bufferGeth = cpUnstaked_0 - initAmount;
        }

        uint256 price = DATASTORE.readUintForId(
            cometId,
            DSU.getKey(priceIndex, "cpPrice")
        );

        if (gAmount <= bufferGeth) {
            return
                finalizeDequeu(DATASTORE, cometId, index, gAmount * price, 0);
        }

        uint256 etherToSend = bufferGeth * price;
        gAmount -= bufferGeth;

        uint256 cpLength = DATASTORE.readUintForId(
            cometId,
            DSU.getKey(priceIndex, "cpLength")
        );
        for (uint256 i = priceIndex + 1; i < cpLength; i++) {
            price = DATASTORE.readUintForId(
                cometId,
                DSU.getKey(priceIndex, "cpPrice")
            );

            uint256 cpUnstaked_1 = DATASTORE.readUintForId(
                cometId,
                DSU.getKey(i, "cpUnstaked")
            );

            bufferGeth = cpUnstaked_1 - cpUnstaked_0;

            if (gAmount <= bufferGeth) {
                etherToSend += gAmount * price;
                return
                    finalizeDequeu(DATASTORE, cometId, index, etherToSend, 0);
            }

            etherToSend += bufferGeth * price;
            gAmount -= bufferGeth;
            cpUnstaked_0 = cpUnstaked_1;
        }
        return finalizeDequeu(DATASTORE, cometId, index, etherToSend, gAmount);
    }

    // burns the amount of gETH
    // ! isoracleactive
    function fetchUnstake() external {
        // StakePool storage self,
        // DataStoreUtils.DataStore storage DATASTORE,
        // bytes calldata pk,
        // uint256 balance,
        // bool isExit,
        // uint256 GOVERNANCE_TAX
        //
        // if price did not change increase cpUnstaked instead of new cp (?)
        // burn (?)
    }
}
