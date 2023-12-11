const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expectCustomError, expectEvent } = require("../utils/helpers");

contract("Whitelist", function () {
  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture));
  });

  const fixture = async () => {
    const [owner, user] = await ethers.getSigners();

    const contract = await ethers.deployContract("$Whitelist", [], {
      from: owner,
    });
    return { owner, user, contract };
  };

  describe("setAddress", function () {
    it("onlyOwner", async function () {
      console.log(this.owner.address, this.user.address);
      await expectCustomError(
        this.contract.connect(this.user).setAddress(this.owner.address, false),
        this.contract,
        "OwnableUnauthorizedAccount",
        [this.user.address]
      );
    });

    it("reverts if already set", async function () {
      await expectCustomError(
        this.contract.setAddress(this.user, false, { from: this.owner }),
        this.contract,
        "AlreadySet"
      );

      await this.contract.setAddress(this.user, true, { from: this.owner });

      await expectCustomError(
        this.contract.setAddress(this.user, true, { from: this.owner }),
        this.contract,
        "AlreadySet"
      );
    });

    it("isAllowed returns correct", async function () {
      await this.contract.setAddress(this.user, true);
      expect(await this.contract.isAllowed(this.user)).to.be.equal(true);

      await this.contract.setAddress(this.user, false);
      expect(await this.contract.isAllowed(this.user)).to.be.equal(false);

      await this.contract.setAddress(this.user, true);
      expect(await this.contract.isAllowed(this.user)).to.be.equal(true);

      await this.contract.setAddress(this.user, false);
      expect(await this.contract.isAllowed(this.user)).to.be.equal(false);
    });

    it("emits Listed", async function () {
      let receipt = await this.contract.setAddress(this.user, true);
      await expectEvent(receipt, this.contract, "Listed", [this.user.address, true]);

      receipt = await this.contract.setAddress(this.user, false);
      await expectEvent(receipt, this.contract, "Listed", [this.user.address, false]);
    });
  });
});
