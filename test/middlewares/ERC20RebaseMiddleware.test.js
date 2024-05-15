/* eslint-disable camelcase */
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

contract("ERC20RebaseMiddleware", function () {
  const name = "Test Staked Ether";
  const symbol = "tsETH";
  const tokenId = BigInt(420);
  const price = BigInt(2e18);
  const initialSupply = 100n * BigInt(1e18);
  const initialRebasedSupply = 100n * BigInt(2e18);

  const nameBytes = strToBytes(name).substr(2);
  const symbolBytes = strToBytes(symbol).substr(2);
  const middlewareData = intToBytes32(nameBytes.length / 2) + nameBytes + symbolBytes;

  const fixture = async () => {
    await silenceWarnings();

    const [initialHolder, recipient, anotherAccount] = await ethers.getSigners();

    const gETH = await ethers.deployContract("gETH", ["name", "symbol", "uri"]);

    const token = await deployWithProxy("$ERC20RebaseMiddleware", [
      tokenId,
      gETH.target,
      middlewareData,
    ]);

    await gETH.setMiddleware(token.target, tokenId, true);
    await gETH.setPricePerShare(price, tokenId);
    await gETH.mint(initialHolder, tokenId, initialSupply, "0x");

    return { initialHolder, recipient, anotherAccount, token, gETH };
  };

  beforeEach(async function () {
    await silenceWarnings();
    Object.assign(this, await loadFixture(fixture));
    this.approve = (owner, spender, value) => this.token.connect(owner).approve(spender, value);
  });

  shouldBehaveLikeERC20(initialRebasedSupply);

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

    shouldBehaveLikeERC20Transfer(initialRebasedSupply);

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

    shouldBehaveLikeERC20Approve(initialRebasedSupply);

    it("reverts when the owner is the zero address", async function () {
      await expect(this.token.$_approve(ethers.ZeroAddress, this.recipient, initialSupply))
        .to.be.revertedWithCustomError(this.token, "ERC20InvalidApprover")
        .withArgs(ethers.ZeroAddress);
    });
  });

  describe("price change", function () {
    it("transfers correctly before and after price change", async function () {
      const beforeBalanceOwner = await this.token.balanceOf(this.initialHolder);
      const beforeBalanceReceiver = await this.token.balanceOf(this.anotherAccount);
      await this.token.transfer(this.anotherAccount, BigInt(1e9));

      const afterBalanceOwner = await this.token.balanceOf(this.initialHolder);
      const afterBalanceReceiver = await this.token.balanceOf(this.anotherAccount);

      expect(afterBalanceOwner).to.be.equal(beforeBalanceOwner - BigInt(1e9));
      expect(afterBalanceReceiver).to.be.equal(BigInt(1e9));

      await this.gETH.setPricePerShare(price * 4n, tokenId); // setting price to 8, initally it was 2

      const afterPPS_beforeBalanceOwner = await this.token.balanceOf(this.initialHolder);
      const afterPPS_beforeBalanceReceiver = await this.token.balanceOf(this.anotherAccount);

      expect(afterPPS_beforeBalanceOwner).to.be.equal(afterBalanceOwner * 4n);
      expect(afterPPS_beforeBalanceReceiver).to.be.equal(afterBalanceReceiver * 4n);

      await this.token.transfer(this.anotherAccount, BigInt(1e9));

      const afterPPS_afterBalanceOwner = await this.token.balanceOf(this.initialHolder);
      const afterPPS_afterBalanceReceiver = await this.token.balanceOf(this.anotherAccount);

      expect(afterPPS_afterBalanceOwner).to.be.equal(afterPPS_beforeBalanceOwner - BigInt(1e9));
      expect(afterPPS_afterBalanceReceiver).to.be.equal(
        afterPPS_beforeBalanceReceiver + BigInt(1e9)
      );

      await this.gETH.setPricePerShare(price * 2n, tokenId); // setting price to 4, it was set to 8 previously, and initially 2, so decreased

      const afterPPS_2_beforeBalanceOwner = await this.token.balanceOf(this.initialHolder);
      const afterPPS_2_beforeBalanceReceiver = await this.token.balanceOf(this.anotherAccount);

      expect(afterPPS_2_beforeBalanceOwner).to.be.equal(afterPPS_afterBalanceOwner / 2n);
      expect(afterPPS_2_beforeBalanceReceiver).to.be.equal(afterPPS_afterBalanceReceiver / 2n);

      console.log("mam");
      await this.token.transfer(this.anotherAccount, BigInt(1e9));

      const afterPPS_2_afterBalanceOwner = await this.token.balanceOf(this.initialHolder);
      const afterPPS_2_afterBalanceReceiver = await this.token.balanceOf(this.anotherAccount);

      expect(afterPPS_2_afterBalanceOwner).to.be.equal(afterPPS_2_beforeBalanceOwner - BigInt(1e9));
      expect(afterPPS_2_afterBalanceReceiver).to.be.equal(
        afterPPS_2_beforeBalanceReceiver + BigInt(1e9)
      );
    });
  });
});
