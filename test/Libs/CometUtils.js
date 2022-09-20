// const { Bytes } = require("ethers");
const { solidity } = require("ethereum-waffle");
const { deployments } = require("hardhat");

const chai = require("chai");

chai.use(solidity);
const { expect } = chai;
const randId = 3131313131;
const operatorId = 420420420;
const planetId = 696969696969;
const cometId = 123123123123;
const wrongId = 69;

describe("GeodeUtils", async () => {
  let testContract;
  let deployer;
  let planet;
  let comet;
  let operator;
  let user1;
  let user2;

  const setupTest = deployments.createFixture(async (hre) => {
    ({ ethers, web3, Web3 } = hre);

    signers = await ethers.getSigners();

    deployer = signers[0];
    planet = signers[2];
    comet = signers[3];
    operator = signers[4];
    user1 = signers[5];
    user2 = signers[6];

    await deployments.fixture(); // ensure you start from a fresh deployments
    const TestCometUtils = await ethers.getContractFactory("TestCometUtils", {
      libraries: {
        MaintainerUtils: (await get("MaintainerUtils")).address,
        OracleUtils: (await get("OracleUtils")).address,
        CometUtils: (await get("CometUtils")).address,
        StakeUtils: (await get("StakeUtils")).address,
      },
    });
    testContract = await TestCometUtils.deploy();
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("CometUtils", () => {
    describe("initiateComet", () => {
      it("reverts if fee is bigger than MAX_MAINTAINER_FEE", async () => {
        await testContract.initiateComet(cometId, "0", comet.address, [
          "comet_name",
          "comet_symbol",
        ]);
      });
    });
  });
});
