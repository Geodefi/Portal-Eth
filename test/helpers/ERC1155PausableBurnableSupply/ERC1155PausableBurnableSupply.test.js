const { expectRevert, constants, BN } = require("@openzeppelin/test-helpers");

const { expect } = require("chai");

const ERC1155PausableBurnableSupply = artifacts.require("$ERC1155PausableBurnableSupply");

contract("ERC1155PausableBurnableSupply", function (accounts) {
  const [deployer, other] = accounts;

  const uri = "https://token.com";
  const data = constants.ZERO_BYTES32;

  const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
  const URI_SETTER_ROLE = web3.utils.soliditySha3("URI_SETTER_ROLE");
  const MINTER_ROLE = web3.utils.soliditySha3("MINTER_ROLE");
  const PAUSER_ROLE = web3.utils.soliditySha3("PAUSER_ROLE");

  const tokenId = new BN("69");
  const amount = new BN("696969");

  const tokenIds = [new BN("42"), new BN("1137")];
  const amounts = [new BN("3000"), new BN("9902")];

  beforeEach(async function () {
    this.token = await ERC1155PausableBurnableSupply.new(uri, { from: deployer });
  });

  describe("constructor", function () {
    it("deployer does not have DEFAULT_ADMIN_ROLE", async function () {
      expect(await this.token.hasRole(DEFAULT_ADMIN_ROLE, deployer)).to.equal(false);
    });
    it("deployer has URI_SETTER_ROLE", async function () {
      expect(await this.token.hasRole(URI_SETTER_ROLE, deployer)).to.equal(true);
    });
    it("deployer has PAUSER_ROLE", async function () {
      expect(await this.token.hasRole(PAUSER_ROLE, deployer)).to.equal(true);
    });
    it("deployer has MINTER_ROLE", async function () {
      expect(await this.token.hasRole(MINTER_ROLE, deployer)).to.equal(true);
    });
  });

  describe("setURI", function () {
    const newUri = "https://new-uri.com";

    it("deployer can set URI", async function () {
      await this.token.setURI(newUri);
      expect(await this.token.uri(0)).to.equal(newUri);
    });

    it("others can not set URI", async function () {
      await expectRevert(
        this.token.setURI(newUri, { from: other }),
        `AccessControl: account ${other.toLowerCase()} is missing role ${URI_SETTER_ROLE}`
      );
    });
  });

  describe("pause", function () {
    it("deployer can pause", async function () {
      await this.token.pause();
      expect(await this.token.paused()).to.equal(true);
    });

    it("others can not pause", async function () {
      await expectRevert(
        this.token.pause({ from: other }),
        `AccessControl: account ${other.toLowerCase()} is missing role ${PAUSER_ROLE}`
      );
    });
  });

  describe("unpause", function () {
    beforeEach(async function () {
      await this.token.pause({ from: deployer });
    });

    it("deployer can unpause", async function () {
      await this.token.unpause();
      expect(await this.token.paused()).to.equal(false);
    });

    it("others can not unpause", async function () {
      await expectRevert(
        this.token.unpause({ from: other }),
        `AccessControl: account ${other.toLowerCase()} is missing role ${PAUSER_ROLE}`
      );
    });
  });

  describe("mint", function () {
    it("deployer can mint", async function () {
      await this.token.mint(deployer, tokenId, amount, data);
      expect(await this.token.balanceOf(deployer, tokenId)).to.be.bignumber.equal(amount);
    });

    it("others can not mint", async function () {
      await expectRevert(
        this.token.mint(other, tokenId, amount, data, { from: other }),
        `AccessControl: account ${other.toLowerCase()} is missing role ${MINTER_ROLE}`
      );
    });
  });

  describe("mintBatch", function () {
    it("deployer can mintBatch", async function () {
      await this.token.mintBatch(deployer, tokenIds, amounts, data);

      for (let i = 0; i < tokenIds.length; i++) {
        expect(await this.token.balanceOf(deployer, tokenIds[[i]])).to.be.bignumber.equal(
          amounts[i]
        );
      }
    });

    it("others can not mintBatch", async function () {
      await expectRevert(
        this.token.mintBatch(other, tokenIds, amounts, data, { from: other }),
        `AccessControl: account ${other.toLowerCase()} is missing role ${MINTER_ROLE}`
      );
    });
  });

  describe("_beforeTokenTransfer", function () {
    it("can not call when paused", async function () {
      await this.token.pause({ from: deployer });
      await expectRevert(
        this.token.$_beforeTokenTransfer(deployer, deployer, deployer, tokenIds, amounts, data, {
          from: other,
        }),
        "Pausable: paused"
      );
    });
  });
});
