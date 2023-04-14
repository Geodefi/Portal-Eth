const { network } = require("hardhat");
const { BN } = require("@openzeppelin/test-helpers");

async function getReceiptTimestamp(receipt) {
  return new BN((await web3.eth.getBlock(receipt.receipt.blockHash)).timestamp);
}

async function impersonate(address, balance) {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [address],
  });

  await network.provider.request({
    method: "hardhat_setBalance",
    params: [address, web3.utils.toHex(balance)],
  });
}

// funcs
module.exports.getReceiptTimestamp = getReceiptTimestamp;
module.exports.impersonate = impersonate;

// vars
module.exports.etherStr = "1000000000000000000";
