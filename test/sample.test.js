const { expect } = require("chai");

const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const {
  deployWithProxy,
  expectEvent,
  expectRevert,
  expectCustomError,
} = require("./utils/helpers");

contract("SampleContract", function () {
  const initParam = "name";
  const stateParam = ethers.id("URI_SETTER_ROLE");

  const fixture = async () => {
    const [deployer, other] = await ethers.getSigners();

    const contract = await ethers.deployContract("$ERC1155PausableBurnableSupply", [initParam], {
      from: deployer,
    });
    // OR if its upgradable:
    const contractUpgradable = await deployWithProxy("$LPToken", [initParam, initParam]);

    return { deployer, other, contract, contractUpgradable };
  };

  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture));
  });

  contract("SampleTest", function () {
    it("SampleCondition", async function () {
      // await expect(
      //   this.contractUpgradable.mint(this.other.address, 0n, { from: this.deployer })
      // ).to.be.revertedWithCustomError(this.contractUpgradable, "LPTokenZeroMint");
      // // above is the same with:
      await expectCustomError(
        this.contractUpgradable.connect(this.deployer).mint(this.other.address, 0n),
        this.contractUpgradable,
        "LPTokenZeroMint"
        // no arguments is ok!
      );
    });

    it("SampleCondition for Upgradable", async function () {
      // // connect!
      // await expect(this.contract.connect(this.other).setURI("newUri"))
      //   .to.be.revertedWithCustomError(this.contract, "AccessControlUnauthorizedAccount")
      //   .withArgs(this.other.address, stateParam);
      // // above is the same with:
      await expectCustomError(
        this.contract.connect(this.other).setURI("newUri"),
        this.contract,
        "AccessControlUnauthorizedAccount",
        [this.other.address, stateParam]
      );
    });
  });
});
