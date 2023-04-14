// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
// import "../../utils/DataStoreUtilsLib.sol";

// contract TestDataStoreUtils {
//   using DataStoreUtils for DataStoreUtils.IsolatedStorage;
//   DataStoreUtils.IsolatedStorage private DATASTORE;

//   /// @notice helpers

//   function generateId(bytes calldata NAME, uint256 TYPE) external pure returns (uint256) {
//     return DataStoreUtils.generateId(NAME, TYPE);
//   }

//   function getKey(uint256 _id, bytes32 _param) external pure returns (bytes32) {
//     return DataStoreUtils.getKey(_id, _param);
//   }

//   /// @notice READ

//   function readUint(uint256 _id, bytes32 _key) external view returns (uint256) {
//     return DATASTORE.readUint(_id, _key);
//   }

//   function readBytes(uint256 _id, bytes32 _key) external view returns (bytes memory) {
//     return DATASTORE.readBytes(_id, _key);
//   }

//   function readAddress(uint256 _id, bytes32 _key) external view returns (address) {
//     return DATASTORE.readAddress(_id, _key);
//   }

//   function readUintArray(
//     uint256 _id,
//     bytes32 _key,
//     uint256 _index
//   ) external view returns (uint256) {
//     return DATASTORE.readUintArray(_id, _key, _index);
//   }

//   function readBytesArray(
//     uint256 _id,
//     bytes32 _key,
//     uint256 _index
//   ) external view returns (bytes memory) {
//     return DATASTORE.readBytesArray(_id, _key, _index);
//   }

//   function readAddressArray(
//     uint256 _id,
//     bytes32 _key,
//     uint256 _index
//   ) external view returns (address) {
//     return DATASTORE.readAddressArray(_id, _key, _index);
//   }

//   /// @notice WRITE

//   function writeUint(uint256 _id, bytes32 _key, uint256 _data) external {
//     DATASTORE.writeUint(_id, _key, _data);
//   }

//   function addUint(uint256 _id, bytes32 _key, uint256 addend) external {
//     DATASTORE.addUint(_id, _key, addend);
//   }

//   function subUint(uint256 _id, bytes32 _key, uint256 minuend) external {
//     DATASTORE.subUint(_id, _key, minuend);
//   }

//   function writeBytes(uint256 _id, bytes32 _key, bytes memory _data) external {
//     DATASTORE.writeBytes(_id, _key, _data);
//   }

//   function writeAddress(uint256 _id, bytes32 _key, address _data) external {
//     DATASTORE.writeAddress(_id, _key, _data);
//   }

//   function appendUintArray(uint256 _id, bytes32 _key, uint256 _data) external {
//     DATASTORE.appendUintArray(_id, _key, _data);
//   }

//   function appendBytesArray(uint256 _id, bytes32 _key, bytes memory _data) external {
//     DATASTORE.appendBytesArray(_id, _key, _data);
//   }

//   function appendAddressArray(uint256 _id, bytes32 _key, address _data) external {
//     DATASTORE.appendAddressArray(_id, _key, _data);
//   }

//   function appendUintArrayBatch(uint256 _id, bytes32 _key, uint256[] memory _data) external {
//     DATASTORE.appendUintArrayBatch(_id, _key, _data);
//   }

//   function appendBytesArrayBatch(uint256 _id, bytes32 _key, bytes[] memory _data) external {
//     DATASTORE.appendBytesArrayBatch(_id, _key, _data);
//   }

//   function appendAddressArrayBatch(uint256 _id, bytes32 _key, address[] memory _data) external {
//     DATASTORE.appendAddressArrayBatch(_id, _key, _data);
//   }
// }
