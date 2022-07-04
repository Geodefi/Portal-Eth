const { solidity } = require("ethereum-waffle");
const chai = require("chai");
const { deployments } = require("hardhat");

chai.use(solidity);
const { expect } = chai;

describe("LPToken", async () => {
  let signers;
  let owner;
  let firstToken;
  let lpTokenFactory;

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture(); // ensure you start from a fresh deployments

      signers = await ethers.getSigners();
      owner = signers[0];
      lpTokenFactory = await ethers.getContractFactory("LPToken");
      firstToken = await lpTokenFactory.deploy();
      firstToken.initialize("Test Token", "TEST");
    }
  );

  beforeEach(async () => {
    await setupTest();
  });

  it("Reverts when minting 0", async () => {
    // Deploy dummy tokens

    await expect(
      firstToken.mint(await owner.getAddress(), 0)
    ).to.be.revertedWith("LPToken: cannot mint 0");
  });

  it("Reverts when transferring the token to itself", async () => {
    // Transferring LPToken to itself should revert
    await expect(
      firstToken.transfer(firstToken.address, String(100e18))
    ).to.be.revertedWith("LPToken: cannot send to itself");
  });
});
