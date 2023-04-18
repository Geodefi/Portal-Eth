const { network } = require("hardhat");
const { BN } = require("@openzeppelin/test-helpers");

// functions

module.exports.strToBytes = function (key) {
  // string to bytes

  return web3.utils.toHex(key);
};

module.exports.strToBytes32 = function (key) {
  // string to bytes32

  return ethers.utils.formatBytes32String(key);
};

module.exports.intToBytes32 = function (x) {
  // integer to bytes32

  return ethers.utils.hexZeroPad(ethers.utils.hexlify(x), 32);
};
module.exports.generateAddress = function (x) {
  // integer to bytes32

  return web3.eth.accounts.create().address;
};
module.exports.getReceiptTimestamp = async function (receipt) {
  // returns the timestamp of a tx receipt
  return new BN((await web3.eth.getBlock(receipt.receipt.blockHash)).timestamp);
};

module.exports.impersonate = async function (address, balance) {
  // allows calling functions from contracts

  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [address],
  });

  await network.provider.request({
    method: "hardhat_setBalance",
    params: [address, web3.utils.toHex(balance)],
  });
};

// constants
module.exports.ETHER_STR = "1000000000000000000";
// module.exports.MAX_UINT256 = ethers.constants.MaxUint256;
