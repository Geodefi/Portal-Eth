// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

/**
 * @notice Main Struct for reading/writing operations for given (id, key) pairs.
 *
 * @param allIdsByType type => id[], optional categorization for IDs, can be directly accessed.
 * @param uintData keccak(id, key) =>  returns uint256
 * @param bytesData keccak(id, key) => returns bytes
 * @param addressData keccak(id, key) =>  returns address
 * @param __gap keep the struct size at 16
 *
 * @dev any other storage type can be expressed as uint or bytes. E.g., bools are 0/1 as uints.
 */
struct IsolatedStorage {
  mapping(uint256 => uint256[]) allIdsByType;
  mapping(bytes32 => uint256) uintData;
  mapping(bytes32 => bytes) bytesData;
  mapping(bytes32 => address) addressData;
  uint256[12] __gap;
}
