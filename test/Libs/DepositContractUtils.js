const { deployments } = require("hardhat");
const { solidity } = require("ethereum-waffle");

const chai = require("chai");
chai.use(solidity);
const { expect } = chai;


describe("DepositContractUtils", async () => {

    const setupTest = deployments.createFixture(async (hre) => {
        ({ ethers, web3, Web3 } = hre);
        const { get } = deployments;
        const signers = await ethers.getSigners();
        user1 = signers[1];
    
        await deployments.fixture(); // ensure you start from a fresh deployments
        const DataStoreUtilsTest = await ethers.getContractFactory(
          "DepositContractUtilsTest",
          {
            libraries: {
              DataStoreUtils: (await get("DepositContractUtils")).address,
            },
          }
        );
        testContract = await DataStoreUtilsTest.deploy();
      });
    
});