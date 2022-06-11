// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "../../utils/DataStoreLib.sol";

contract DataStoreUtilsTest {
  using DataStoreUtils for DataStoreUtils.DataStore;
  DataStoreUtils.DataStore private DATASTORE;

  function readUintForId(uint256 _id, bytes32 _key)
    public
    view
    returns (uint256 data)
  {
    data = DATASTORE.readUintForId(_id, _key);
  }

  function readBytesForId(uint256 _id, bytes32 _key)
    public
    view
    returns (bytes memory data)
  {
    data = DATASTORE.readBytesForId(_id, _key);
  }

  function readAddressForId(uint256 _id, bytes32 _key)
    public
    view
    returns (address data)
  {
    data = DATASTORE.readAddressForId(_id, _key);
  }

  function writeUintForId(
    uint256 _id,
    bytes32 _key,
    uint256 data
  ) public {
    DATASTORE.writeUintForId(_id, _key, data);
  }

  function writeBytesForId(
    uint256 _id,
    bytes32 _key,
    bytes memory data
  ) public {
    DATASTORE.writeBytesForId(_id, _key, data);
  }

  function writeAddressForId(
    uint256 _id,
    bytes32 _key,
    address data
  ) public {
    DATASTORE.writeAddressForId(_id, _key, data);
  }
}