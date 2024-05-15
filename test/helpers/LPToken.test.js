const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { deployWithProxy } = require("../utils/helpers");
const {
  shouldBehaveLikeERC20,
  shouldBehaveLikeERC20Transfer,
  shouldBehaveLikeERC20Approve,
} = require("../utils/ERC20.behavior");

contract("LPToken", function (accounts) {
  const name = "LPToken";
  const symbol = "LPT";
  const initialSupply = 100n;

  const fixture = async () => {
    const [initialHolder, recipient, anotherAccount] = await ethers.getSigners();

    const token = await deployWithProxy("$LPToken", [name, symbol]);
    await token.$_mint(initialHolder, initialSupply);

    return { initialHolder, recipient, anotherAccount, token };
  };

  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture));
    this.approve = (owner, spender, value) => this.token.connect(owner).approve(spender, value);
  });

  shouldBehaveLikeERC20(initialSupply);

  describe("mint", function () {
    it("cannot mint 0", async function () {
      await expect(
        this.token.mint(this.initialHolder.address, 0n, { from: this.initialHolder })
      ).to.be.revertedWithCustomError(this.token, "LPTokenZeroMint");
    });
  });

  describe("_update", function () {
    it("cannot send to itself", async function () {
      await expect(this.token.$_update(this.initialHolder.address, this.token.target, 1n))
        .to.be.revertedWithCustomError(this.token, "ERC20InvalidReceiver")
        .withArgs(this.token.target);
    });
  });
});
