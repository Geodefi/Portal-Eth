const { solidity } = require("ethereum-waffle");
const { deployments } = require("hardhat");

const chai = require("chai");
const { RAND_ADDRESS } = require("../testUtils");

chai.use(solidity);
const { expect } = chai;

describe("SwapInitialize", () => {
  // Test Values
  let gETHReference;

  const INITIAL_A_VALUE = 50;
  const SWAP_FEE = 1e7;
  const LP_TOKEN_NAME = "Test LP Token Name";
  const LP_TOKEN_SYMBOL = "TESTLP";

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture(); // ensure you start from a fresh deployments

      swap = await ethers.getContract("Swap");
      gETHReference = (await deployments.get("gETH")).address;
      LPToken = (await deployments.get("LPToken")).address;
    }
  );

  beforeEach(async () => {
    await setupTest();
  });

  describe("swapStorage#constructor", () => {
    it("Reverts with '_a exceeds maximum'", async () => {
      await expect(
        swap.initialize(
          gETHReference,
          [0, 1],
          LP_TOKEN_NAME,
          LP_TOKEN_SYMBOL,
          10e6 + 1,
          SWAP_FEE,
          0,
          LPToken
        )
      ).to.be.revertedWith("_a exceeds maximum");
    });

    it("Reverts with '_fee exceeds maximum'", async () => {
      await expect(
        swap.initialize(
          gETHReference,
          [0, 1],
          LP_TOKEN_NAME,
          LP_TOKEN_SYMBOL,
          INITIAL_A_VALUE,
          10e8 + 1,
          0,
          LPToken
        )
      ).to.be.revertedWith("_fee exceeds maximum");
    });

    it("Reverts with '_adminFee exceeds maximum'", async () => {
      await expect(
        swap.initialize(
          (
            await deployments.get("LPToken")
          ).address,
          [0, 1],
          LP_TOKEN_NAME,
          LP_TOKEN_SYMBOL,
          INITIAL_A_VALUE,
          SWAP_FEE,
          10e10 + 1,
          LPToken
        )
      ).to.be.revertedWith("_adminFee exceeds maximum");
    });

    it("Reverts when the LPToken target does not implement initialize function", async () => {
      await expect(
        swap.initialize(
          gETHReference,
          [0, 1],
          LP_TOKEN_NAME,
          LP_TOKEN_SYMBOL,
          INITIAL_A_VALUE,
          SWAP_FEE,
          0,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWith("Swap: lpTokenTargetAddress can not be zero");
      await expect(
        swap.initialize(
          gETHReference,
          [0, 1],
          LP_TOKEN_NAME,
          LP_TOKEN_SYMBOL,
          INITIAL_A_VALUE,
          SWAP_FEE,
          0,
          RAND_ADDRESS
        )
      ).to.be.revertedWith("function returned an unexpected amount of data");
    });
  });
});
