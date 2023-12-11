const { ethers } = require("hardhat");
const { expect } = require("chai");
const { ZERO_BYTES32 } = require("../../utils/helpers");

/**
 * Future Ref: this is one way test a contract:
 * should use: ethers.deployContract()            instead of  artifacts.require
 * should use: connect()                          instead of  {from:}
 * should use: ethers.getSigners()                instead of  '=accounts' (might be same)
 * should use: .revertedWithCustomError.withArgs  instead of  expectCustomError
 * *
 * However, (for ease) we will continue using current setup outside of this file and reconsider later.
 */

// const ERC1155PausableBurnableSupply = artifacts.require("$ERC1155PausableBurnableSupply");

contract("ERC1155PausableBurnableSupply", function (accounts) {
  const uri = "https://token.com";
  const newUri = "https://new-uri.com";
  const data = ZERO_BYTES32;

  const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
  // this is :
  // const URI_SETTER_ROLE = web3.utils.soliditySha3("URI_SETTER_ROLE");
  // const MINTER_ROLE = web3.utils.soliditySha3("MINTER_ROLE");
  // const PAUSER_ROLE = web3.utils.soliditySha3("PAUSER_ROLE");
  // same with : - tested
  const URI_SETTER_ROLE = ethers.id("URI_SETTER_ROLE");
  const MINTER_ROLE = ethers.id("MINTER_ROLE");
  const PAUSER_ROLE = ethers.id("PAUSER_ROLE");

  const tokenId = "69";
  const amount = "696969";

  const tokenIds = ["42", "1137"];
  const amounts = ["3000", "9902"];

  beforeEach(async function () {
    const [deployer, other] = await ethers.getSigners();
    this.deployer = deployer;
    this.other = other;

    this.token = await ethers.deployContract("$ERC1155PausableBurnableSupply", [uri], {
      from: this.deployer,
    });
  });

  describe("constructor", function () {
    it("deployer has DEFAULT_ADMIN_ROLE", async function () {
      expect(await this.token.hasRole(DEFAULT_ADMIN_ROLE, this.deployer.address)).to.equal(true);
    });
    it("deployer has URI_SETTER_ROLE", async function () {
      expect(await this.token.hasRole(URI_SETTER_ROLE, this.deployer.address)).to.equal(true);
    });
    it("deployer has PAUSER_ROLE", async function () {
      expect(await this.token.hasRole(PAUSER_ROLE, this.deployer.address)).to.equal(true);
    });
    it("deployer has MINTER_ROLE", async function () {
      expect(await this.token.hasRole(MINTER_ROLE, this.deployer.address)).to.equal(true);
    });
  });

  describe("setURI", function () {
    it("deployer can set URI", async function () {
      await this.token.setURI(newUri);
      expect(await this.token.uri(0)).to.equal(newUri);
    });

    it("others can not set URI", async function () {
      await expect(this.token.connect(this.other).setURI(newUri))
        .to.be.revertedWithCustomError(this.token, "AccessControlUnauthorizedAccount")
        .withArgs(this.other.address, URI_SETTER_ROLE);
    });
  });

  describe("pause", function () {
    it("deployer can pause", async function () {
      await this.token.pause();
      expect(await this.token.paused()).to.equal(true);
    });

    it("others can not pause", async function () {
      await expect(this.token.connect(this.other).pause())
        .to.be.revertedWithCustomError(this.token, "AccessControlUnauthorizedAccount")
        .withArgs(this.other.address, PAUSER_ROLE);
    });
  });

  describe("unpause", function () {
    beforeEach(async function () {
      await this.token.connect(this.deployer).pause();
    });

    it("deployer can unpause", async function () {
      await this.token.unpause();
      expect(await this.token.paused()).to.equal(false);
    });

    it("others can not unpause", async function () {
      console.log(this.other.address, PAUSER_ROLE);
      await expect(this.token.connect(this.other).unpause())
        .to.be.revertedWithCustomError(this.token, "AccessControlUnauthorizedAccount")
        .withArgs(this.other.address, PAUSER_ROLE);
    });
  });

  describe("mint", function () {
    it("deployer can mint", async function () {
      await this.token.mint(this.deployer.address, tokenId, amount, data);
      expect(await this.token.balanceOf(this.deployer.address, tokenId)).to.be.equal(amount);
    });

    it("others can not mint", async function () {
      await expect(this.token.connect(this.other).mint(this.other.address, tokenId, amount, data))
        .to.be.revertedWithCustomError(this.token, "AccessControlUnauthorizedAccount")
        .withArgs(this.other.address, MINTER_ROLE);
    });
  });

  describe("mintBatch", function () {
    it("deployer can mintBatch", async function () {
      await this.token.mintBatch(this.deployer.address, tokenIds, amounts, data);

      for (let i = 0; i < tokenIds.length; i++) {
        expect(await this.token.balanceOf(this.deployer.address, tokenIds[[i]])).to.be.equal(
          amounts[i]
        );
      }
    });

    it("others can not mintBatch", async function () {
      await expect(
        this.token.connect(this.other).mintBatch(this.other.address, tokenIds, amounts, data)
      )
        .to.be.revertedWithCustomError(this.token, "AccessControlUnauthorizedAccount")
        .withArgs(this.other.address, MINTER_ROLE);
    });
  });
});
