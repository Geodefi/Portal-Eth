const { expect } = require("chai");
const { BN, expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const { silenceWarnings } = require("@openzeppelin/upgrades-core");

const { strToBytes, intToBytes32 } = require("../utils");

const ERC20Middleware = artifacts.require("$ERC20Middleware");
const gETH = artifacts.require("gETH");

const { shouldBehaveLikeERC20 } = require("../utils/ERC20.behavior");
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");

contract("ERC20Middleware", function (accounts) {
  const [deployer, recipient, anotherAccount] = accounts;
  const name = "Test Staked Ether";
  const symbol = "tsETH";
  const tokenId = new BN(420);
  const price = new BN(String(1e18));
  const initialSupply = new BN(String(1e18)).muln(100);

  let factory;
  let middlewareData;

  const deployErc20WithProxy = async function () {
    const contract = await upgrades.deployProxy(
      factory,
      [tokenId.toString(), this.gETH.address, middlewareData],
      {
        unsafeAllow: ["state-variable-assignment"],
      }
    );
    await contract.waitForDeployment();
    return await ERC20Middleware.at(contract.target);
  };

  before(async function () {
    await silenceWarnings();

    factory = await ethers.getContractFactory("$ERC20Middleware");

    const nameBytes = strToBytes(name).substr(2);
    const symbolBytes = strToBytes(symbol).substr(2);
    middlewareData = intToBytes32(nameBytes.length / 2) + nameBytes + symbolBytes;

    this.deployErc20WithProxy = deployErc20WithProxy;
  });

  beforeEach(async function () {
    this.gETH = await gETH.new("name", "symbol", "uri", { from: deployer });
    await this.gETH.mint(deployer, tokenId, initialSupply, "0x", { from: deployer });

    this.token = await this.deployErc20WithProxy();
    await this.gETH.setMiddleware(this.token.address, tokenId, true);
    await this.gETH.setPricePerShare(price, tokenId);
  });

  shouldBehaveLikeERC20("ERC20", initialSupply, deployer, recipient, anotherAccount);

  describe("initialize", function () {
    it("correct gETH address", async function () {
      expect(await this.token.ERC1155()).to.be.equal(this.gETH.address);
    });
    it("correct token id", async function () {
      expect(await this.token.ERC1155_ID()).to.be.bignumber.equal(tokenId);
    });
    it("correct name", async function () {
      expect(await this.token.name()).to.be.equal(name);
    });
    it("correct symbol", async function () {
      expect(await this.token.symbol()).to.be.equal(symbol);
    });
    it("correct pricePerShare", async function () {
      expect(await this.token.pricePerShare()).to.be.bignumber.equal(price);
    });
    it("has 18 decimals", async function () {
      expect(await this.token.decimals()).to.be.bignumber.equal("18");
    });
  });

  describe("decrease allowance", function () {
    describe("when the spender is not the zero address", function () {
      const spender = recipient;

      function shouldDecreaseApproval(amount) {
        describe("when there was no approved amount before", function () {
          it("reverts", async function () {
            await expectRevert(
              this.token.decreaseAllowance(spender, amount, { from: deployer }),
              "ERC20: decreased allowance below zero"
            );
          });
        });

        describe("when the spender had an approved amount", function () {
          const approvedAmount = amount;

          beforeEach(async function () {
            await this.token.approve(spender, approvedAmount, { from: deployer });
          });

          it("emits an approval event", async function () {
            expectEvent(
              await this.token.decreaseAllowance(spender, approvedAmount, { from: deployer }),
              "Approval",
              { owner: deployer, spender: spender, value: new BN(0) }
            );
          });

          it("decreases the spender allowance subtracting the requested amount", async function () {
            await this.token.decreaseAllowance(spender, approvedAmount.subn(1), {
              from: deployer,
            });

            expect(await this.token.allowance(deployer, spender)).to.be.bignumber.equal("1");
          });

          it("sets the allowance to zero when all allowance is removed", async function () {
            await this.token.decreaseAllowance(spender, approvedAmount, { from: deployer });
            expect(await this.token.allowance(deployer, spender)).to.be.bignumber.equal("0");
          });

          it("reverts when more than the full allowance is removed", async function () {
            await expectRevert(
              this.token.decreaseAllowance(spender, approvedAmount.addn(1), {
                from: deployer,
              }),
              "ERC20: decreased allowance below zero"
            );
          });
        });
      }

      describe("when the sender has enough balance", function () {
        const amount = initialSupply;

        shouldDecreaseApproval(amount);
      });

      describe("when the sender does not have enough balance", function () {
        const amount = initialSupply.addn(1);

        shouldDecreaseApproval(amount);
      });
    });

    describe("when the spender is the zero address", function () {
      const amount = initialSupply;
      const spender = ZERO_ADDRESS;

      it("reverts", async function () {
        await expectRevert(
          this.token.decreaseAllowance(spender, amount, { from: deployer }),
          "ERC20: decreased allowance below zero"
        );
      });
    });
  });
  describe("increase allowance", function () {
    const amount = initialSupply;

    describe("when the spender is not the zero address", function () {
      const spender = recipient;

      describe("when the sender has enough balance", function () {
        it("emits an approval event", async function () {
          expectEvent(
            await this.token.increaseAllowance(spender, amount, { from: deployer }),
            "Approval",
            {
              owner: deployer,
              spender: spender,
              value: amount,
            }
          );
        });

        describe("when there was no approved amount before", function () {
          it("approves the requested amount", async function () {
            await this.token.increaseAllowance(spender, amount, { from: deployer });

            expect(await this.token.allowance(deployer, spender)).to.be.bignumber.equal(amount);
          });
        });

        describe("when the spender had an approved amount", function () {
          beforeEach(async function () {
            await this.token.approve(spender, new BN(1), { from: deployer });
          });

          it("increases the spender allowance adding the requested amount", async function () {
            await this.token.increaseAllowance(spender, amount, { from: deployer });

            expect(await this.token.allowance(deployer, spender)).to.be.bignumber.equal(
              amount.addn(1)
            );
          });
        });
      });

      describe("when the sender does not have enough balance", function () {
        const amount = initialSupply.addn(1);

        it("emits an approval event", async function () {
          expectEvent(
            await this.token.increaseAllowance(spender, amount, { from: deployer }),
            "Approval",
            {
              owner: deployer,
              spender: spender,
              value: amount,
            }
          );
        });

        describe("when there was no approved amount before", function () {
          it("approves the requested amount", async function () {
            await this.token.increaseAllowance(spender, amount, { from: deployer });

            expect(await this.token.allowance(deployer, spender)).to.be.bignumber.equal(amount);
          });
        });

        describe("when the spender had an approved amount", function () {
          beforeEach(async function () {
            await this.token.approve(spender, new BN(1), { from: deployer });
          });

          it("increases the spender allowance adding the requested amount", async function () {
            await this.token.increaseAllowance(spender, amount, { from: deployer });

            expect(await this.token.allowance(deployer, spender)).to.be.bignumber.equal(
              amount.addn(1)
            );
          });
        });
      });
    });

    describe("when the spender is the zero address", function () {
      const spender = ZERO_ADDRESS;

      it("reverts", async function () {
        await expectRevert(
          this.token.increaseAllowance(spender, amount, { from: deployer }),
          "ERC20: approve to the zero address"
        );
      });
    });
  });
});
