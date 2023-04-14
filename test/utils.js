// import { BigNumber, Bytes, ContractFactory, Signer, providers } from "ethers"
// import { ethers, network } from "hardhat"
const { ethers, network } = require("hardhat");

const {
  //   BigNumber,
  //   Bytes,
  //   ContractFactory,
  Signer,
  //   providers,
} = require("ethers");

// import { ERC20 } from "../build/typechain/ERC20"
// import { Swap } from "../build/typechain/Swap"
// import merkleTreeDataTest from "../test/exampleMerkleTree.json"
// const { merkleTreeDataTest } = require("../test/exampleMerkleTree.json");

module.exports.MAX_UINT256 = ethers.constants.MaxUint256;
module.exports.ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
module.exports.DEAD_ADDRESS = "0x000000000000000000000000000000000000dEaD";
module.exports.RAND_ADDRESS = "0x5B6Dac8Ecf0EEce87c0488968F8b88d34dD495Ea";

// export enum TIME {
//   SECONDS = 1,
//   DAYS = 86400,
//   WEEKS = 604800,
// }

// Proposal
module.exports.TIME = {
  SECONDS: 1,
  DAYS: 86400,
  WEEKS: 604800,
};

// DEPLOYMENT helper functions

// Workaround for linking libraries not yet working in buidler-waffle plugin
// https://github.com/nomiclabs/buidler/issues/611

function linkBytecode(artifact, libraries) {
  let bytecode = artifact.bytecode;

  for (const [, fileReferences] of Object.entries(artifact.linkReferences)) {
    for (const [libName, fixups] of Object.entries(fileReferences)) {
      const addr = libraries[libName];
      if (addr === undefined) {
        continue;
      }

      for (const fixup of fixups) {
        bytecode =
          bytecode.substr(0, 2 + fixup.start * 2) +
          addr.substr(2) +
          bytecode.substr(2 + (fixup.start + fixup.length) * 2);
      }
    }
  }

  return bytecode;
}
module.exports.linkBytecode = linkBytecode;

async function deployContractWithLibraries(signer, artifact, libraries, args) {
  const swapFactory = await ethers.getContractFactory(
    artifact.abi,
    linkBytecode(artifact, libraries),
    signer
  );

  if (args) {
    return swapFactory.deploy(...args);
  } else {
    return swapFactory.deploy();
  }
}
module.exports.deployContractWithLibraries = deployContractWithLibraries;

// function getTestMerkleRoot() {
//   return merkleTreeDataTest.merkleRoot;
// };
// module.exports.getTestMerkleRoot = getTestMerkleRoot;

// function getTestMerkleAllowedAccounts() {
//   return merkleTreeDataTest.allowedAccounts;
// }
// module.exports.getTestMerkleAllowedAccounts = getTestMerkleAllowedAccounts;

// function getTestMerkleProof(address) {
//   const ALLOWED_ACCOUNTS = getTestMerkleAllowedAccounts();

//   if (address in ALLOWED_ACCOUNTS) {
//     return ALLOWED_ACCOUNTS[address].proof;
//   }
//   return [];
// }
// module.exports.getTestMerkleProof = getTestMerkleProof;

// Contract calls
async function getPoolBalances(swap, numOfTokens) {
  const balances = [];

  for (let i = 0; i < numOfTokens; i++) {
    balances.push(await swap.getTokenBalance(i));
  }
  return balances;
}
module.exports.getPoolBalances = getPoolBalances;

async function getUserTokenBalances(address, tokenIds, gETHReference) {
  const balanceArray = [];

  if (address instanceof Signer) {
    address = await address.getAddress();
  }

  for (const tokenId of tokenIds) {
    balanceArray.push(await gETHReference.balanceOf(address, tokenId));
  }

  return balanceArray;
}
module.exports.getUserTokenBalances = getUserTokenBalances;

async function getUserTokenBalance(address, tokenId, gETHReference) {
  if (address instanceof Signer) {
    address = await address.getAddress();
  }
  return gETHReference.balanceOf(address, tokenId);
}
module.exports.getUserTokenBalance = getUserTokenBalance;

// EVM methods

async function forceAdvanceOneBlock(timestamp) {
  const params = timestamp ? [timestamp] : [];
  return ethers.provider.send("evm_mine", params);
}
module.exports.forceAdvanceOneBlock = forceAdvanceOneBlock;

async function setTimestamp(timestamp) {
  return forceAdvanceOneBlock(timestamp);
}
module.exports.setTimestamp = setTimestamp;

async function increaseTimestamp(timestampDelta) {
  await ethers.provider.send("evm_increaseTime", [timestampDelta]);
  return forceAdvanceOneBlock();
}
module.exports.increaseTimestamp = increaseTimestamp;

async function setNextTimestamp(timestamp) {
  const chainId = (await ethers.provider.getNetwork()).chainId;

  switch (chainId) {
    case 31337: // buidler evm
      return ethers.provider.send("evm_setNextBlockTimestamp", [timestamp]);
    case 1337: // ganache
    default:
      return setTimestamp(timestamp);
  }
}
module.exports.setNextTimestamp = setNextTimestamp;

async function getCurrentBlockTimestamp() {
  const block = await ethers.provider.getBlock("latest");
  return block.timestamp;
}
module.exports.getCurrentBlockTimestamp = getCurrentBlockTimestamp;

async function impersonateAccount(address) {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [address],
  });

  return ethers.provider.getSigner(address);
}
module.exports.impersonateAccount = impersonateAccount;

async function asyncForEach(array, callback) {
  for (let index = 0; index < array.length; index++) {
    await callback(array[index], index);
  }
}
module.exports.asyncForEach = asyncForEach;
