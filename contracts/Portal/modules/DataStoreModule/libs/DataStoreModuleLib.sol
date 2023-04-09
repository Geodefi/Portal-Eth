// SPDX-License-Identifier: MIT

pragma solidity =0.8.7;

/**
 * @title DataStoreModule Library - DSML
 * A Storage Management Library for Dynamic Structs providing an Isolated Storage Layout
 * for the contracts and modules that inherits DataStoreModule (DSM)
 *
 * * DataStoreUtils is a storage management tool designed to create a safe and scalable
 * * storage layout with the help of data types, IDs and keys.
 *
 * * Focusing on upgradable contracts with multiple user types to create a
 * * sustainable development environment.
 * * In summary, extra gas cost that would be saved with Storage packing are
 * * ignored to create upgradable structs.
 *
 * @dev Distinct id and key pairs SHOULD return different storage slots
 * @dev TYPEs are defined in globals.sol
 *
 * @dev IDs are the representation of an entity with any given key as properties.
 * @dev While it is good practice to keep record,
 * * TYPE for ID is NOT mandatory, an ID might not have an explicit type.
 * * Thus there is no checks of types or keys.
 *
 * @author Ice Bear & Crash Bandicoot
 */

library DataStoreModuleLib {
  /**
   * @notice Main Struct for reading and writing operations for given (id, key) pairs
   * @param allIdsByType type => id[], optional categorization for IDs, requires direct access
   * @param uintData keccak(id, key) =>  returns uint256
   * @param bytesData keccak(id, key) => returns bytes
   * @param addressData keccak(id, key) =>  returns address
   * @param __gap keep the struct size at 16
   * @dev any other storage type can be expressed as uint or bytes
   */
  struct IsolatedStorage {
    mapping(uint256 => uint256[]) allIdsByType;
    mapping(bytes32 => uint256) uintData;
    mapping(bytes32 => bytes) bytesData;
    mapping(bytes32 => address) addressData;
    uint256[12] __gap;
  }

  /**
   * @custom:section                           ** HELPERS **
   */
  /**
   * @dev -> pure: all
   */

  /**
   * @notice generaliazed method of generating an ID
   * @dev Some TYPEs may require permissionless creation. Allowing anyone to claim any ID,
   * meaning malicious actors can claim names to mislead people. To prevent this
   * TYPEs will be considered during ID generation.
   */
  function generateId(bytes memory _name, uint256 _type) internal pure returns (uint256 id) {
    id = uint256(keccak256(abi.encodePacked(_name, _type)));
  }

  /**
   * @notice hashes given id and a parameter to be used as key in getters and setters
   * @return key bytes32 hash of id and parameter to be stored
   **/
  function getKey(uint256 id, bytes32 param) internal pure returns (bytes32 key) {
    key = keccak256(abi.encodePacked(id, param));
  }

  /**
   * @custom:section                           ** DATA GETTERS **
   */
  /**
   * @dev -> internal view: all
   */

  function readUint(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key
  ) internal view returns (uint256 data) {
    data = self.uintData[getKey(_id, _key)];
  }

  function readBytes(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key
  ) internal view returns (bytes memory data) {
    data = self.bytesData[getKey(_id, _key)];
  }

  function readAddress(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key
  ) internal view returns (address data) {
    data = self.addressData[getKey(_id, _key)];
  }

  /**
   * @custom:section                           ** ARRAY GETTERS **
   */
  /**
   * @dev -> internal view: all
   */

  function readUintArray(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    uint256 _index
  ) internal view returns (uint256 data) {
    data = self.uintData[getKey(_index, getKey(_id, _key))];
  }

  function readBytesArray(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    uint256 _index
  ) internal view returns (bytes memory data) {
    data = self.bytesData[getKey(_index, getKey(_id, _key))];
  }

  function readAddressArray(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    uint256 _index
  ) internal view returns (address data) {
    data = self.addressData[getKey(_index, getKey(_id, _key))];
  }

  /**
   * @custom:section                           ** STATE MODIFYING FUNCTIONS **
   */
  /**
   * @custom:section                           ** DATA SETTERS **
   */
  /**
   * @dev -> internal: all
   */

  function writeUint(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    uint256 _data
  ) internal {
    self.uintData[getKey(_id, _key)] = _data;
  }

  function addUint(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    uint256 _addend
  ) internal {
    self.uintData[getKey(_id, _key)] += _addend;
  }

  function subUint(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    uint256 _minuend
  ) internal {
    self.uintData[getKey(_id, _key)] -= _minuend;
  }

  function writeBytes(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    bytes memory _data
  ) internal {
    self.bytesData[getKey(_id, _key)] = _data;
  }

  function writeAddress(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    address _data
  ) internal {
    self.addressData[getKey(_id, _key)] = _data;
  }

  /**
   * @custom:section                           ** ARRAY SETTERS **
   */
  /**
   * @dev -> internal: all
   */

  function appendUintArray(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    uint256 _data
  ) internal {
    bytes32 arrayKey = getKey(_id, _key);
    self.uintData[getKey(self.uintData[arrayKey]++, arrayKey)] = _data;
  }

  function appendBytesArray(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    bytes memory _data
  ) internal {
    bytes32 arrayKey = getKey(_id, _key);
    self.bytesData[getKey(self.uintData[arrayKey]++, arrayKey)] = _data;
  }

  function appendAddressArray(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    address _data
  ) internal {
    bytes32 arrayKey = getKey(_id, _key);
    self.addressData[getKey(self.uintData[arrayKey]++, arrayKey)] = _data;
  }

  /**
   * @custom:section                           ** BATCH ARRAY SETTERS **
   */
  /**
   * @dev -> internal: all
   */

  function appendUintArrayBatch(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    uint256[] memory _data
  ) internal {
    bytes32 arrayKey = getKey(_id, _key);
    uint256 arrayLen = self.uintData[arrayKey];

    for (uint256 i = 0; i < _data.length; ) {
      self.uintData[getKey(arrayLen++, arrayKey)] = _data[i];
      unchecked {
        i += 1;
      }
    }

    self.uintData[arrayKey] = arrayLen;
  }

  function appendBytesArrayBatch(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    bytes[] memory _data
  ) internal {
    bytes32 arrayKey = getKey(_id, _key);
    uint256 arrayLen = self.uintData[arrayKey];

    for (uint256 i = 0; i < _data.length; ) {
      self.bytesData[getKey(arrayLen++, arrayKey)] = _data[i];
      unchecked {
        i += 1;
      }
    }

    self.uintData[arrayKey] = arrayLen;
  }

  function appendAddressArrayBatch(
    IsolatedStorage storage self,
    uint256 _id,
    bytes32 _key,
    address[] memory _data
  ) internal {
    bytes32 arrayKey = getKey(_id, _key);
    uint256 arrayLen = self.uintData[arrayKey];

    for (uint256 i = 0; i < _data.length; ) {
      self.addressData[getKey(arrayLen++, arrayKey)] = _data[i];
      unchecked {
        i += 1;
      }
    }

    self.uintData[arrayKey] = arrayLen;
  }
}
