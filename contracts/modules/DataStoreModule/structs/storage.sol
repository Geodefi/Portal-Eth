// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @notice Storage Struct for reading/writing operations for given (id, key) pairs.
 *
 * @param allIdsByType type => id[], optional categorization for IDs, can be directly accessed.
 * @param uintData keccak(id, key) =>  returns uint256
 * @param bytesData keccak(id, key) => returns bytes
 * @param addressData keccak(id, key) =>  returns address
 *
 * @dev any other storage type can be expressed as uint or bytes. E.g., bools are 0/1 as uints.
 *
 * @dev normally we would put custom:storage-location erc7201:geode.storage.DataStoreModule
 * but compiler throws an error... So np for now, just effects dev ex.
 */
struct DataStoreModuleStorage {
  mapping(uint256 => uint256[]) allIdsByType;
  mapping(bytes32 => uint256) uintData;
  mapping(bytes32 => bytes) bytesData;
  mapping(bytes32 => address) addressData;
}
