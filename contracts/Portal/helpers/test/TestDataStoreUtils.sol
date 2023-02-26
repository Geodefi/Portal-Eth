// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "../../utils/DataStoreUtilsLib.sol";

contract TestDataStoreUtils {
  using DataStoreUtils for DataStoreUtils.IsolatedStorage;
  DataStoreUtils.IsolatedStorage private DATASTORE;

  /// @notice helpers

  function generateId(
    bytes calldata NAME,
    uint256 TYPE
  ) external pure returns (uint256) {
    return DataStoreUtils.generateId(NAME, TYPE);
  }

  function getKey(uint256 _id, bytes32 _param) external pure returns (bytes32) {
    return DataStoreUtils.getKey(_id, _param);
  }

  /// @notice READ

  function readUintForId(
    uint256 _id,
    bytes32 _key
  ) external view returns (uint256) {
    return DATASTORE.readUintForId(_id, _key);
  }

  function readBytesForId(
    uint256 _id,
    bytes32 _key
  ) external view returns (bytes memory) {
    return DATASTORE.readBytesForId(_id, _key);
  }

  function readAddressForId(
    uint256 _id,
    bytes32 _key
  ) external view returns (address) {
    return DATASTORE.readAddressForId(_id, _key);
  }

  function readUintArrayForId(
    uint256 _id,
    bytes32 _key,
    uint256 _index
  ) external view returns (uint256) {
    return DATASTORE.readUintArrayForId(_id, _key, _index);
  }

  function readBytesArrayForId(
    uint256 _id,
    bytes32 _key,
    uint256 _index
  ) external view returns (bytes memory) {
    return DATASTORE.readBytesArrayForId(_id, _key, _index);
  }

  function readAddressArrayForId(
    uint256 _id,
    bytes32 _key,
    uint256 _index
  ) external view returns (address) {
    return DATASTORE.readAddressArrayForId(_id, _key, _index);
  }

  /// @notice WRITE

  function writeUintForId(uint256 _id, bytes32 _key, uint256 _data) external {
    DATASTORE.writeUintForId(_id, _key, _data);
  }

  function addUintForId(uint256 _id, bytes32 _key, uint256 addend) external {
    DATASTORE.addUintForId(_id, _key, addend);
  }

  function subUintForId(uint256 _id, bytes32 _key, uint256 minuend) external {
    DATASTORE.subUintForId(_id, _key, minuend);
  }

  function writeBytesForId(
    uint256 _id,
    bytes32 _key,
    bytes memory _data
  ) external {
    DATASTORE.writeBytesForId(_id, _key, _data);
  }

  function writeAddressForId(
    uint256 _id,
    bytes32 _key,
    address _data
  ) external {
    DATASTORE.writeAddressForId(_id, _key, _data);
  }

  function appendUintArrayForId(
    uint256 _id,
    bytes32 _key,
    uint256 _data
  ) external {
    DATASTORE.appendUintArrayForId(_id, _key, _data);
  }

  function appendBytesArrayForId(
    uint256 _id,
    bytes32 _key,
    bytes memory _data
  ) external {
    DATASTORE.appendBytesArrayForId(_id, _key, _data);
  }

  function appendAddressArrayForId(
    uint256 _id,
    bytes32 _key,
    address _data
  ) external {
    DATASTORE.appendAddressArrayForId(_id, _key, _data);
  }

  function appendUintArrayForIdBatch(
    uint256 _id,
    bytes32 _key,
    uint256[] memory _data
  ) external {
    DATASTORE.appendUintArrayForIdBatch(_id, _key, _data);
  }

  function appendBytesArrayForIdBatch(
    uint256 _id,
    bytes32 _key,
    bytes[] memory _data
  ) external {
    DATASTORE.appendBytesArrayForIdBatch(_id, _key, _data);
  }

  function appendAddressArrayForIdBatch(
    uint256 _id,
    bytes32 _key,
    address[] memory _data
  ) external {
    DATASTORE.appendAddressArrayForIdBatch(_id, _key, _data);
  }
}
