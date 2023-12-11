const { expect } = require("chai");

const { ethers } = require("hardhat");
const { ETHER_STR } = require("../utils");
const { impersonate } = require("../utils");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

async function getTimeStamp(tx) {
  const rc = await ethers.provider.getTransactionReceipt(tx.hash);
  const block = await ethers.provider.getBlock(rc.blockNumber);
  return block.timestamp;
}

const {
  //   ZERO_BYTES32,
  //   ZERO_ADDRESS,
  deployWithProxy,
  expectEvent,
  //   expectRevert,
  expectCustomError,
} = require("./utils/helpers");

contract("gETH", function (accounts) {
  const name = "Geode Staked Ether";
  const symbol = "gETH";
  const uri = "https://token.com";
  const denominator = BigInt(ETHER_STR);

  const URI_SETTER_ROLE = web3.utils.soliditySha3("URI_SETTER_ROLE");
  const MINTER_ROLE = web3.utils.soliditySha3("MINTER_ROLE");
  const PAUSER_ROLE = web3.utils.soliditySha3("PAUSER_ROLE");
  const MIDDLEWARE_MANAGER_ROLE = web3.utils.soliditySha3("MIDDLEWARE_MANAGER_ROLE");
  const ORACLE_ROLE = web3.utils.soliditySha3("ORACLE_ROLE");

  const tokenId = BigInt("69");
  const price = BigInt("69420");

  const mintAmount = BigInt("420420");
  const transferAmount = BigInt("69");

  const fixture = async () => {
    const [deployer, user] = await ethers.getSigners();

    const token = await ethers.deployContract("$gETH", [name, symbol, uri]);

    const middleware = await deployWithProxy("$ERC20Middleware", [
      tokenId,
      token.target,
      ZERO_BYTES32,
    ]);

    const nonERC1155Receiver = await ethers.deployContract("$nonERC1155Receiver", [
      tokenId,
      token.target,
    ]);

    return { deployer, user, token, middleware, nonERC1155Receiver };
  };

  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture));
  });

  describe("Constructor", function () {
    it("sets name", async function () {
      expect(await this.token.name()).to.be.equal(name);
    });

    it("sets symbol", async function () {
      expect(await this.token.symbol()).to.be.equal(symbol);
    });

    it("grants MIDDLEWARE_MANAGER_ROLE", async function () {
      expect(await this.token.hasRole(MIDDLEWARE_MANAGER_ROLE, this.deployer)).to.be.equal(true);
    });

    it("grants ORACLE_ROLE", async function () {
      expect(await this.token.hasRole(ORACLE_ROLE, this.deployer)).to.be.equal(true);
    });
  });

  context("Denominator", function () {
    it("denominator is 1e18", async function () {
      expect(await this.token.denominator()).to.be.equal(denominator);
    });
  });

  context("Roles", function () {
    describe("reverts if transfer functions called with address without the role", function () {
      it("reverts transferUriSetterRole", async function () {
        await expectCustomError(
          this.token.connect(this.user).transferUriSetterRole(this.user),
          this.token,
          "AccessControlUnauthorizedAccount"
        );
      });

      it("reverts transferPauserRole", async function () {
        await expectCustomError(
          this.token.connect(this.user).transferPauserRole(this.user),
          this.token,
          "AccessControlUnauthorizedAccount"
        );
      });

      it("reverts transferMinterRole", async function () {
        await expectCustomError(
          this.token.connect(this.user).transferMinterRole(this.user),
          this.token,
          "AccessControlUnauthorizedAccount"
        );
      });

      it("reverts transferOracleRole", async function () {
        await expectCustomError(
          this.token.connect(this.user).transferOracleRole(this.user),
          this.token,
          "AccessControlUnauthorizedAccount"
        );
      });

      it("reverts transferMiddlewareManagerRole", async function () {
        await expectCustomError(
          this.token.connect(this.user).transferMiddlewareManagerRole(this.user),
          this.token,
          "AccessControlUnauthorizedAccount"
        );
      });
    });

    describe("transferUriSetterRole", function () {
      beforeEach(async function () {
        await this.token.transferUriSetterRole(this.user);
      });

      it("sets new UriSetter", async function () {
        expect(await this.token.hasRole(URI_SETTER_ROLE, this.user)).to.be.equal(true);
      });

      it("removes oldUriSetter", async function () {
        expect(await this.token.hasRole(URI_SETTER_ROLE, this.deployer)).to.be.equal(false);
      });
    });

    describe("transferPauserRole", function () {
      beforeEach(async function () {
        await this.token.transferPauserRole(this.user);
      });

      it("sets new Pauser", async function () {
        expect(await this.token.hasRole(PAUSER_ROLE, this.user)).to.be.equal(true);
      });

      it("removes oldPauser", async function () {
        expect(await this.token.hasRole(PAUSER_ROLE, this.deployer)).to.be.equal(false);
      });
    });

    describe("transferMinterRole", function () {
      beforeEach(async function () {
        await this.token.transferMinterRole(this.user);
      });

      it("sets new Minter", async function () {
        expect(await this.token.hasRole(MINTER_ROLE, this.user)).to.be.equal(true);
      });

      it("removes oldMinter", async function () {
        expect(await this.token.hasRole(MINTER_ROLE, this.deployer)).to.be.equal(false);
      });
    });

    describe("transferOracleRole", function () {
      beforeEach(async function () {
        await this.token.transferOracleRole(this.user);
      });

      it("sets new Oracle", async function () {
        expect(await this.token.hasRole(ORACLE_ROLE, this.user)).to.be.equal(true);
      });

      it("removes oldOracle", async function () {
        expect(await this.token.hasRole(ORACLE_ROLE, this.deployer)).to.be.equal(false);
      });
    });

    describe("transferMiddlewareManagerRole", function () {
      beforeEach(async function () {
        await this.token.transferMiddlewareManagerRole(this.user);
      });

      it("sets new MiddlewareManager", async function () {
        expect(await this.token.hasRole(MIDDLEWARE_MANAGER_ROLE, this.user)).to.be.equal(true);
      });

      it("removes oldMiddlewareManager", async function () {
        expect(await this.token.hasRole(MIDDLEWARE_MANAGER_ROLE, this.deployer)).to.be.equal(false);
      });
    });
  });

  context("Price", function () {
    describe("_setPricePerShare", function () {
      let updateTime;
      beforeEach(async function () {
        const tx = await this.token.$_setPricePerShare(price, tokenId);
        updateTime = await getTimeStamp(tx);
      });

      it("updates pricePerShare", async function () {
        expect(await this.token.pricePerShare(tokenId)).to.be.equal(price);
      });

      it("updates priceUpdateTimestamp", async function () {
        expect(await this.token.priceUpdateTimestamp(tokenId)).to.be.equal(updateTime);
      });
    });

    describe("setPricePerShare", function () {
      it("reverts for zero ID", async function () {
        await expectCustomError(
          this.token.setPricePerShare(price, ZERO_BYTES32),
          this.token,
          "gETHZeroId"
        );
      });

      it("emits PriceUpdated", async function () {
        const receipt = await this.token.setPricePerShare(price, tokenId);
        const updateTime = await getTimeStamp(receipt);

        await expectEvent(receipt, this.token, "PriceUpdated", [tokenId, price, updateTime]);
      });
    });
  });

  context("Middlewares", function () {
    describe("_setMiddleware", async function () {
      it("sets as a middleware", async function () {
        await this.token
          .connect(this.deployer)
          .$_setMiddleware(this.middleware.target, tokenId, true);
        expect(await this.token.isMiddleware(this.middleware.target, tokenId)).to.be.equal(true);
      });
    });

    describe("setMiddleware", async function () {
      it("reverts for zero address", async function () {
        await expectCustomError(
          this.token.setMiddleware(ZERO_ADDRESS, tokenId, true),
          this.token,
          "gETHInvalidMiddleware"
        );
      });

      it("reverts if not a contract", async function () {
        await expectCustomError(
          this.token.setMiddleware(this.user, tokenId, true),
          this.token,
          "gETHInvalidMiddleware"
        );
      });

      it("emits MiddlewareSet", async function () {
        await expectEvent(
          await this.token.setMiddleware(this.middleware.target, tokenId, true),
          this.token,
          "MiddlewareSet",
          [tokenId, this.middleware.target, true]
        );
      });
    });
  });

  context("Avoiders", function () {
    describe("avoidMiddlewares", async function () {
      let receipt;
      beforeEach(async function () {
        receipt = await this.token.connect(this.user).avoidMiddlewares(tokenId, true);
      });

      it("sets address as avoider", async function () {
        expect(await this.token.isAvoider(this.user, tokenId)).to.be.equal(true);
      });

      it("emits Avoider", async function () {
        expectEvent(receipt, this.token, "Avoider", [this.user, tokenId, true]);
      });

      describe("can not touch avoider", async function () {
        let middlewareSigner;
        beforeEach(async function () {
          await this.token.$_mint(this.user, tokenId, mintAmount, "0x");
          await this.token.connect(this.user).avoidMiddlewares(tokenId, true);
          await this.token
            .connect(this.deployer)
            .setMiddleware(this.middleware.target, tokenId, true);
          middlewareSigner = await impersonate(this.middleware.target, ETHER_STR);
        });

        it("safeTransferFrom", async function () {
          await expectCustomError(
            this.token
              .connect(middlewareSigner)
              .safeTransferFrom(this.user, this.deployer, tokenId, transferAmount, "0x"),
            this.token,
            "ERC1155MissingApprovalForAll"
          );
        });

        it("burn", async function () {
          await expectCustomError(
            this.token.connect(this.middleware).burn(this.user, tokenId, transferAmount),
            this.token,
            "ERC1155MissingApprovalForAll"
          );
        });

        it("can transfer to non-Erc155Holder, if approved", async function () {
          await this.token.connect(this.user).setApprovalForAll(this.middleware.target, true);
          await this.token
            .connect(middlewareSigner)
            .safeTransferFrom(
              this.user,
              this.nonERC1155Receiver.target,
              tokenId,
              transferAmount,
              "0x"
            );
        });
      });
    });
  });
});
