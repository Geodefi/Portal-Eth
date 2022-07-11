// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../../../interfaces/IDepositContract.sol";
import "../../utils/DepositContractUtilsLib.sol";

contract DepositContractUtilsTest {
    using DepositContractUtils for DepositContractUtils.DepositContractData;
    DepositContractUtils.DepositContractData private DEPOSIT_CONTRACT_UTILS;

    constructor(address _DEPOSIT_CONTRACT_POSITION) {
        DEPOSIT_CONTRACT_UTILS
            .DEPOSIT_CONTRACT_POSITION = _DEPOSIT_CONTRACT_POSITION;
    }

     function getDepositContract()
        external
        view
        virtual
        returns (IDepositContract)
    {
        return DEPOSIT_CONTRACT_UTILS.getDepositContract();
    }

    function getDepositDataRoot(
        bytes memory _pubkey,
        bytes memory _withdrawal_credentials,
        bytes memory _signature,
        uint256 _stakeAmount
    ) external view virtual returns (bytes32) {
        return DEPOSIT_CONTRACT_UTILS.getDepositDataRoot(_pubkey, _withdrawal_credentials, _signature, _stakeAmount);
    }

    function addressToWC(address _wc_address)
        external
        view
        virtual
        returns (bytes memory)
    {
        return DEPOSIT_CONTRACT_UTILS.addressToWC(_wc_address);
    }


}
