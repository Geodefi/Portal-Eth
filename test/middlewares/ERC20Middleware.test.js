const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { silenceWarnings } = require("@openzeppelin/upgrades-core");

const {
  shouldBehaveLikeERC20,
  shouldBehaveLikeERC20Approve,
  shouldBehaveLikeERC20Transfer,
} = require("../utils/ERC20.behavior");

const { strToBytes, intToBytes32 } = require("../../utils");
const { deployWithProxy } = require("../utils/helpers");

contract("ERC20Middleware", function () {
  const name = "Test Staked Ether";
  const symbol = "tsETH";
  const tokenId = BigInt(420);
  const price = BigInt(1e18);
  const initialSupply = 100n * BigInt(1e18);

  const nameBytes = strToBytes(name).substr(2);
  const symbolBytes = strToBytes(symbol).substr(2);
  const middlewareData = intToBytes32(nameBytes.length / 2) + nameBytes + symbolBytes;

  const fixture = async () => {
    await silenceWarnings();

    const [initialHolder, recipient, anotherAccount] = await ethers.getSigners();

    const gETH = await ethers.deployContract("gETH", ["name", "symbol", "uri"]);

    const token = await deployWithProxy("$ERC20Middleware", [tokenId, gETH.target, middlewareData]);

    await gETH.mint(initialHolder, tokenId, initialSupply, "0x");
    await gETH.setMiddleware(token.target, tokenId, true);
    await gETH.setPricePerShare(price, tokenId);

    return { initialHolder, recipient, anotherAccount, token, gETH };
  };

  beforeEach(async function () {
    await silenceWarnings();
    Object.assign(this, await loadFixture(fixture));
    this.approve = (owner, spender, value) => this.token.connect(owner).approve(spender, value);
  });

  shouldBehaveLikeERC20(initialSupply);

  describe("initialize", function () {
    it("correct gETH address", async function () {
      expect(await this.token.ERC1155()).to.be.equal(this.gETH.target);
    });
    it("correct token id", async function () {
      expect(await this.token.ERC1155_ID()).to.be.equal(tokenId);
    });
    it("correct name", async function () {
      expect(await this.token.name()).to.be.equal(name);
    });
    it("correct symbol", async function () {
      expect(await this.token.symbol()).to.be.equal(symbol);
    });
    it("correct pricePerShare", async function () {
      expect(await this.token.pricePerShare()).to.be.equal(price);
    });
    it("has 18 decimals", async function () {
      expect(await this.token.decimals()).to.be.equal("18");
    });
  });

  describe("_transfer", function () {
    beforeEach(function () {
      this.transfer = this.token.$_transfer;
    });

    shouldBehaveLikeERC20Transfer(initialSupply);

    it("reverts when the sender is the zero address", async function () {
      await expect(this.token.$_transfer(ethers.ZeroAddress, this.recipient, initialSupply))
        .to.be.revertedWithCustomError(this.token, "ERC20InvalidSender")
        .withArgs(ethers.ZeroAddress);
    });
  });

  describe("_approve", function () {
    beforeEach(function () {
      this.approve = this.token.$_approve;
    });

    shouldBehaveLikeERC20Approve(initialSupply);

    it("reverts when the owner is the zero address", async function () {
      await expect(this.token.$_approve(ethers.ZeroAddress, this.recipient, initialSupply))
        .to.be.revertedWithCustomError(this.token, "ERC20InvalidApprover")
        .withArgs(ethers.ZeroAddress);
    });
  });
});
