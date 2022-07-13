// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../../interfaces/IDepositContract.sol";
import "../helpers/BytesLib.sol";

library DepositContractUtils {
    address constant internal DEPOSIT_CONTRACT_POSITION = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    uint256 constant internal PUBKEY_LENGTH = 48;
    uint256 constant internal SIGNATURE_LENGTH = 96;
    uint256 constant internal WITHDRAWAL_CREDENTIALS_LENGTH = 32;
    uint256 constant internal DEPOSIT_SIZE = 32 ether;
    uint256 constant internal DEPOSIT_SIZE_PRESTAKE = 1 ether;
    
    function getDepositContract()
        internal
        pure
        returns (IDepositContract)
    {
        return IDepositContract(DEPOSIT_CONTRACT_POSITION);
    }

    /**
     * @dev Padding memory array with zeroes up to 64 bytes on the right
     * @param _b Memory array of size 32 .. 64
     */
    function _pad64(bytes memory _b) internal pure returns (bytes memory) {
        assert(_b.length >= 32 && _b.length <= 64);
        if (64 == _b.length) return _b;

        bytes memory zero32 = new bytes(32);
        assembly {
            mstore(add(zero32, 0x20), 0)
        }

        if (32 == _b.length) return BytesLib.concat(_b, zero32);
        else
            return
                BytesLib.concat(
                    _b,
                    BytesLib.slice(zero32, 0, uint256(64 - _b.length))
                );
    }

    /**
     * @dev Converting value to little endian bytes and padding up to 32 bytes on the right
     * @param _value Number less than `2**64` for compatibility reasons
     */
    function _toLittleEndian64(uint256 _value)
        internal
        pure
        returns (uint256 result)
    {
        result = 0;
        uint256 temp_value = _value;
        for (uint256 i = 0; i < 8; ++i) {
            result = (result << 8) | (temp_value & 0xFF);
            temp_value >>= 8;
        }

        assert(0 == temp_value); // fully converted
        result <<= (24 * 8);
    }

    function getDepositDataRoot(
        bytes memory pubkey,
        bytes memory withdrawal_credentials,
        bytes memory signature,
        uint256 stakeAmount
    ) internal pure returns (bytes32) {
        require(stakeAmount >= 1 ether, "DepositContract: deposit value too low");
        require(
            stakeAmount % 1 gwei == 0,
            "DepositContract: deposit value not multiple of gwei"
        );
        uint256 deposit_amount = stakeAmount / 1 gwei;

        bytes32 pubkeyRoot = sha256(_pad64(pubkey));
        bytes32 signatureRoot = sha256(
            abi.encodePacked(
                sha256(BytesLib.slice(signature, 0, 64)),
                sha256(
                    _pad64(BytesLib.slice(signature, 64, SIGNATURE_LENGTH - 64))
                )
            )
        );

        bytes32 depositDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, withdrawal_credentials)),
                sha256(
                    abi.encodePacked(
                        _toLittleEndian64(deposit_amount),
                        signatureRoot
                    )
                )
            )
        );
        return depositDataRoot;
    }

    function addressToWC(address wcAddress)
        internal
        pure
        returns (bytes memory)
    {
        uint256 w = 1 << 248;
        return
            abi.encodePacked(
                bytes32(w) | bytes32(uint256(uint160(address(wcAddress))))
            );
    }
}
