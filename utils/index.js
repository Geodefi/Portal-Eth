const { ethers, network } = require("hardhat");
const { BN } = require("@openzeppelin/test-helpers");

// functions

module.exports.strToBytes = function (key) {
  // string to bytes

  return web3.utils.toHex(key);
};

module.exports.strToBytes32 = function (key) {
  // string to bytes32
  // Note 1: formatBytes32String becomes encodeBytes32String in v6, currently using v5 of ethers package
  // Note 2: Fixed since we bumped to v6.
  return ethers.encodeBytes32String(key);
};

module.exports.intToBytes32 = function (x) {
  // integer to bytes32
  // Note: The biggest number that hexlify can get is 2^53-2,
  return ethers.zeroPadValue(ethers.toBeHex(x), 32);
};

module.exports.generateId = function (_name, _type) {
  // Note: web3.utils.soliditySha3 and ethers.utils.solidityKeccak256 is not returning the same value
  // while working with numbers, need to be careful while working with it.
  return new BN(
    web3.utils.soliditySha3(web3.eth.abi.encodeParameters(["bytes", "uint256"], [_name, _type])),
    "hex"
  );
};

module.exports.generateId_old = function (_name, _type) {
  // Note: web3.utils.soliditySha3 and ethers.utils.solidityKeccak256 is not returning the same value
  // while working with numbers, need to be careful while working with it.
  return new BN(
    web3.utils.soliditySha3(
      web3.utils.encodePacked({ value: _name, type: "bytes" }, { value: _type, type: "uint256" })
    ),
    "hex"
  );
};

module.exports.generateAddress = function () {
  // integer to bytes32
  return web3.eth.accounts.create().address;
};

module.exports.getBlockTimestamp = async function () {
  // returns the timestamp of the latest block
  return new BN((await web3.eth.getBlock("latest")).timestamp);
};

module.exports.getReceiptTimestamp = async function (receipt) {
  // returns the timestamp of a tx receipt
  return new BN((await web3.eth.getBlock(receipt.receipt.blockHash)).timestamp);
};
async function forceAdvanceOneBlock(timestamp) {
  const params = timestamp ? [timestamp] : [];
  return ethers.provider.send("evm_mine", params);
}

module.exports.forceAdvanceOneBlock = forceAdvanceOneBlock;
module.exports.setTimestamp = async function (timestamp) {
  await forceAdvanceOneBlock(timestamp);
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

  // Note : If you are using  hardhat-ethers call getSigner after impersonating the account
  return await ethers.getSigner(address);
};

module.exports.delay = function (time) {
  return new Promise((resolve) => setTimeout(resolve, time));
};

// constants
const DAY = new BN("24").mul(new BN("60")).mul(new BN("60"));
module.exports.DAY = DAY;
module.exports.WEEK = DAY.mul(new BN("7"));
module.exports.PERCENTAGE_DENOMINATOR = new BN("10").pow(new BN("10"));
module.exports.ETHER_STR = "1000000000000000000";
