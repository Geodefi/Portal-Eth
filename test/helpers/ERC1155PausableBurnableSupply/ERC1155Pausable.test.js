const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expectCustomError } = require("../../utils/helpers");

contract("ERC1155Pausable", function (accounts) {
  const uri = "https://token.com";

  const fixture = async () => {
    const [holder, operator, receiver, other] = await ethers.getSigners();

    const token = await ethers.deployContract("$ERC1155Pausable", [uri]);

    return { holder, operator, receiver, other, token };
  };

  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture));
  });

  context("when token is paused", function () {
    const firstTokenId = BigInt("37");
    const firstTokenValue = BigInt("42");

    const secondTokenId = BigInt("19842");
    const secondTokenValue = BigInt("23");

    beforeEach(async function () {
      await this.token.connect(this.holder).setApprovalForAll(this.operator, true);
      await this.token.$_mint(this.holder, firstTokenId, firstTokenValue, "0x");

      await this.token.$_pause();
    });

    it("reverts when trying to safeTransferFrom from holder", async function () {
      await expectCustomError(
        this.token
          .connect(this.holder)
          .safeTransferFrom(this.holder, this.receiver, firstTokenId, firstTokenValue, "0x"),
        this.token,
        "EnforcedPause",
        []
      );
    });

    it("reverts when trying to safeTransferFrom from operator", async function () {
      await expectCustomError(
        this.token
          .connect(this.operator)
          .safeTransferFrom(this.holder, this.receiver, firstTokenId, firstTokenValue, "0x"),
        this.token,
        "EnforcedPause",
        []
      );
    });

    it("reverts when trying to safeBatchTransferFrom from holder", async function () {
      await expectCustomError(
        this.token
          .connect(this.holder)
          .safeBatchTransferFrom(
            this.holder,
            this.receiver,
            [firstTokenId],
            [firstTokenValue],
            "0x"
          ),
        this.token,
        "EnforcedPause",
        []
      );
    });

    it("reverts when trying to safeBatchTransferFrom from operator", async function () {
      await expectCustomError(
        this.token
          .connect(this.operator)
          .safeBatchTransferFrom(
            this.holder,
            this.receiver,
            [firstTokenId],
            [firstTokenValue],
            "0x"
          ),
        this.token,
        "EnforcedPause",
        []
      );
    });

    it("reverts when trying to mint", async function () {
      await expectCustomError(
        this.token.$_mint(this.holder, secondTokenId, secondTokenValue, "0x"),
        this.token,
        "EnforcedPause",
        []
      );
    });

    it("reverts when trying to mintBatch", async function () {
      await expectCustomError(
        this.token.$_mintBatch(this.holder, [secondTokenId], [secondTokenValue], "0x"),
        this.token,
        "EnforcedPause",
        []
      );
    });

    it("reverts when trying to burn", async function () {
      await expectCustomError(
        this.token.$_burn(this.holder, firstTokenId, firstTokenValue),
        this.token,
        "EnforcedPause",
        []
      );
    });

    it("reverts when trying to burnBatch", async function () {
      await expectCustomError(
        this.token.$_burnBatch(this.holder, [firstTokenId], [firstTokenValue]),
        this.token,
        "EnforcedPause",
        []
      );
    });

    describe("setApprovalForAll", function () {
      it("approves an operator", async function () {
        await this.token.connect(this.holder).setApprovalForAll(this.other, true);
        expect(await this.token.isApprovedForAll(this.holder, this.other)).to.equal(true);
      });
    });

    describe("balanceOf", function () {
      it("returns the token value owned by the given address", async function () {
        const balance = await this.token.balanceOf(this.holder, firstTokenId);
        expect(balance).to.be.equal(firstTokenValue);
      });
    });

    describe("isApprovedForAll", function () {
      it("returns the approval of the operator", async function () {
        expect(await this.token.isApprovedForAll(this.holder, this.operator)).to.equal(true);
      });
    });
  });
});
