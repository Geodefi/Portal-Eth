// SPDX-License-Identifier: MIT

pragma solidity =0.8.7;

/**
 * @author Icebear & Crash Bandicoot
 * @title Storage Management Library for dynamic structs, based on data types and ids
 *
 * DataStoreUtils is a storage management tool designed to create a safe and scalable
 * storage layout with the help of ids and keys.
 * Mainly focusing on upgradable contracts with multiple user types to create a
 * sustainable development environment.
 *
 * In summary, extra gas cost that would be saved with Storage packing are
 * ignored to create upgradable structs*.
 *
 * IDs are the representation of a user with any given key as properties.
 * Type for ID is not mandatory, not all IDs should have an explicit type.
 * Thus there is no checks of types or keys.
 *
 * @notice distinct id and key pairs return different storage slots
 *
 */
library DataStoreUtils {
    /**
     * @notice Main Struct for reading and writing data to storage for given (id, key) pairs
     * @param allIdsByType optional categorization for given ID, requires direct access, type => id[]
     * @param uintData keccak(id, key) =>  returns uint256
     * @param bytesData keccak(id, key) => returns bytes
     * @param addressData keccak(id, key) =>  returns address
     * @dev any other storage type can be expressed as bytes
     * @param __gap keep the struct size at 16
     */
    struct DataStore {
        mapping(uint256 => uint256[]) allIdsByType;
        mapping(bytes32 => uint256) uintData;
        mapping(bytes32 => bytes) bytesData;
        mapping(bytes32 => address) addressData;
    }

    /**
     *                              ** HELPER **
     **/

    /**
     * @notice hashes given id with parameter to be used as key in getters and setters
     * @return key bytes32 hash of id and parameter to be stored
     **/
    function getKey(uint256 _id, bytes32 _param)
        internal
        pure
        returns (bytes32 key)
    {
        key = keccak256(abi.encodePacked(_id, _param));
    }

    /**
     *                              **DATA GETTERS **
     **/

    function readUintForId(
        DataStore storage self,
        uint256 _id,
        bytes32 _key
    ) internal view returns (uint256 data) {
        data = self.uintData[getKey(_id, _key)];
    }

    function readBytesForId(
        DataStore storage self,
        uint256 _id,
        bytes32 _key
    ) internal view returns (bytes memory data) {
        data = self.bytesData[getKey(_id, _key)];
    }

    function readAddressForId(
        DataStore storage self,
        uint256 _id,
        bytes32 _key
    ) internal view returns (address data) {
        data = self.addressData[getKey(_id, _key)];
    }

    /**
     *                              **DATA SETTERS **
     **/
    function writeUintForId(
        DataStore storage self,
        uint256 _id,
        bytes32 _key,
        uint256 _data
    ) internal {
        self.uintData[getKey(_id, _key)] = _data;
    }

    function addUintForId(
        DataStore storage self,
        uint256 _id,
        bytes32 _key,
        uint256 _addend
    ) internal {
        self.uintData[getKey(_id, _key)] += _addend;
    }

    function subUintForId(
        DataStore storage self,
        uint256 _id,
        bytes32 _key,
        uint256 _minuend
    ) internal {
        self.uintData[getKey(_id, _key)] -= _minuend;
    }

    function writeBytesForId(
        DataStore storage self,
        uint256 _id,
        bytes32 _key,
        bytes memory _data
    ) internal {
        self.bytesData[getKey(_id, _key)] = _data;
    }

    function writeAddressForId(
        DataStore storage self,
        uint256 _id,
        bytes32 _key,
        address _data
    ) internal {
        self.addressData[getKey(_id, _key)] = _data;
    }
}
