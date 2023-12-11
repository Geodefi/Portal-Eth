const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ZERO_ADDRESS } = require("../../utils/helpers");

contract("ERC1155Supply", function (accounts) {
  const [holder] = accounts;

  const uri = "https://token.com";

  const firstTokenId = BigInt("37");
  const firstTokenValue = BigInt("42");

  const secondTokenId = BigInt("19842");
  const secondTokenValue = BigInt("23");

  const fixture = async () => {
    const [holder] = await ethers.getSigners();

    const token = await ethers.deployContract("$ERC1155Supply", [uri]);

    return { holder, token };
  };

  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture));
  });

  context("before mint", function () {
    it("exist", async function () {
      expect(await this.token.exists(firstTokenId)).to.be.equal(false);
    });

    it("totalSupply", async function () {
      expect(await this.token.totalSupply(ethers.Typed.uint256(firstTokenId))).to.be.equal("0");
      expect(await this.token.totalSupply()).to.be.equal("0");
    });
  });

  context("after mint", function () {
    context("single", function () {
      beforeEach(async function () {
        await this.token.$_mint(holder, firstTokenId, firstTokenValue, "0x");
      });

      it("exist", async function () {
        expect(await this.token.exists(firstTokenId)).to.be.equal(true);
      });

      it("totalSupply", async function () {
        expect(await this.token.totalSupply(ethers.Typed.uint256(firstTokenId))).to.be.equal(
          firstTokenValue
        );
        expect(await this.token.totalSupply()).to.be.equal(firstTokenValue);
      });
    });

    context("batch", function () {
      beforeEach(async function () {
        await this.token.$_mintBatch(
          holder,
          [firstTokenId, secondTokenId],
          [firstTokenValue, secondTokenValue],
          "0x"
        );
      });

      it("exist", async function () {
        expect(await this.token.exists(firstTokenId)).to.be.equal(true);
        expect(await this.token.exists(secondTokenId)).to.be.equal(true);
      });

      it("totalSupply", async function () {
        expect(await this.token.totalSupply(ethers.Typed.uint256(firstTokenId))).to.be.equal(
          firstTokenValue
        );
        expect(await this.token.totalSupply(ethers.Typed.uint256(secondTokenId))).to.be.equal(
          secondTokenValue
        );
        expect(await this.token.totalSupply()).to.be.equal(firstTokenValue + secondTokenValue);
      });
    });
  });

  context("after burn", function () {
    context("single", function () {
      beforeEach(async function () {
        await this.token.$_mint(holder, firstTokenId, firstTokenValue, "0x");
        await this.token.$_burn(holder, firstTokenId, firstTokenValue);
      });

      it("exist", async function () {
        expect(await this.token.exists(firstTokenId)).to.be.equal(false);
      });

      it("totalSupply", async function () {
        expect(await this.token.totalSupply(ethers.Typed.uint256(firstTokenId))).to.be.equal("0");
        expect(await this.token.totalSupply()).to.be.equal("0");
      });
    });

    context("batch", function () {
      beforeEach(async function () {
        await this.token.$_mintBatch(
          holder,
          [firstTokenId, secondTokenId],
          [firstTokenValue, secondTokenValue],
          "0x"
        );
        await this.token.$_burnBatch(
          holder,
          [firstTokenId, secondTokenId],
          [firstTokenValue, secondTokenValue]
        );
      });

      it("exist", async function () {
        expect(await this.token.exists(firstTokenId)).to.be.equal(false);
        expect(await this.token.exists(secondTokenId)).to.be.equal(false);
      });

      it("totalSupply", async function () {
        expect(await this.token.totalSupply(ethers.Typed.uint256(firstTokenId))).to.be.equal("0");
        expect(await this.token.totalSupply(ethers.Typed.uint256(secondTokenId))).to.be.equal("0");
        expect(await this.token.totalSupply()).to.be.equal("0");
      });
    });
  });

  context("other", function () {
    it("supply unaffected by no-op", async function () {
      this.token.safeTransferFrom(ZERO_ADDRESS, ZERO_ADDRESS, firstTokenId, firstTokenValue, "0x", {
        from: ZERO_ADDRESS,
      });
      expect(await this.token.totalSupply(ethers.Typed.uint256(firstTokenId))).to.be.equal("0");
      expect(await this.token.totalSupply()).to.be.equal("0");
    });
  });
});
