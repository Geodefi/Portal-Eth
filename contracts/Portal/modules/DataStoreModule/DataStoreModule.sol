// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// libraries
import {DataStoreModuleLib as DSML} from "./libs/DataStoreModuleLib.sol";
// interfaces
import {IDataStoreModule} from "./interfaces/IDataStoreModule.sol";

/**
 * @title DataStore Module - DSM
 *
 * @author Icebear & Crash Bandicoot
 *
 */
contract DataStoreModule is IDataStoreModule {
  using DSML for DSML.IsolatedStorage;
  /**
   * @dev                                     ** VARIABLES **
   */
  DSML.IsolatedStorage internal DATASTORE;

  /**
   * @dev                                     ** HELPER FUNCTIONS **
   */
  /**
   * @dev -> external pure: all
   */

  /**
   * @notice useful view function for string inputs - returns same with the DSML.generateId
   * @dev id is keccak(name, type)
   */
  function generateId(
    string calldata _name,
    uint256 _type
  ) external pure virtual override returns (uint256 id) {
    id = uint256(keccak256(abi.encodePacked(_name, _type)));
  }

  /**
   * @notice useful view function for string inputs - returns same with the DSML.generateId
   */
  function getKey(
    uint256 _id,
    bytes32 _param
  ) external pure virtual override returns (bytes32 key) {
    return DSML.getKey(_id, _param);
  }

  /**
   * @dev                                     ** DATA GETTER FUNCTIONS **
   */
  /**
   * @dev -> external view: all
   */

  /**
   * @dev useful for outside reach, shouldn't be used within contracts as a referance
   * @return allIdsByType is an array of IDs of the given TYPE from Datastore,
   * returns a specific index
   */
  function allIdsByType(
    uint256 _type,
    uint256 _index
  ) external view virtual override returns (uint256) {
    return DATASTORE.allIdsByType[_type][_index];
  }

  function allIdsByTypeLength(uint256 _type) external view virtual override returns (uint256) {
    return DATASTORE.allIdsByType[_type].length;
  }

  function readUint(uint256 id, bytes32 key) external view virtual override returns (uint256 data) {
    data = DATASTORE.readUint(id, key);
  }

  function readAddress(
    uint256 id,
    bytes32 key
  ) external view virtual override returns (address data) {
    data = DATASTORE.readAddress(id, key);
  }

  function readBytes(
    uint256 id,
    bytes32 key
  ) external view virtual override returns (bytes memory data) {
    data = DATASTORE.readBytes(id, key);
  }

  /**
   * @dev                                     ** ARRAY GETTER FUNCTIONS **
   */
  /**
   * @dev -> external view: all
   */

  function readUintArray(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view virtual override returns (uint256 data) {
    data = DATASTORE.readUintArray(id, key, index);
  }

  function readBytesArray(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view virtual override returns (bytes memory data) {
    data = DATASTORE.readBytesArray(id, key, index);
  }

  function readAddressArray(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view virtual override returns (address data) {
    data = DATASTORE.readAddressArray(id, key, index);
  }
}
