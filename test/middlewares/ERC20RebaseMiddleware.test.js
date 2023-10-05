const { expect } = require("chai");
const { BN, expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const { silenceWarnings } = require("@openzeppelin/upgrades-core");

const { strToBytes, intToBytes32 } = require("../utils");

const ERC20RebaseMiddleware = artifacts.require("$ERC20RebaseMiddleware");
const gETH = artifacts.require("gETH");

const { shouldBehaveLikeERC20 } = require("../utils/ERC20.behavior");
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");

contract("ERC20RebaseMiddleware", function (accounts) {
  const [deployer, recipient, anotherAccount] = accounts;
  const name = "Test Staked Ether";
  const symbol = "tsETH";
  const tokenId = new BN(420);
  const price = new BN(String(2e18));
  const initialSupply = new BN(String(1e18)).muln(100);
  const initialRebasedSupply = new BN(String(2e18)).muln(100);

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
    return await ERC20RebaseMiddleware.at(contract.target);
  };

  before(async function () {
    await silenceWarnings();

    factory = await ethers.getContractFactory("$ERC20RebaseMiddleware");

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

  shouldBehaveLikeERC20("ERC20R", initialRebasedSupply, deployer, recipient, anotherAccount);

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
              "ERC20R: decreased allowance below zero"
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
              "ERC20R: decreased allowance below zero"
            );
          });
        });
      }

      describe("when the sender has enough balance", function () {
        const amount = initialRebasedSupply;

        shouldDecreaseApproval(amount);
      });

      describe("when the sender does not have enough balance", function () {
        const amount = initialRebasedSupply.addn(1);

        shouldDecreaseApproval(amount);
      });
    });

    describe("when the spender is the zero address", function () {
      const amount = initialRebasedSupply;
      const spender = ZERO_ADDRESS;

      it("reverts", async function () {
        await expectRevert(
          this.token.decreaseAllowance(spender, amount, { from: deployer }),
          "ERC20R: decreased allowance below zero"
        );
      });
    });
  });
  describe("increase allowance", function () {
    const amount = initialRebasedSupply;

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
        const amount = initialRebasedSupply.addn(1);

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
          "ERC20R: approve to the zero address"
        );
      });
    });
  });

  describe("price change", function () {
    it("transfers correctly before and after price change", async function () {
      const beforeBalanceOwner = await this.token.balanceOf(deployer);
      const beforeBalanceReceiver = await this.token.balanceOf(anotherAccount);

      await this.token.transfer(anotherAccount, 1e9, { from: deployer });

      const afterBalanceOwner = await this.token.balanceOf(deployer);
      const afterBalanceReceiver = await this.token.balanceOf(anotherAccount);

      expect(afterBalanceOwner).to.be.bignumber.eq(beforeBalanceOwner.sub(new BN(1e9)));
      expect(afterBalanceReceiver).to.be.bignumber.eq(new BN(1e9));

      await this.gETH.setPricePerShare(price.muln(4), tokenId); // setting price to 8, initally it was 2

      const afterPPS_beforeBalanceOwner = await this.token.balanceOf(deployer);
      const afterPPS_beforeBalanceReceiver = await this.token.balanceOf(anotherAccount);

      expect(afterPPS_beforeBalanceOwner).to.be.bignumber.eq(afterBalanceOwner.muln(4));
      expect(afterPPS_beforeBalanceReceiver).to.be.bignumber.eq(afterBalanceReceiver.muln(4));

      await this.token.transfer(anotherAccount, 1e9, { from: deployer });

      const afterPPS_afterBalanceOwner = await this.token.balanceOf(deployer);
      const afterPPS_afterBalanceReceiver = await this.token.balanceOf(anotherAccount);

      expect(afterPPS_afterBalanceOwner).to.be.bignumber.eq(
        afterPPS_beforeBalanceOwner.sub(new BN(1e9))
      );
      expect(afterPPS_afterBalanceReceiver).to.be.bignumber.eq(
        afterPPS_beforeBalanceReceiver.add(new BN(1e9))
      );

      await this.gETH.setPricePerShare(price.muln(2), tokenId); // setting price to 4, it was set 8 previously and initially 2, so decreased

      const afterPPS_2_beforeBalanceOwner = await this.token.balanceOf(deployer);
      const afterPPS_2_beforeBalanceReceiver = await this.token.balanceOf(anotherAccount);

      expect(afterPPS_2_beforeBalanceOwner).to.be.bignumber.eq(afterPPS_afterBalanceOwner.divn(2));
      expect(afterPPS_2_beforeBalanceReceiver).to.be.bignumber.eq(
        afterPPS_afterBalanceReceiver.divn(2)
      );

      await this.token.transfer(anotherAccount, 1e9, { from: deployer });

      const afterPPS_2_afterBalanceOwner = await this.token.balanceOf(deployer);
      const afterPPS_2_afterBalanceReceiver = await this.token.balanceOf(anotherAccount);

      expect(afterPPS_2_afterBalanceOwner).to.be.bignumber.eq(
        afterPPS_2_beforeBalanceOwner.sub(new BN(1e9))
      );
      expect(afterPPS_2_afterBalanceReceiver).to.be.bignumber.eq(
        afterPPS_2_beforeBalanceReceiver.add(new BN(1e9))
      );
    });
  });
});
