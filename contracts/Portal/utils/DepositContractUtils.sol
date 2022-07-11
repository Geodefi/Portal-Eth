// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../../interfaces/IDepositContract.sol";
import "../helpers/BytesLib.sol";

library DepositContractUtils {
    struct DepositContract {
        address DEPOSIT_CONTRACT_POSITION;
    }
    uint256 constant SIGNATURE_LENGTH = 96;

    function getDepositContract(DepositContract storage self)
        public
        view
        returns (IDepositContract)
    {
        return IDepositContract(self.DEPOSIT_CONTRACT_POSITION);
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

    function _getDepositDataRoot(
        bytes memory pubkey,
        bytes memory withdrawal_credentials,
        bytes memory signature,
        uint256 stakeAmount
    ) internal pure returns (bytes32) {
        require(stakeAmount >= 1 ether, "StakeUtils: deposit value too low");
        require(
            stakeAmount % 1 gwei == 0,
            "StakeUtils: deposit value not multiple of gwei"
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

    function _addressToWC(address wc_address)
        internal
        pure
        returns (bytes memory)
    {
        uint256 w = 1 << 248;
        return
            abi.encodePacked(
                bytes32(w) | bytes32(uint256(uint160(address(wc_address))))
            );
    }
}
