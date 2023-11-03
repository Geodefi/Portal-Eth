const { expect } = require("chai");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");

const Whitelist = artifacts.require("$Whitelist");

contract("Whitelist", function (accounts) {
  const [owner, user] = accounts;

  beforeEach(async function () {
    this.contract = await Whitelist.new({ from: owner });
  });

  describe("setAddress", function () {
    it("onlyOwner", async function () {
      await expectRevert(
        this.contract.setAddress(owner, false, { from: user }),
        "Ownable: caller is not the owner"
      );
    });

    it("reverts if already set", async function () {
      await expectRevert(
        this.contract.setAddress(user, false, { from: owner }),
        "Whitelist: already set"
      );

      await this.contract.setAddress(user, true, { from: owner });

      await expectRevert(
        this.contract.setAddress(user, true, { from: owner }),
        "Whitelist: already set"
      );
    });

    it("isAllowed returns correct", async function () {
      await this.contract.setAddress(user, true);
      expect(await this.contract.isAllowed(user)).to.be.equal(true);

      await this.contract.setAddress(user, false);
      expect(await this.contract.isAllowed(user)).to.be.equal(false);

      await this.contract.setAddress(user, true);
      expect(await this.contract.isAllowed(user)).to.be.equal(true);

      await this.contract.setAddress(user, false);
      expect(await this.contract.isAllowed(user)).to.be.equal(false);
    });

    it("emits Listed", async function () {
      await expectEvent(await this.contract.setAddress(user, true), "Listed", {
        account: user,
        isWhitelisted: true,
      });
      await expectEvent(await this.contract.setAddress(user, false), "Listed", {
        account: user,
        isWhitelisted: false,
      });
    });
  });
});
