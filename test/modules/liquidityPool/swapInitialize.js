const { solidity } = require("ethereum-waffle");
const { deployments } = require("hardhat");

const chai = require("chai");
const { RAND_ADDRESS, ZERO_ADDRESS } = require("../utils");

chai.use(solidity);
const { expect } = chai;

describe("SwapInitialize", () => {
  // Test Values
  let gETHReference;
  let deployer;
  const LP_TOKEN_NAME = "Test LP Token Name";
  const LP_TOKEN_SYMBOL = "TESTLP";

  const setupTest = deployments.createFixture(async ({ deployments, ethers }) => {
    await deployments.fixture(); // ensure you start from a fresh deployments
    signers = await ethers.getSigners();
    deployer = signers[0];

    swap = await ethers.getContractAt("Swap", (await deployments.get("Swap")).address);

    gETHReference = (await deployments.get("gETH")).address;
    LPToken = (await deployments.get("LPToken")).address;
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("swapStorage#constructor", () => {
    it("Reverts with ' _gETH can not be zero'", async () => {
      await expect(
        swap.initialize(ZERO_ADDRESS, 1, LP_TOKEN_NAME, LP_TOKEN_SYMBOL, LPToken, deployer.address)
      ).to.be.revertedWith("_gETH can not be zero");
    });

    it("Reverts with ' lpTokenTargetAddress can not be zero'", async () => {
      await expect(
        swap.initialize(
          gETHReference,
          1,
          LP_TOKEN_NAME,
          LP_TOKEN_SYMBOL,
          ZERO_ADDRESS,
          deployer.address
        )
      ).to.be.revertedWith("lpTokenTargetAddress can not be zero");
    });

    it("Reverts with ' owner can not be zero'", async () => {
      await expect(
        swap.initialize(gETHReference, 1, LP_TOKEN_NAME, LP_TOKEN_SYMBOL, LPToken, ZERO_ADDRESS)
      ).to.be.revertedWith("owner can not be zero");
    });

    it("Reverts with ' _pooledTokenId can not be zero'", async () => {
      await expect(
        swap.initialize(gETHReference, 0, LP_TOKEN_NAME, LP_TOKEN_SYMBOL, LPToken, deployer.address)
      ).to.be.revertedWith("_pooledTokenId can not be zero");
    });

    it("Reverts when the LPToken target does not implement initialize function", async () => {
      await expect(
        swap.initialize(
          gETHReference,
          1,
          LP_TOKEN_NAME,
          LP_TOKEN_SYMBOL,
          ethers.constants.AddressZero,
          deployer.address
        )
      ).to.be.revertedWith("Swap: lpTokenTargetAddress can not be zero");
      await expect(
        swap.initialize(
          gETHReference,
          1,
          LP_TOKEN_NAME,
          LP_TOKEN_SYMBOL,
          RAND_ADDRESS,
          deployer.address
        )
      ).to.be.reverted;
    });
  });
});
