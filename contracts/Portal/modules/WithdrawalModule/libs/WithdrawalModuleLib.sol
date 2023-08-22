// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {PERCENTAGE_DENOMINATOR} from "../../../globals/macros.sol";
import {VALIDATOR_STATE} from "../../../globals/validator_state.sol";
// libraries
import {DataStoreModuleLib as DSML} from "../../DataStoreModule/libs/DataStoreModuleLib.sol";
import {StakeModuleLib as SML} from "../../StakeModule/libs/StakeModuleLib.sol";
import {DepositContractLib as DCL} from "../../StakeModule/libs/DepositContractLib.sol";
// interfaces
import {IgETH} from "../../../interfaces/IgETH.sol";
import {IPortal} from "../../../interfaces/IPortal.sol";
// external
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

library WithdrawalModuleLib {
  using DSML for DSML.IsolatedStorage;

  struct Validator {
    uint256 beaconBalance;
    uint256 withdrawnBalance;
    uint256[14] __gap;
  }

  struct PooledWithdrawal {
    uint256 pooledTokenId;
    IgETH gETH;
    IPortal PORTAL;
    address GOVERNANCE;
    uint256 EXCESS_BALANCE;
    mapping(bytes => Validator) validators;
    uint256[11] __gap;
  }

  function _finalizeExit(
    PooledWithdrawal storage self,
    SML.Validator memory v,
    bytes memory pk,
    uint256 amount
  ) internal returns (uint256 remBalance) {
    require(v.state != VALIDATOR_STATE.EXITED);

    if (amount > DCL.DEPOSIT_AMOUNT) {
      remBalance = DCL.DEPOSIT_AMOUNT;
      remBalance += _distributeFees(self, v, amount - DCL.DEPOSIT_AMOUNT);
    } else {
      remBalance = amount;
    }
  }

  function _distributeFees(
    PooledWithdrawal storage self,
    SML.Validator memory v,
    uint256 profit
  ) internal returns (uint256 remBalance) {
    uint256 poolFee = v.poolFee;
    uint256 operatorFee = v.operatorFee;
    uint256 governanceFee = v.governanceFee;

    uint256 poolProfit = (profit * poolFee) / PERCENTAGE_DENOMINATOR;
    uint256 operatorProfit = (profit * operatorFee) / PERCENTAGE_DENOMINATOR;
    uint256 governanceProfit = (profit * governanceFee) / PERCENTAGE_DENOMINATOR;

    remBalance = (((profit - poolProfit) - operatorProfit) - governanceProfit);

    self.PORTAL.increaseWalletBalance{value: poolProfit}(v.poolId);
    self.PORTAL.increaseWalletBalance{value: operatorProfit}(v.operatorId);
    (bool success, ) = payable(self.GOVERNANCE).call{value: governanceProfit}("");
    require(success, "WML:Failed to send ETH");
  }

  function processValidators(
    PooledWithdrawal storage self,
    bytes[] calldata pks,
    uint256[] calldata beaconBalances,
    uint256[] calldata withdrawnBalances,
    bytes32[][] calldata balanceProofs
  ) external {
    uint256 pkLen = pks.length;
    require(
      pkLen == beaconBalances.length &&
        pkLen == withdrawnBalances.length &&
        pkLen == balanceProofs.length,
      "WML:invalid lengths"
    );

    bytes32 balanceMerkleRoot = self.PORTAL.getBalancesMerkleRoot();

    for (uint256 j = 0; j < pks.length; j++) {
      // verify balances
      bytes32 leaf = keccak256(
        bytes.concat(keccak256(abi.encode(pks[j], beaconBalances[j], withdrawnBalances[j])))
      );
      require(
        MerkleProof.verify(balanceProofs[j], balanceMerkleRoot, leaf),
        "WML:NOT all proofs are valid"
      );
    }

    bytes[] memory tempFinalizedPks = new bytes[](pks.length);
    uint256 finalizedPkLen;
    uint256 totalExcess;
    for (uint256 i = 0; i < pks.length; i++) {
      bytes memory pk = pks[i];
      // calculate the increase that will be considered since the last process
      uint256 balanceIncrease = withdrawnBalances[i] - self.validators[pk].withdrawnBalance;

      // 1. increase processed balances
      self.validators[pk].beaconBalance = beaconBalances[i];
      self.validators[pk].withdrawnBalance = withdrawnBalances[i];

      // get validator
      SML.Validator memory v = self.PORTAL.getValidator(pk);

      // means exited
      if (beaconBalances[i] == 0) {
        // if there is a normal fee to distribute, first distribute it then finalize the exit
        // if (balanceIncrease > DCL.DEPOSIT_AMOUNT) {
        // totalExcess += _distributeFees(self, v, balanceIncrease - DCL.DEPOSIT_AMOUNT);
        // totalExcess += _finalizeExit(self, v, DCL.DEPOSIT_AMOUNT);
        // } else {
        totalExcess += _finalizeExit(self, v, pk, balanceIncrease);
        tempFinalizedPks[finalizedPkLen] = pk;
        finalizedPkLen += 1;
        // }
      } else {
        totalExcess += _distributeFees(self, v, balanceIncrease);
      }
    }

    bytes[] memory finalizedPks = new bytes[](finalizedPkLen);
    for (uint256 i = 0; i < finalizedPkLen; i++) {
      finalizedPks[i] = tempFinalizedPks[i];
    }

    self.PORTAL.setValidatorStateBatch(self.pooledTokenId, finalizedPks, VALIDATOR_STATE.EXITED);

    self.EXCESS_BALANCE += totalExcess;
  }
}
