// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../../../interfaces/IDepositContract.sol";
import "../../utils/DepositContractUtilsLib.sol";

contract TestDepositContractUtils {
  function getDepositContract()
    external
    view
    virtual
    returns (IDepositContract)
  {
    return DepositContractUtils.DEPOSIT_CONTRACT;
  }

  function getDepositDataRoot(
    bytes memory _pubkey,
    bytes memory _withdrawal_credentials,
    bytes memory _signature,
    uint256 _stakeAmount
  ) external view virtual returns (bytes32) {
    return
      DepositContractUtils._getDepositDataRoot(
        _pubkey,
        _withdrawal_credentials,
        _signature,
        _stakeAmount
      );
  }

  function addressToWC(
    address _wc_address
  ) external view virtual returns (bytes memory) {
    return DepositContractUtils.addressToWC(_wc_address);
  }

  function getPubkeyLength() external view virtual returns (uint256) {
    return DepositContractUtils.PUBKEY_LENGTH;
  }
}
