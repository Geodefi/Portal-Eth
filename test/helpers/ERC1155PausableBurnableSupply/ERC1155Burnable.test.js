const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expectCustomError } = require("../../utils/helpers");

contract("ERC1155Burnable", function () {
  const uri = "https://token.com";

  const tokenIds = [BigInt("42"), BigInt("1137")];
  const values = [BigInt("3000"), BigInt("9902")];

  const fixture = async () => {
    const [operator, holder, other] = await ethers.getSigners();

    const token = await ethers.deployContract("$ERC1155Burnable", [uri], {
      from: operator,
    });
    await token.$_mint(holder.address, tokenIds[0], values[0], "0x");
    await token.$_mint(holder.address, tokenIds[1], values[1], "0x");
    return { holder, operator, other, token };
  };

  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture));
  });

  describe("burn", function () {
    it("holder can burn their tokens", async function () {
      await this.token.connect(this.holder).burn(this.holder, tokenIds[0], values[0] - 1n);

      expect(await this.token.balanceOf(this.holder, tokenIds[0])).to.be.equal("1");
    });

    it("approved operators can burn the holder's tokens", async function () {
      await this.token.connect(this.holder).setApprovalForAll(this.operator, true);
      await this.token.connect(this.operator).burn(this.holder, tokenIds[0], values[0] - 1n);

      expect(await this.token.balanceOf(this.holder, tokenIds[0])).to.be.equal("1");
    });

    it("unapproved accounts cannot burn the holder's tokens", async function () {
      await expectCustomError(
        this.token.connect(this.other).burn(this.holder, tokenIds[0], values[0] - 1n),
        this.token,
        "ERC1155MissingApprovalForAll",
        [this.other, this.holder]
      );
    });
  });

  describe("burnBatch", function () {
    it("holder can burn their tokens", async function () {
      await this.token
        .connect(this.holder)
        .burnBatch(this.holder, tokenIds, [values[0] - 1n, values[1] - 2n]);

      expect(await this.token.balanceOf(this.holder, tokenIds[0])).to.be.equal("1");
      expect(await this.token.balanceOf(this.holder, tokenIds[1])).to.be.equal("2");
    });

    it("approved operators can burn the holder's tokens", async function () {
      await this.token.connect(this.holder).setApprovalForAll(this.operator, true);
      await this.token
        .connect(this.operator)
        .burnBatch(this.holder, tokenIds, [values[0] - 1n, values[1] - 2n]);

      expect(await this.token.balanceOf(this.holder, tokenIds[0])).to.be.equal("1");
      expect(await this.token.balanceOf(this.holder, tokenIds[1])).to.be.equal("2");
    });

    it("unapproved accounts cannot burn the holder's tokens", async function () {
      await expectCustomError(
        this.token
          .connect(this.other)
          .burnBatch(this.holder, tokenIds, [values[0] - 1n, values[1] - 2n]),
        this.token,
        "ERC1155MissingApprovalForAll",
        [this.other, this.holder]
      );
    });
  });
});
