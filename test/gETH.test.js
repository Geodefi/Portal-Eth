const { expect } = require("chai");

const { expectRevert, expectEvent, constants, BN } = require("@openzeppelin/test-helpers");
const { etherStr, getReceiptTimestamp, impersonate } = require("./utils/utils");
const { shouldBehaveLikeERC1155 } = require("./utils/ERC1155.behavior");

const { ZERO_BYTES32, ZERO_ADDRESS } = constants;

const gETH = artifacts.require("$gETH");
const ERC20Middleware = artifacts.require("$ERC20Middleware");
const nonERC1155Receiver = artifacts.require("$nonERC1155Receiver");

contract("gETH", function (accounts) {
  const [deployer, user, ...otherAccounts] = accounts;

  const name = "Geode Staked Ether";
  const symbol = "gETH";
  const uri = "https://token.com";
  const denominator = new BN(etherStr);

  const URI_SETTER_ROLE = web3.utils.soliditySha3("URI_SETTER_ROLE");
  const MINTER_ROLE = web3.utils.soliditySha3("MINTER_ROLE");
  const PAUSER_ROLE = web3.utils.soliditySha3("PAUSER_ROLE");
  const MIDDLEWARE_MANAGER_ROLE = web3.utils.soliditySha3("MIDDLEWARE_MANAGER_ROLE");
  const ORACLE_ROLE = web3.utils.soliditySha3("ORACLE_ROLE");

  const tokenId = new BN("69");
  const price = new BN("69420");

  const mintAmount = new BN("420420");
  const transferAmount = new BN("69");

  let middleware;
  let nonReceiver;

  beforeEach(async function () {
    this.token = await gETH.new(name, symbol, uri, { from: deployer });
  });

  shouldBehaveLikeERC1155(otherAccounts);

  describe("Constructor", function () {
    it("sets name", async function () {
      expect(await this.token.name()).to.be.equal(name);
    });

    it("sets symbol", async function () {
      expect(await this.token.symbol()).to.be.equal(symbol);
    });

    it("grants MIDDLEWARE_MANAGER_ROLE", async function () {
      expect(await this.token.hasRole(MIDDLEWARE_MANAGER_ROLE, deployer)).to.equal(true);
    });

    it("grants ORACLE_ROLE", async function () {
      expect(await this.token.hasRole(ORACLE_ROLE, deployer)).to.equal(true);
    });
  });

  context("Denominator", function () {
    it("denominator is 1e18", async function () {
      expect(await this.token.denominator()).to.be.bignumber.equal(denominator);
    });
  });

  context("Middlewares", function () {
    beforeEach(async function () {
      middleware = await ERC20Middleware.new({
        from: deployer,
      });
      middleware.initialize(tokenId, this.token.address, ZERO_BYTES32);

      nonReceiver = await nonERC1155Receiver.new(tokenId, this.token.address, {
        from: deployer,
      });
    });

    describe("_setMiddleware", async function () {
      it("sets as a middleware", async function () {
        await this.token.$_setMiddleware(middleware.address, tokenId, { from: deployer });
        expect(await this.token.isMiddleware(middleware.address, tokenId)).to.be.equal(true);
      });
    });

    describe("setMiddleware", async function () {
      it("reverts for zero address", async function () {
        expectRevert(
          this.token.setMiddleware(ZERO_ADDRESS, tokenId, { from: deployer }),
          "gETH:middleware query for the zero address"
        );
      });

      it("reverts if not a contract", async function () {
        expectRevert(
          this.token.setMiddleware(user, tokenId, { from: deployer }),
          "gETH:middleware must be a contract"
        );
      });

      it("emits MiddlewareSet", async function () {
        expectEvent(
          await this.token.setMiddleware(middleware.address, tokenId, { from: deployer }),
          "MiddlewareSet",
          { id: tokenId, middleware: middleware.address, isSet: true }
        );
      });
    });

    context("can transfer without approval", function () {
      beforeEach(async function () {
        await this.token.$_mint(user, tokenId, mintAmount, "0x");
        await this.token.setMiddleware(middleware.address, tokenId, { from: deployer });
        await impersonate(middleware.address, etherStr);
      });

      it("safeTransferFrom", async function () {
        await this.token.safeTransferFrom(user, deployer, tokenId, transferAmount, "0x", {
          from: middleware.address,
        });
        expect(await this.token.balanceOf(user, tokenId)).to.be.bignumber.equal(
          mintAmount.sub(transferAmount)
        );
        expect(await this.token.balanceOf(deployer, tokenId)).to.be.bignumber.equal(transferAmount);
      });

      it("burn", async function () {
        await this.token.burn(user, tokenId, transferAmount, {
          from: middleware.address,
        });
        expect(await this.token.balanceOf(user, tokenId)).to.be.bignumber.equal(
          mintAmount.sub(transferAmount)
        );
      });

      it("can transfer to non-Erc155Holder contract", async function () {
        await this.token.safeTransferFrom(
          user,
          nonReceiver.address,
          tokenId,
          transferAmount,
          "0x",
          {
            from: middleware.address,
          }
        );
        expect(await this.token.balanceOf(user, tokenId)).to.be.bignumber.equal(
          mintAmount.sub(transferAmount)
        );
        expect(await this.token.balanceOf(nonReceiver.address, tokenId)).to.be.bignumber.equal(
          transferAmount
        );
      });
    });
  });

  context("Avoiders", function () {
    describe("avoidMiddlewares", async function () {
      let receipt;

      beforeEach(async function () {
        receipt = await this.token.avoidMiddlewares(tokenId, true, { from: user });
      });

      it("sets address as avoider", async function () {
        expect(await this.token.isAvoider(user, tokenId)).to.be.equal(true);
      });

      it("emits Avoider", async function () {
        expectEvent(receipt, "Avoider", { avoider: user, id: tokenId, isAvoid: true });
      });

      context("can not touch avoider", function () {
        beforeEach(async function () {
          await this.token.$_mint(user, tokenId, mintAmount, "0x");
          await this.token.avoidMiddlewares(tokenId, true, { from: user });
          await this.token.setMiddleware(middleware.address, tokenId, { from: deployer });
          await impersonate(middleware.address, etherStr);
        });

        describe("safeTransferFrom", async function () {
          await expectRevert(
            this.token.safeTransferFrom(user, deployer, tokenId, transferAmount, "0x", {
              from: middleware.address,
            }),
            "ERC1155: caller is not token owner or approved"
          );
        });

        describe("burn", async function () {
          await expectRevert(
            this.token.burn(user, tokenId, transferAmount, {
              from: middleware.address,
            }),
            "ERC1155: caller is not token owner or approved"
          );
        });

        it("can transfer to non-Erc155Holder, if approved", async function () {
          await this.token.setApprovalForAll(middleware.address, true, { from: user });
          await this.token.safeTransferFrom(
            user,
            nonReceiver.address,
            tokenId,
            transferAmount,
            "0x",
            {
              from: middleware.address,
            }
          );
        });
      });
    });
  });

  context("Price", function () {
    describe("_setPricePerShare", function () {
      let updateTime;
      beforeEach(async function () {
        updateTime = await getReceiptTimestamp(
          await this.token.$_setPricePerShare(price, tokenId, { from: deployer })
        );
      });

      it("updates pricePerShare", async function () {
        expect(await this.token.pricePerShare(tokenId)).to.be.bignumber.equal(price);
      });

      it("updates priceUpdateTimestamp", async function () {
        expect(await this.token.priceUpdateTimestamp(tokenId)).to.be.bignumber.equal(updateTime);
      });
    });

    describe("setPricePerShare", function () {
      it("reverts for zero address", async function () {
        expectRevert(
          this.token.setPricePerShare(price, ZERO_BYTES32, { from: deployer }),
          "gETH:price query for the zero address"
        );
      });

      it("emits PriceUpdated", async function () {
        const receipt = await this.token.setPricePerShare(price, tokenId, { from: deployer });
        const updateTime = await getReceiptTimestamp(receipt);

        expectEvent(receipt, "PriceUpdated", {
          id: tokenId,
          pricePerShare: price,
          updateTimestamp: updateTime,
        });
      });
    });
  });

  context("Roles", function () {
    describe("transferUriSetterRole", function () {
      beforeEach(async function () {
        await this.token.transferUriSetterRole(user, { from: deployer });
      });

      it("sets new UriSetter", async function () {
        expect(await this.token.hasRole(URI_SETTER_ROLE, user)).to.be.equal(true);
      });

      it("removes oldUriSetter", async function () {
        expect(await this.token.hasRole(URI_SETTER_ROLE, deployer)).to.be.equal(false);
      });
    });

    describe("transferPauserRole", function () {
      beforeEach(async function () {
        await this.token.transferPauserRole(user, { from: deployer });
      });

      it("sets new Pauser", async function () {
        expect(await this.token.hasRole(PAUSER_ROLE, user)).to.be.equal(true);
      });

      it("removes oldPauser", async function () {
        expect(await this.token.hasRole(PAUSER_ROLE, deployer)).to.be.equal(false);
      });
    });

    describe("transferMinterRole", function () {
      beforeEach(async function () {
        await this.token.transferMinterRole(user, { from: deployer });
      });

      it("sets new Minter", async function () {
        expect(await this.token.hasRole(MINTER_ROLE, user)).to.be.equal(true);
      });

      it("removes oldMinter", async function () {
        expect(await this.token.hasRole(MINTER_ROLE, deployer)).to.be.equal(false);
      });
    });

    describe("transferOracleRole", function () {
      beforeEach(async function () {
        await this.token.transferOracleRole(user, { from: deployer });
      });

      it("sets new Oracle", async function () {
        expect(await this.token.hasRole(ORACLE_ROLE, user)).to.be.equal(true);
      });

      it("removes oldOracle", async function () {
        expect(await this.token.hasRole(ORACLE_ROLE, deployer)).to.be.equal(false);
      });
    });

    describe("transferMiddlewareManagerRole", function () {
      beforeEach(async function () {
        await this.token.transferMiddlewareManagerRole(user, { from: deployer });
      });

      it("sets new MiddlewareManager", async function () {
        expect(await this.token.hasRole(MIDDLEWARE_MANAGER_ROLE, user)).to.be.equal(true);
      });

      it("removes oldMiddlewareManager", async function () {
        expect(await this.token.hasRole(MIDDLEWARE_MANAGER_ROLE, deployer)).to.be.equal(false);
      });
    });
  });
});
