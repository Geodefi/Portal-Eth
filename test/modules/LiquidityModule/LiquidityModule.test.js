const { expect } = require("chai");
const { expectRevert, constants, BN, balance } = require("@openzeppelin/test-helpers");
const { expectEvent, expectCustomError } = require("../../utils/helpers");

const {
  getBlockTimestamp,
  forceAdvanceOneBlock,
  setTimestamp,
  PERCENTAGE_DENOMINATOR,
  ETHER_STR,
  DAY,
} = require("../../../utils");

const { ZERO_ADDRESS, MAX_UINT256, ZERO_BYTES32 } = constants;

const gETH = artifacts.require("gETH");
const LPToken = artifacts.require("LPToken");
const LML = artifacts.require("LiquidityModuleLib");
const $LML = artifacts.require("$LiquidityModuleLib");
const LiquidityModuleMock = artifacts.require("$LiquidityModuleMock");

contract("LiquidityModule", function (accounts) {
  const [deployer, user1, user2] = accounts;

  const tokenId = new BN("420");
  const INITIAL_A_VALUE = new BN("60");
  const SWAP_FEE = PERCENTAGE_DENOMINATOR.divn(10000).muln(4); // 4bps
  const MAX_ADMIN_FEE = PERCENTAGE_DENOMINATOR.divn(2); // 50%
  const MAX_SWAP_FEE = PERCENTAGE_DENOMINATOR.divn(100); // 1%
  const poolName = "MY POOL";

  const getLP = async function (address) {
    return await LPToken.at(address);
  };

  before(async function () {
    this.gETH = await gETH.new("name", "symbol", "uri", { from: deployer });

    this.lpTokenImp = (await LPToken.new({ from: deployer })).address;

    const library = await LML.new({ from: deployer });

    await LiquidityModuleMock.link(library);
    await $LML.link(library);

    this.library = await $LML.new({ from: deployer });
  });

  beforeEach(async function () {
    this.contract = await LiquidityModuleMock.new({ from: deployer });
  });

  context("library", function () {
    context("internal helpers", function () {
      describe("within1", function () {
        it("Returns true when a > b and a - b <= 1", async function () {
          expect(await this.library.$within1(2, 1)).to.be.equal(true);
        });

        it("Returns false when a > b and a - b > 1", async function () {
          expect(await this.library.$within1(3, 1)).to.be.equal(false);
        });

        it("Returns true when a <= b and b - a <= 1", async function () {
          expect(await this.library.$within1(1, 2)).to.be.equal(true);
        });

        it("Returns false when a <= b and b - a > 1", async function () {
          expect(await this.library.$within1(1, 3)).to.be.equal(false);
        });

        it("Reverts during an integer overflow", async function () {
          await expectRevert(this.library.$within1(MAX_UINT256, -1), "out-of-bounds");
        });
      });

      describe("difference", function () {
        it("Returns correct difference when a > b", async function () {
          expect(await this.library.$difference(3, 1)).to.be.bignumber.equal("2");
        });

        it("Returns correct difference when a <= b", async function () {
          expect(await this.library.$difference(1, 3)).to.be.bignumber.equal("2");
        });

        it("Reverts during an integer overflow", async function () {
          await expectRevert(this.library.$difference(-1, MAX_UINT256), "out-of-bounds");
        });
      });
    });
  });

  describe("__LiquidityModule_init", function () {
    it("reverts if _gETH_position is zero", async function () {
      await expectRevert(
        this.contract.initialize(
          ZERO_ADDRESS,
          this.lpTokenImp,
          tokenId,
          INITIAL_A_VALUE,
          SWAP_FEE,
          poolName
        ),
        "LM:_gETH_position can not be zero"
      );
    });
    it("reverts if _lpToken_referance is zero", async function () {
      await expectRevert(
        this.contract.initialize(
          this.gETH.address,
          ZERO_ADDRESS,
          tokenId,
          INITIAL_A_VALUE,
          SWAP_FEE,
          poolName
        ),
        "LM:_lpToken_referance can not be zero"
      );
    });
    it("reverts if _pooledTokenId is zero", async function () {
      await expectRevert(
        this.contract.initialize(
          this.gETH.address,
          this.lpTokenImp,
          0,
          INITIAL_A_VALUE,
          SWAP_FEE,
          poolName
        ),
        "LM:_pooledTokenId can not be zero"
      );
    });
    it("reverts if _initialA is zero", async function () {
      await expectRevert(
        this.contract.initialize(
          this.gETH.address,
          this.lpTokenImp,
          tokenId,
          0,
          SWAP_FEE,
          poolName
        ),
        "LM:_A can not be zero"
      );
    });
    it("reverts if _initialA exceeds maximum", async function () {
      await expectRevert(
        this.contract.initialize(
          this.gETH.address,
          this.lpTokenImp,
          tokenId,
          MAX_UINT256,
          SWAP_FEE,
          poolName
        ),
        "LM:_A exceeds maximum"
      );
    });
    it("reverts if _swapFee exceeds maximum", async function () {
      await expectRevert(
        this.contract.initialize(
          this.gETH.address,
          this.lpTokenImp,
          tokenId,
          INITIAL_A_VALUE,
          MAX_UINT256,
          poolName
        ),
        "LM:_swapFee exceeds maximum"
      );
    });
    describe("success", function () {
      let params;

      beforeEach(async function () {
        await this.contract.initialize(
          this.gETH.address,
          this.lpTokenImp,
          tokenId,
          INITIAL_A_VALUE,
          SWAP_FEE,
          poolName
        );
        params = await this.contract.LiquidityParams();
      });

      it("correct gETH", async function () {
        expect(params.gETH).to.be.equal(this.gETH.address);
      });
      it("correct pooledTokenId", async function () {
        expect(params.pooledTokenId).to.be.bignumber.equal(tokenId);
      });
      it("correct initialA", async function () {
        expect(params.initialA).to.be.bignumber.equal(INITIAL_A_VALUE.muln(100));
      });
      it("correct futureA", async function () {
        expect(params.futureA).to.be.bignumber.equal(INITIAL_A_VALUE.muln(100));
      });
      it("correct swapFee", async function () {
        expect(params.swapFee).to.be.bignumber.equal(SWAP_FEE);
      });
      it("correct LP token name", async function () {
        const lpToken = await getLP(params.lpToken);
        expect(await lpToken.name()).to.be.equal("Geode LP Token: " + poolName);
      });
      it("correct LP token symbol", async function () {
        const lpToken = await getLP(params.lpToken);
        expect(await lpToken.symbol()).to.be.equal(poolName + "-LP");
      });
      it("avoids middlewares", async function () {
        expect(await this.gETH.isAvoider(this.contract.address, tokenId)).to.be.equal(true);
      });
    });
  });

  context("contract", function () {
    const initBalances = [String(1e20), String(1e20)]; // 100 eth,100 gETH

    const initDeposit = [String(1e18), String(1e18)]; // 10 eth, e0 gETH
    beforeEach(async function () {
      await this.contract.initialize(
        this.gETH.address,
        this.lpTokenImp,
        tokenId,
        INITIAL_A_VALUE,
        SWAP_FEE,
        poolName
      );
      this.contract.setAdminFee(new BN("0"));

      this.lpToken = await getLP((await this.contract.LiquidityParams()).lpToken);
      await this.gETH.setPricePerShare(ETHER_STR, tokenId);

      for (const account of [deployer, user1, user2]) {
        await this.gETH.mint(account, tokenId, initBalances[0], "0x", { from: deployer });
        await this.gETH.setApprovalForAll(this.contract.address, true, { from: account });
        await this.lpToken.approve(this.contract.address, MAX_UINT256.toString(), {
          from: account,
        });
      }

      await this.gETH.mint(deployer, tokenId, initDeposit[1], ZERO_BYTES32, {
        from: deployer,
      });
      await this.contract.addLiquidity(initDeposit, 0, MAX_UINT256, {
        from: deployer,
        value: initDeposit[0],
      });
    });

    context("getters", function () {
      describe("A", async function () {
        it("Returns correct A value", async function () {
          expect(await this.contract.getA()).to.be.bignumber.equal(INITIAL_A_VALUE);
          expect(await this.contract.getAPrecise()).to.be.bignumber.equal(
            INITIAL_A_VALUE.muln(100)
          );
        });
      });
      describe("getBalance", function () {
        it("Reverts when index is out of range", async function () {
          await expectRevert(this.contract.getBalance(2), "out-of-bounds");
        });
        it("Returns correct balances of pooled tokens", async function () {
          expect(await this.contract.getBalance(0)).to.be.bignumber.equal(initDeposit[0]);
          expect(await this.contract.getBalance(1)).to.be.bignumber.equal(initDeposit[1]);
        });
      });
      describe("getAdminBalance", function () {
        it("Reverts with 'Token index out of range'", async function () {
          await expectRevert(this.contract.getAdminBalance(2), "LML:Token index out of range");
        });
        it("Is always 0 when adminFee is set to 0", async function () {
          expect(await this.contract.getAdminBalance(0)).to.be.bignumber.equal("0");
          expect(await this.contract.getAdminBalance(1)).to.be.bignumber.equal("0");
          await this.contract.swap(0, 1, String(1e17), 0, MAX_UINT256, {
            value: ethers.parseEther("0.1").toString(),
            from: user1,
          });
          expect(await this.contract.getAdminBalance(0)).to.be.bignumber.equal("0");
          expect(await this.contract.getAdminBalance(1)).to.be.bignumber.equal("0");
        });
        it("Returns expected amounts when adminFee is > 0", async function () {
          // Sets adminFee to 1% of the swap fees
          await this.contract.setAdminFee(MAX_SWAP_FEE);
          await this.contract.swap(0, 1, String(1e17), 0, MAX_UINT256, {
            value: ethers.parseEther("0.1").toString(),
            from: user1,
          });
          expect(await this.contract.getAdminBalance(0)).to.be.bignumber.equal(new BN("0"));
          expect(await this.contract.getAdminBalance(1)).to.be.bignumber.equal("399338962149");
          // After the first swap, the pool becomes imbalanced; there are more 1st token than 2nd token in the pool.
          // Therefore swapping from 2nd -> 1st will result in more 1st token returned
          // Also results in higher fees collected on the second swap.
          await this.contract.swap(1, 0, String(1e17), 0, MAX_UINT256, {
            from: user1,
          });
          expect(await this.contract.getAdminBalance(0)).to.be.bignumber.equal("400660758190");
          expect(await this.contract.getAdminBalance(1)).to.be.bignumber.equal("399338962149");
        });
      });
      describe("getVirtualPrice", function () {
        it("Returns zero if no LP", async function () {
          const lpTokenBalance = await this.lpToken.balanceOf(deployer);

          await this.contract.removeLiquidity(lpTokenBalance, [0, 0], MAX_UINT256, {
            from: deployer,
          });
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(new BN("0"));
        });
        it("Returns expected value after initial deposit", async function () {
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(String(1e18));
        });
        it("Returns expected values after swaps", async function () {
          // With each swap, virtual price will increase due to the fees
          await this.contract.swap(0, 1, String(1e17), 0, MAX_UINT256, {
            value: ethers.parseEther("0.1").toString(),
            from: user1,
          });
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000020001975421763"
          );
          await this.contract.swap(1, 0, String(1e17), 0, MAX_UINT256, { from: user1 });
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000040035070723434"
          );
        });
        it("Returns expected values after imbalanced withdrawal", async function () {
          await this.contract.addLiquidity([String(1e18), String(1e18)], 0, MAX_UINT256, {
            value: ethers.parseEther("1").toString(),
            from: user1,
          });
          await this.contract.addLiquidity([String(1e18), String(1e18)], 0, MAX_UINT256, {
            value: ethers.parseEther("1").toString(),
            from: user2,
          });
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(String(1e18));
          await this.contract.removeLiquidityImbalance(
            [String(1e18), 0],
            String(2e18),
            MAX_UINT256,
            {
              from: user1,
            }
          );
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000040029773424026"
          );
          await this.contract.removeLiquidityImbalance(
            [0, String(1e18)],
            String(2e18),
            MAX_UINT256,
            {
              from: user2,
            }
          );
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000080046628378343"
          );
        });
        it("Value is unchanged after balanced deposits", async function () {
          // pool is 1:1:1 ratio
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(String(1e18));
          await this.contract.addLiquidity([String(1e18), String(1e18)], 0, MAX_UINT256, {
            value: ethers.parseEther("1").toString(),
            from: user1,
          });
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(String(1e18));
          // pool changes to 1:2:1 ratio, thus changing the virtual price
          await this.contract.addLiquidity([String(2e18), String(0)], 0, MAX_UINT256, {
            value: ethers.parseEther("2").toString(),
            from: user2,
          });
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000066822646615457"
          );
          // User 2 makes balanced deposit, keeping the ratio 2:1
          await this.contract.addLiquidity([String(2e18), String(1e18)], 0, MAX_UINT256, {
            value: ethers.parseEther("2").toString(),
            from: user2,
          });
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000066822646615457"
          );
        });
        it("Value is unchanged after balanced withdrawals", async function () {
          await this.contract.addLiquidity([String(1e18), String(1e18)], 0, MAX_UINT256, {
            from: user1,
            value: ethers.parseEther("1").toString(),
          });
          await this.contract.removeLiquidity(String(1e18), [0, 0], MAX_UINT256, {
            from: user1,
          });
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(String(1e18));
        });
      });
      describe("getDebt", async function () {
        describe("When no swap fee", async function () {
          beforeEach(async function () {
            await this.contract.setSwapFee(0);
          });
          it("Debt must be zero when Ether > gEther", async function () {
            await this.contract.addLiquidity([String(2e18), String(1e18)], "0", MAX_UINT256, {
              value: ethers.parseEther("2").toString(),
              from: user1,
            });
            expect(await this.contract.getDebt()).to.be.bignumber.equal(new BN("0"));
          });
          it("Debt must be non-zero when Ether < gEther", async function () {
            await this.contract.addLiquidity([String(1e18), String(2e18)], 0, MAX_UINT256, {
              value: ethers.parseEther("1").toString(),
              from: user1,
            });
            expect(await this.contract.getDebt()).to.be.bignumber.equal("499147041342998336");
          });
          describe("Pool should be balanced after the debt was paid", async function () {
            beforeEach(async function () {
              await this.contract.addLiquidity([String(1e18), String(2e18)], 0, MAX_UINT256, {
                value: ethers.parseEther("1").toString(),
              });
            });
            it("price=1", async function () {
              const debt = await this.contract.getDebt();
              expect(debt).to.be.bignumber.equal("499147041342998336");
              const expectedDY = await this.contract.calculateSwap(0, 1, debt);
              expect(expectedDY).to.be.bignumber.equal("500852958657001662");
              await this.contract.swap(0, 1, debt, 0, MAX_UINT256, {
                value: debt,
                from: user1,
              });
              const tokenBalance1 = await this.contract.getBalance(0);
              const tokenBalance2 = await this.contract.getBalance(1);
              expect(
                tokenBalance1
                  .mul(new BN(String(1e18)))
                  .div(tokenBalance2)
                  .addn(1)
              ).to.be.bignumber.equal(String(1e18));
              expect(await this.contract.getDebt()).to.be.bignumber.lt(new BN("10"));
            });
            it("price=1.2", async function () {
              await this.gETH.setPricePerShare(String(12e17), tokenId);
              const debt = await this.contract.getDebt();
              expect(debt).to.be.bignumber.equal("797964337058657421");
              const expectedDY = await this.contract.calculateSwap(0, 1, debt);
              expect(expectedDY).to.be.bignumber.equal("668363052451118814");
              await this.contract.swap(0, 1, debt, 0, MAX_UINT256, {
                value: debt,
                from: user1,
              });
              const tokenBalance1 = await this.contract.getBalance(0);
              const tokenBalance2 = await this.contract.getBalance(1);
              expect(
                tokenBalance1
                  .mul(new BN(String(1e18)))
                  .div(tokenBalance2)
                  .addn(1)
              ).to.be.bignumber.equal(String(12e17));
              expect(await this.contract.getDebt()).to.be.bignumber.lt(new BN("10"));
            });
            it("price=2", async function () {
              await this.gETH.setPricePerShare(String(2e18), tokenId);
              const debt = await this.contract.getDebt();
              expect(debt).to.be.bignumber.equal("1989158936944686622");
              const expectedDY = await this.contract.calculateSwap(0, 1, debt);
              expect(expectedDY).to.be.bignumber.equal("1005420531527656688");
              await this.contract.swap(0, 1, debt, 0, MAX_UINT256, {
                value: debt,
                from: user1,
              });
              const tokenBalance1 = await this.contract.getBalance(0);
              const tokenBalance2 = await this.contract.getBalance(1);
              expect(
                tokenBalance1
                  .mul(new BN(String(1e18)))
                  .div(tokenBalance2)
                  .addn(2)
              ).to.be.bignumber.equal(String(2e18));
              expect(await this.contract.getDebt()).to.be.bignumber.lt(new BN("10"));
            });
          });
        });
        describe("When swap fee is 4e6", async function () {
          it("Debt must be zero when Ether > gEther", async function () {
            await this.contract.addLiquidity([String(2e18), String(1e18)], 0, MAX_UINT256, {
              value: ethers.parseEther("2").toString(),
              from: user1,
            });
            expect(await this.contract.getDebt()).to.be.bignumber.equal(new BN("0"));
          });
          it("Debt must be non-zero when Ether < gEther", async function () {
            await this.contract.addLiquidity([String(1e18), String(2e18)], 0, MAX_UINT256, {
              value: ethers.parseEther("1").toString(),
              from: user1,
            });
            const debt = await this.contract.getDebt();
            expect(debt).to.be.bignumber.gt("499147041342998336");
            expect(debt).to.be.bignumber.equal("499247211934729736");
          });
          describe("Pool debt be < 1e15 after the debt was paid.", async function () {
            beforeEach(async function () {
              await this.contract.addLiquidity([String(1e18), String(2e18)], 0, MAX_UINT256, {
                value: ethers.parseEther("1").toString(),
              });
            });
            it("price=1", async function () {
              const debt = await this.contract.getDebt();
              expect(debt).to.be.bignumber.gt("499147041342998336");
              expect(debt).to.be.bignumber.equal("499247211934729736");
              const expectedDY = await this.contract.calculateSwap(0, 1, debt);
              expect(expectedDY).to.be.bignumber.equal("500752747931239795");
              await this.contract.swap(0, 1, debt, 0, MAX_UINT256, {
                value: debt,
                from: user1,
              });
              const tokenBalance1 = await this.contract.getBalance(0);
              const tokenBalance2 = await this.contract.getBalance(1);
              expect(
                tokenBalance1
                  .mul(new BN(String(1e18)))
                  .div(tokenBalance2)
                  .addn(1)
              ).to.be.bignumber.gt(new BN(String(1e18)).sub(new BN(String(1e15))));
              expect(await this.contract.getDebt()).to.be.bignumber.lte(String(1e15));
            });
            it("price=1.2", async function () {
              await this.gETH.setPricePerShare(String(12e17), tokenId);
              const debt = await this.contract.getDebt();
              expect(debt).to.be.bignumber.gt("797964337058657421");
              expect(debt).to.be.bignumber.equal("798124744191245689");
              const expectedDY = await this.contract.calculateSwap(0, 1, debt);
              expect(expectedDY).to.be.bignumber.equal("668229326246004552");
              await this.contract.swap(0, 1, debt, 0, MAX_UINT256, {
                value: debt,
                from: user1,
              });
              const tokenBalance1 = await this.contract.getBalance(0);
              const tokenBalance2 = await this.contract.getBalance(1);
              expect(
                tokenBalance1
                  .mul(new BN(String(1e18)))
                  .div(tokenBalance2)
                  .addn(1)
              ).to.be.bignumber.gt(new BN(String(12e17)).sub(new BN(String(1e15))));
              expect(await this.contract.getDebt()).to.be.bignumber.lte(String(1e15));
            });
            it("price=2", async function () {
              await this.gETH.setPricePerShare(String(2e18), tokenId);
              const debt = await this.contract.getDebt();
              expect(debt).to.be.bignumber.gt("1989158936944686622");
              expect(debt).to.be.bignumber.equal("1989561105157297684");
              const expectedDY = await this.contract.calculateSwap(0, 1, debt);
              expect(expectedDY).to.be.bignumber.equal("1005219366655508469");
              await this.contract.swap(0, 1, debt, 0, MAX_UINT256, {
                value: debt,
                from: user1,
              });
              const tokenBalance1 = await this.contract.getBalance(0);
              const tokenBalance2 = await this.contract.getBalance(1);
              expect(
                tokenBalance1
                  .mul(new BN(String(1e18)))
                  .div(tokenBalance2)
                  .addn(1)
              ).to.be.bignumber.gt(new BN(String(2e18)).sub(new BN(String(1e15))));
              expect(await this.contract.getDebt()).to.be.bignumber.lte(String(1e15));
            });
          });
        });
      });
    });

    context("Fee", function () {
      describe("setSwapFee", function () {
        it("Emits NewSwapFee event", async function () {
          expectEvent(await this.contract.setSwapFee(MAX_SWAP_FEE), this.contract, "NewSwapFee", [
            MAX_SWAP_FEE,
          ]);
        });

        it("Reverts when fee is higher than the limit", async function () {
          await expectRevert(this.contract.setSwapFee(MAX_SWAP_FEE.addn(1)), "LML:Fee is too high");
        });

        it("Success", async function () {
          await this.contract.setSwapFee(MAX_SWAP_FEE);
          expect((await this.contract.LiquidityParams()).swapFee).to.be.bignumber.equal(
            MAX_SWAP_FEE
          );
        });
      });

      describe("setAdminFee", function () {
        it("Emits NewAdminFee event", async function () {
          expectEvent(
            await this.contract.setAdminFee(MAX_ADMIN_FEE),
            this.contract,
            "NewAdminFee",
            [MAX_ADMIN_FEE]
          );
        });

        it("Reverts when adminFee is higher than the limit", async function () {
          await expectRevert(
            this.contract.setAdminFee(MAX_ADMIN_FEE.addn(1)),
            "LML:Fee is too high"
          );
        });

        it("Success", async function () {
          await this.contract.setAdminFee(MAX_ADMIN_FEE);
          expect((await this.contract.LiquidityParams()).adminFee).to.be.bignumber.equal(
            MAX_ADMIN_FEE
          );
        });
      });

      describe("withdrawAdminFees", function () {
        it("Succeeds when there are no fees withdrawn", async function () {
          // Sets adminFee to 1% of the swap fees
          await this.contract.setAdminFee(String(1e8));

          const EtherBefore = await balance.current(user1);
          const tokenBefore = await this.gETH.balanceOf(user1, tokenId);

          await this.contract.withdrawAdminFees(user1);

          const EtherAfter = await balance.current(user1);
          const tokenAfter = await this.gETH.balanceOf(user1, tokenId);
          expect(EtherBefore).to.be.bignumber.equal(EtherAfter);
          expect(tokenBefore).to.be.bignumber.equal(tokenAfter);
        });

        it("Succeeds with expected amount of fees withdrawn", async function () {
          // Sets adminFee to 1% of the swap fees
          await this.contract.setAdminFee(String(1e8));
          await this.contract.swap(0, 1, String(1e17), 0, MAX_UINT256, {
            value: ethers.parseEther("0.1").toString(),
            from: user2,
          });
          await this.contract.swap(1, 0, String(1e17), 0, MAX_UINT256, {
            from: user2,
          });

          expect(await this.contract.getAdminBalance(0)).to.be.bignumber.equal(
            String(400660758190)
          );
          expect(await this.contract.getAdminBalance(1)).to.be.bignumber.equal(
            String(399338962149)
          );

          const EtherBefore = await balance.current(user1);
          const tokenBefore = await this.gETH.balanceOf(user1, tokenId);

          await this.contract.withdrawAdminFees(user1);

          const EtherAfter = await balance.current(user1);
          const tokenAfter = await this.gETH.balanceOf(user1, tokenId);

          expect(EtherAfter.sub(EtherBefore)).to.be.bignumber.equal(String(400660758190));
          expect(tokenAfter.sub(tokenBefore)).to.be.bignumber.equal(String(399338962149));
        });

        it("Withdrawing admin fees has no impact on users' withdrawal", async function () {
          // Sets adminFee to 1% of the swap fees
          await this.contract.setAdminFee(String(1e8));
          await this.contract.addLiquidity([String(1e18), String(1e18)], 0, MAX_UINT256, {
            value: ethers.parseEther("1").toString(),
            from: user1,
          });

          for (let i = 0; i < 10; i++) {
            await this.contract.swap(0, 1, String(1e17), 0, MAX_UINT256, {
              value: ethers.parseEther("0.1").toString(),
              from: user2,
            });
            await this.contract.swap(1, 0, String(1e17), 0, MAX_UINT256, {
              from: user2,
            });
          }

          await this.contract.withdrawAdminFees(deployer);

          const EtherBefore = await balance.current(user1);
          const firstTokenBefore = await this.gETH.balanceOf(user1, tokenId);

          const user1LPTokenBalance = await this.lpToken.balanceOf(user1);

          const tx = await this.contract.removeLiquidity(user1LPTokenBalance, [0, 0], MAX_UINT256, {
            from: user1,
          });
          const gasUsed = new BN(tx.receipt.cumulativeGasUsed.toString()).mul(
            new BN(tx.receipt.effectiveGasPrice.toString())
          );

          const EtherAfter = await balance.current(user1);

          const firstTokenAfter = await this.gETH.balanceOf(user1, tokenId);

          expect(EtherAfter.add(gasUsed).sub(EtherBefore)).to.be.bignumber.equal(
            "999790899571521545"
          );

          expect(firstTokenAfter.sub(firstTokenBefore)).to.be.bignumber.equal(
            "1000605270122712963"
          );
        });
      });
    });

    context("A", function () {
      describe("rampA", function () {
        beforeEach(async () => {
          await forceAdvanceOneBlock();
        });

        it("Emits RampA event", async function () {
          const endTimestamp = (await getBlockTimestamp()).add(DAY.muln(14).addn(1));
          expectEvent(await this.contract.rampA(100, endTimestamp), this.contract, "RampA");
        });

        it("Succeeds to ramp upwards", async function () {
          // Create imbalanced pool to measure virtual price change
          // We expect virtual price to increase as A decreases
          await this.contract.addLiquidity([String(1e18), 0], 0, MAX_UINT256, {
            value: ethers.parseEther("1").toString(),
          });

          // call rampA(), changing A to 100 within a span of 14 days
          const endTimestamp = (await getBlockTimestamp()).add(DAY.muln(14).addn(1));
          await this.contract.rampA(100, endTimestamp);

          // +0 seconds since ramp A
          expect(await this.contract.getA()).to.be.bignumber.equal("60");
          expect(await this.contract.getAPrecise()).to.be.bignumber.equal("6000");
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000066822646615457"
          );

          // set timestamp to +100000 seconds
          await setTimestamp((await getBlockTimestamp()).addn(100000).toNumber());
          expect(await this.contract.getA()).to.be.bignumber.equal("63");
          expect(await this.contract.getAPrecise()).to.be.bignumber.equal("6330");
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000119154175111724"
          );

          // set timestamp to the end of ramp period
          await setTimestamp(endTimestamp.toNumber());
          expect(await this.contract.getA()).to.be.bignumber.equal("100");
          expect(await this.contract.getAPrecise()).to.be.bignumber.equal("10000");
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000471070200386269"
          );
        });

        it("Succeeds to ramp downwards", async function () {
          // Create imbalanced pool to measure virtual price change
          // We expect virtual price to decrease as A decreases
          await this.contract.addLiquidity([String(1e18), 0], 0, MAX_UINT256, {
            value: ethers.parseEther("1").toString(),
          });

          // call rampA()
          const endTimestamp = (await getBlockTimestamp()).add(DAY.muln(14).addn(1));
          await this.contract.rampA(30, endTimestamp);

          // +0 seconds since ramp A
          expect(await this.contract.getA()).to.be.bignumber.equal("60");
          expect(await this.contract.getAPrecise()).to.be.bignumber.equal("6000");
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000066822646615457"
          );

          // set timestamp to +100000 seconds
          await setTimestamp((await getBlockTimestamp()).addn(100000).toNumber());
          expect(await this.contract.getA()).to.be.bignumber.equal("57");
          expect(await this.contract.getAPrecise()).to.be.bignumber.equal("5752");
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal(
            "1000023622369635453"
          );

          // set timestamp to the end of ramp period
          await setTimestamp(endTimestamp.toNumber());
          expect(await this.contract.getA()).to.be.bignumber.equal("30");
          expect(await this.contract.getAPrecise()).to.be.bignumber.equal("3000");
          expect(await this.contract.getVirtualPrice()).to.be.bignumber.equal("999083006036060718");
        });

        it("Reverts with 'Wait 1 day before starting ramp'", async function () {
          await this.contract.rampA(55, (await getBlockTimestamp()).add(DAY.muln(14).addn(1)));
          await expectRevert(
            this.contract.rampA(55, (await getBlockTimestamp()).add(DAY.muln(14).addn(1))),
            "AL:Wait 1 day before starting ramp"
          );
        });

        it("Reverts with 'Insufficient ramp time'", async function () {
          await expectRevert(
            this.contract.rampA(55, (await getBlockTimestamp()).add(DAY.muln(14).subn(1))),
            "AL:Insufficient ramp time"
          );
        });

        it("Reverts with 'futureA_ must be > 0 and < MAX_A'", async function () {
          await expectRevert(
            this.contract.rampA(0, (await getBlockTimestamp()).add(DAY.muln(14).addn(1))),
            "AL:futureA_ must be > 0 and < MAX_A"
          );
        });

        it("Reverts with 'futureA_ is too small'", async function () {
          await expectRevert(
            this.contract.rampA(24, (await getBlockTimestamp()).add(DAY.muln(14).addn(1))),
            "AL:futureA_ is too small"
          );
        });

        it("Reverts with 'futureA_ is too large'", async function () {
          await expectRevert(
            this.contract.rampA(121, (await getBlockTimestamp()).add(DAY.muln(14).addn(1))),
            "AL:futureA_ is too large"
          );
        });
      });

      describe("stopRampA", function () {
        let startTimeStamp;
        let endTimestamp;
        beforeEach(async function () {
          startTimeStamp = await getBlockTimestamp();
          endTimestamp = startTimeStamp.add(DAY.muln(14).addn(1));
          await this.contract.rampA(100, endTimestamp);
        });

        it("Emits StopRampA event", async function () {
          expectEvent(await this.contract.stopRampA(), this.contract, "StopRampA");
        });

        it("Stop ramp succeeds", async function () {
          // set timestamp to +100000 seconds
          await setTimestamp(startTimeStamp.addn(100000).toNumber());
          expect(await this.contract.getA()).to.be.bignumber.equal("63");
          expect(await this.contract.getAPrecise()).to.be.bignumber.equal("6330");

          // Stop ramp
          await this.contract.stopRampA();
          expect(await this.contract.getA()).to.be.bignumber.equal("63");
          expect(await this.contract.getAPrecise()).to.be.bignumber.equal("6330");

          // set timestamp to endTimestamp
          await setTimestamp(endTimestamp.toNumber());

          // verify ramp has stopped
          expect(await this.contract.getA()).to.be.bignumber.equal("63");
          expect(await this.contract.getAPrecise()).to.be.bignumber.equal("6330");
        });

        it("Reverts with 'Ramp is already stopped'", async function () {
          // Stop ramp
          await this.contract.stopRampA();

          // check call reverts when ramp is already stopped
          await expectRevert(this.contract.stopRampA(), "AL:Ramp is already stopped");
        });
      });
    });

    describe("addLiquidity", function () {
      it("Reverts when contract is paused", async function () {
        const beforePoolTokenAmount = await this.lpToken.balanceOf(user1);
        await this.contract.pause();
        await expectCustomError(
          this.contract.addLiquidity([String(1e18), String(3e18)], 0, MAX_UINT256, {
            value: ethers.parseEther("1").toString(),
            from: user1,
          }),
          this.contract,
          "EnforcedPause"
        );
        const afterPoolTokenAmount = await this.lpToken.balanceOf(user1);

        expect(afterPoolTokenAmount).to.be.bignumber.equal(beforePoolTokenAmount);
        // unpause
        await this.contract.unpause();

        await this.contract.addLiquidity([String(1e18), String(3e18)], 0, MAX_UINT256, {
          value: ethers.parseEther("1").toString(),
          from: user1,
        });

        const finalPoolTokenAmount = await this.lpToken.balanceOf(user1);

        expect(finalPoolTokenAmount).to.be.bignumber.gt(beforePoolTokenAmount);
        expect(finalPoolTokenAmount).to.be.bignumber.equal("3993470625071427531");
      });

      it("Reverts with 'received less or more ETH than expected'", async function () {
        await expectRevert(
          this.contract.addLiquidity([String(2e18), String(0)], 0, MAX_UINT256, {
            from: user1,
            value: ethers.parseEther("2.001").toString(),
          }),
          "LML:received less or more ETH than expected"
        );
      });

      it("Reverts with 'Must supply all tokens in pool'", async function () {
        const lpSupInit = await this.lpToken.balanceOf(deployer);
        await this.contract.removeLiquidity(lpSupInit, [0, 0], MAX_UINT256);
        const lpSupEnd = await this.lpToken.balanceOf(deployer);
        await expect(lpSupEnd).to.be.bignumber.equal(new BN("0"));
        await expectRevert(
          this.contract.addLiquidity([String(0), String(3e18)], 0, MAX_UINT256, { from: user1 }),
          "LML:Must supply all tokens in pool"
        );

        await expectRevert(
          this.contract.addLiquidity([String(2e18), String(0)], 0, MAX_UINT256, {
            from: user1,
            value: ethers.parseEther("2").toString(),
          }),
          "LML:Must supply all tokens in pool"
        );
      });

      it("Succeeds with expected output amount of pool tokens", async function () {
        const calculatedPoolTokenAmount = await this.contract.calculateTokenAmount(
          [String(1e18), String(3e18)],
          true,
          { from: user1 }
        );

        const calculatedPoolTokenAmountWithSlippage = calculatedPoolTokenAmount
          .muln(999)
          .divn(1000);

        await this.contract.addLiquidity(
          [String(1e18), String(3e18)],
          calculatedPoolTokenAmountWithSlippage,
          MAX_UINT256,
          { value: ethers.parseEther("1").toString(), from: user1 }
        );

        const actualPoolTokenAmount = await this.lpToken.balanceOf(user1);

        // The actual pool token amount is less than 5e18 due to the imbalance of the underlying tokens
        expect(actualPoolTokenAmount).to.be.bignumber.equal("3993470625071427531");
      });

      it("Succeeds with actual pool token amount being within ±0.1% range of calculated pool token", async function () {
        const calculatedPoolTokenAmount = await this.contract.calculateTokenAmount(
          [String(1e18), String(3e18)],
          true,
          { from: user1 }
        );

        const calculatedPoolTokenAmountWithNegativeSlippage = calculatedPoolTokenAmount
          .muln(999)
          .divn(1000);

        const calculatedPoolTokenAmountWithPositiveSlippage = calculatedPoolTokenAmount
          .muln(1001)
          .divn(1000);

        await this.contract.addLiquidity(
          [String(1e18), String(3e18)],
          calculatedPoolTokenAmountWithNegativeSlippage,
          MAX_UINT256,
          { value: ethers.parseEther("1").toString(), from: user1 }
        );

        const actualPoolTokenAmount = await this.lpToken.balanceOf(user1);

        expect(actualPoolTokenAmount).to.be.bignumber.gte(
          calculatedPoolTokenAmountWithNegativeSlippage
        );

        expect(actualPoolTokenAmount).to.be.bignumber.lte(
          calculatedPoolTokenAmountWithPositiveSlippage
        );
      });

      it("Succeeds with correctly updated tokenBalance after imbalanced deposit", async function () {
        await this.contract.addLiquidity([String(1e18), String(3e18)], 0, MAX_UINT256, {
          value: ethers.parseEther("1").toString(),
          from: user1,
        });

        // Check updated token balance
        const tokenBalance1 = await this.contract.getBalance(0);
        expect(tokenBalance1).to.be.bignumber.eq(String(2e18));

        const tokenBalance2 = await this.contract.getBalance(1);
        expect(tokenBalance2).to.be.bignumber.eq(String(4e18));
      });

      it("Returns correct minted lpToken amount", async function () {
        const initBal = await this.lpToken.balanceOf(user1);
        const receipt = await this.contract.addLiquidity(
          [String(1e18), String(1e18)],
          0,
          MAX_UINT256,
          {
            value: ethers.parseEther("1").toString(),
            from: user1,
          }
        );
        const finalBal = await this.lpToken.balanceOf(user1);
        const expMint = finalBal.sub(initBal);

        expectEvent(receipt, this.contract, "return$addLiquidity", [expMint]);
      });

      it("Reverts when minToMint is not reached due to front running", async function () {
        const calculatedLPTokenAmount = await this.contract.calculateTokenAmount(
          [String(1e18), String(3e18)],
          true,
          { from: user1 }
        );
        const calculatedLPTokenAmountWithSlippage = calculatedLPTokenAmount.muln(999).divn(1000);

        // Someone else deposits thus front running user 1's deposit
        await this.contract.addLiquidity([String(1e19), String(3e19)], 0, MAX_UINT256, {
          value: ethers.parseEther("10").toString(),
        });

        await expectRevert(
          this.contract.addLiquidity(
            [String(1e18), String(3e18)],
            calculatedLPTokenAmountWithSlippage,
            MAX_UINT256,
            { value: ethers.parseEther("1").toString(), from: user1 }
          ),
          "LML:Could not mint min requested"
        );
      });

      it("Reverts when block is mined after deadline", async function () {
        const currentTimestamp = await getBlockTimestamp();

        await setTimestamp(currentTimestamp.addn(600).toNumber());

        await expectRevert(
          this.contract.addLiquidity(
            [String(1e16), String(1e16)],
            0,
            currentTimestamp.addn(599).toNumber(),
            {
              value: ethers.parseEther("0.01").toString(),
              from: user1,
            }
          ),
          "LM:Deadline not met"
        );
      });

      it("Emits addLiquidity event", async function () {
        const calculatedLPTokenAmount = await this.contract.calculateTokenAmount(
          [String(1e16), String(1e16)],
          true,
          {
            from: user1,
          }
        );

        const calculatedLPTokenAmountWithSlippage = calculatedLPTokenAmount.muln(999).divn(1000);

        expectEvent(
          await this.contract.addLiquidity(
            [String(1e16), String(1e16)],
            calculatedLPTokenAmountWithSlippage,
            MAX_UINT256,
            { value: ethers.parseEther("0.01").toString(), from: user1 }
          ),
          this.contract,
          "AddLiquidity"
        );
      });
    });

    context("withdrawal", function () {
      let currentUser1Balance;

      beforeEach(async function () {
        await this.contract.addLiquidity([String(9e18), String(9e18)], 0, MAX_UINT256, {
          from: deployer,
          value: ethers.parseEther("9").toString(),
        });

        await this.contract.addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.parseEther("2").toString(),
          from: user1,
        });
        currentUser1Balance = await this.lpToken.balanceOf(user1);
        expect(currentUser1Balance).to.be.bignumber.equal("2008115340140025950");
      });

      describe("removeLiquidity", function () {
        it("Reverts with 'Cannot exceed total supply'", async function () {
          await expectRevert(
            this.contract.calculateRemoveLiquidity(MAX_UINT256),
            "LML:Cannot exceed total supply"
          );
        });

        it("Succeeds even when contract is paused", async function () {
          // pause the contract
          await this.contract.pause();

          await this.contract.removeLiquidity(currentUser1Balance, [0, 0], MAX_UINT256, {
            from: user1,
          });

          await this.contract.unpause();
        });

        it("Reverts when user tries to burn more LP tokens than they own", async function () {
          // User 1 adds liquidity

          await expectRevert(
            this.contract.removeLiquidity(currentUser1Balance.addn(1), [0, 0], MAX_UINT256, {
              from: user1,
            }),
            "LML:>LP.balanceOf"
          );
        });

        it("Reverts when minAmounts of underlying tokens are not reached due to front running", async function () {
          // User 1 adds liquidity

          const [expectedZerothTokenAmount, expectedFirstTokenAmount] =
            await this.contract.calculateRemoveLiquidity(currentUser1Balance);

          expect(expectedZerothTokenAmount).to.be.bignumber.equal("1094931742643574883");
          expect(expectedFirstTokenAmount).to.be.bignumber.equal("913355561988515381");

          // User 2 adds liquidity, which leads to change in balance of underlying tokens
          await this.contract.addLiquidity([String(1e16), String(2e18)], 0, MAX_UINT256, {
            value: ethers.parseEther("0.01").toString(),
            from: user2,
          });

          // User 1 tries to remove liquidity which get reverted due to front running
          await expectRevert(
            this.contract.removeLiquidity(
              currentUser1Balance,
              [expectedZerothTokenAmount, expectedFirstTokenAmount],
              MAX_UINT256,
              {
                from: user1,
              }
            ),
            "LML:amounts[i] < minAmounts[i]"
          );
        });

        it("Reverts when block is mined after deadline", async function () {
          const currentTimestamp = await getBlockTimestamp();
          await setTimestamp(currentTimestamp.addn(600).toNumber());
          await expectRevert(
            this.contract.removeLiquidity(
              currentUser1Balance,
              [0, 0],
              currentTimestamp.addn(599).toNumber(),
              {
                from: user1,
              }
            ),
            "LM:Deadline not met"
          );
        });

        it("Emits removeLiquidity event", async function () {
          // User 1 adds liquidity

          // User 1 tries removes liquidity

          expectEvent(
            await this.contract.removeLiquidity(currentUser1Balance, [0, 0], MAX_UINT256, {
              from: user1,
            }),
            this.contract,
            "RemoveLiquidity"
          );
        });
      });

      describe("removeLiquidityImbalance", function () {
        it("Reverts when contract is paused", async function () {
          // User 1 adds liquidity

          // Owner pauses the contract
          await this.contract.pause();

          await expectCustomError(
            this.contract.removeLiquidityImbalance(
              [String(1e18), String(1e16)],
              currentUser1Balance,
              MAX_UINT256,
              {
                from: user1,
              }
            ),
            this.contract,
            "EnforcedPause"
          );
        });

        it("Reverts with 'Cannot withdraw more than available'", async function () {
          await expectRevert(
            this.contract.removeLiquidityImbalance(
              [MAX_UINT256, MAX_UINT256],
              currentUser1Balance,
              MAX_UINT256
            ),
            "LML:Cannot withdraw > available"
          );
        });

        it("Succeeds with calculated max amount of pool token to be burned (±0.1%)", async function () {
          // User 1 adds liquidity

          // User 1 calculates amount of pool token to be burned
          const maxPoolTokenAmountToBeBurned = await this.contract.calculateTokenAmount(
            [String(1e18), String(1e16)],
            false
          );

          // ±0.1% range of pool token to be burned
          const maxPoolTokenAmountToBeBurnedNegativeSlippage = maxPoolTokenAmountToBeBurned
            .muln(1001)
            .divn(1000);

          const maxPoolTokenAmountToBeBurnedPositiveSlippage = maxPoolTokenAmountToBeBurned
            .muln(999)
            .divn(1000);

          const EtherBefore = await balance.current(user1);
          const firstTokenBalanceBefore = await this.gETH.balanceOf(user1, tokenId);

          const poolTokenBalanceBefore = await this.lpToken.balanceOf(user1);

          // User 1 withdraws imbalanced tokens

          const tx = await this.contract.removeLiquidityImbalance(
            [String(1e18), String(1e16)],
            maxPoolTokenAmountToBeBurnedNegativeSlippage,
            MAX_UINT256,
            { from: user1 }
          );
          const gasUsed = new BN(tx.receipt.cumulativeGasUsed.toString()).mul(
            new BN(tx.receipt.effectiveGasPrice.toString())
          );

          const EtherAfter = await balance.current(user1);
          const firstTokenBalanceAfter = await this.gETH.balanceOf(user1, tokenId);

          const poolTokenBalanceAfter = await this.lpToken.balanceOf(user1);

          // Check the actual returned token amounts match the requested amounts
          expect(EtherAfter.add(gasUsed).sub(EtherBefore)).to.be.bignumber.equal(String(1e18));
          expect(firstTokenBalanceAfter.sub(firstTokenBalanceBefore)).to.be.bignumber.equal(
            String(1e16)
          );

          // Check the actual burned pool token amount
          const actualPoolTokenBurned = poolTokenBalanceBefore.sub(poolTokenBalanceAfter);

          expect(actualPoolTokenBurned).to.be.bignumber.equal("1009066061317383115");
          expect(actualPoolTokenBurned).to.be.bignumber.gte(
            maxPoolTokenAmountToBeBurnedPositiveSlippage
          );
          expect(actualPoolTokenBurned).to.be.bignumber.lte(
            maxPoolTokenAmountToBeBurnedNegativeSlippage
          );
        });

        it("Returns correct amount of burned lpToken", async function () {
          const receipt = await this.contract.removeLiquidityImbalance(
            [String(1e18), String(1e16)],
            currentUser1Balance,
            MAX_UINT256,
            { from: user1 }
          );

          const futureUser1Balance = await this.lpToken.balanceOf(user1);

          expectEvent(receipt, this.contract, "return$removeLiquidityImbalance", [
            currentUser1Balance.sub(futureUser1Balance),
          ]);
        });

        it("Reverts when user tries to burn more LP tokens than they own", async function () {
          // User 1 adds liquidity

          await expectRevert(
            this.contract.removeLiquidityImbalance(
              [String(1e18), String(1e16)],
              currentUser1Balance.addn(1),
              MAX_UINT256,
              {
                from: user1,
              }
            ),
            "LML:>LP.balanceOf"
          );
        });

        it("Reverts when minAmounts of underlying tokens are not reached due to front running", async function () {
          // User 1 adds liquidity

          // User 1 calculates amount of pool token to be burned
          const maxPoolTokenAmountToBeBurned = await this.contract.calculateTokenAmount(
            [String(1e18), String(1e16)],
            false
          );

          // Calculate +0.1% of pool token to be burned
          const maxPoolTokenAmountToBeBurnedNegativeSlippage = maxPoolTokenAmountToBeBurned
            .muln(1001)
            .divn(1000);

          // User 2 adds liquidity, which leads to change in balance of underlying tokens
          await this.contract.addLiquidity([String(1e16), String(1e20)], 0, MAX_UINT256, {
            value: ethers.parseEther("0.01").toString(),
            from: user1,
          });

          // User 1 tries to remove liquidity which get reverted due to front running
          await expectRevert(
            this.contract.removeLiquidityImbalance(
              [String(1e18), String(1e16)],
              maxPoolTokenAmountToBeBurnedNegativeSlippage,
              MAX_UINT256,
              {
                from: user1,
              }
            ),
            "LML:tokenAmount > maxBurnAmount"
          );
        });

        it("Reverts when block is mined after deadline", async function () {
          // User 1 adds liquidity

          const currentTimestamp = await getBlockTimestamp();
          await setTimestamp(currentTimestamp.addn(600).toNumber());

          await expectRevert(
            this.contract.removeLiquidityImbalance(
              [String(1e18), String(1e16)],
              currentUser1Balance,
              currentTimestamp.addn(599).toNumber(),
              {
                from: user1,
              }
            ),
            "LM:Deadline not met"
          );
        });

        it("Emits RemoveLiquidityImbalance event", async function () {
          expectEvent(
            await this.contract.removeLiquidityImbalance(
              [String(1e18), String(1e16)],
              currentUser1Balance,
              MAX_UINT256,
              { from: user1 }
            ),
            this.contract,
            "RemoveLiquidityImbalance"
          );
        });
      });

      describe("removeLiquidityOneToken", function () {
        it("Reverts when contract is paused", async function () {
          // Owner pauses the contract
          await this.contract.pause();

          await expectCustomError(
            this.contract.removeLiquidityOneToken(currentUser1Balance, 0, 0, MAX_UINT256, {
              from: user1,
            }),
            this.contract,
            "EnforcedPause"
          );
        });

        it("Reverts with 'Token index out of range'", async function () {
          await expectRevert(
            this.contract.calculateRemoveLiquidityOneToken(1, 5),
            "LML:Token index out of range"
          );
        });

        it("Reverts with 'Withdraw exceeds available'", async function () {
          await this.contract.swap(1, 0, String(1e19), 0, MAX_UINT256, { from: user2 });

          await expectRevert(
            this.contract.calculateRemoveLiquidityOneToken(currentUser1Balance.muln(2), 0, {
              from: user1,
            }),
            "LML:Withdraw exceeds available"
          );
        });

        it("Reverts with 'Token not found'", async function () {
          await expectRevert(
            this.contract.removeLiquidityOneToken(0, 9, 1, MAX_UINT256, { from: user1 }),
            "LML:Token not found"
          );
        });

        it("Ether: Succeeds with calculated token amount as minAmount", async function () {
          // User 1 calculates the amount of underlying token to receive.
          const calculatedZerothTokenAmount = await this.contract.calculateRemoveLiquidityOneToken(
            currentUser1Balance,
            0
          );

          expect(calculatedZerothTokenAmount).to.be.bignumber.equal("2009272526202775311");

          // User 1 initiates one token withdrawal
          const before = await balance.current(user1);

          const tx = await this.contract.removeLiquidityOneToken(
            currentUser1Balance,
            0,
            calculatedZerothTokenAmount,
            MAX_UINT256,
            { from: user1 }
          );

          const gasUsed = new BN(tx.receipt.cumulativeGasUsed.toString()).mul(
            new BN(tx.receipt.effectiveGasPrice.toString())
          );

          const after = await balance.current(user1);

          expect(after.add(gasUsed).sub(before)).to.be.bignumber.equal("2009272526202775311");
        });

        it("gETH: Succeeds with calculated token amount as minAmount", async function () {
          // User 1 calculates the amount of underlying token to receive.
          const calculatedTokenAmount = await this.contract.calculateRemoveLiquidityOneToken(
            currentUser1Balance,
            1
          );

          expect(calculatedTokenAmount).to.be.bignumber.equal("2002407296469467895");

          // User 1 initiates one token withdrawal
          const before = await this.gETH.balanceOf(user1, tokenId);

          await this.contract.removeLiquidityOneToken(
            currentUser1Balance,
            1,
            calculatedTokenAmount,
            MAX_UINT256,
            { from: user1 }
          );

          const after = await this.gETH.balanceOf(user1, tokenId);

          expect(after.sub(before)).to.be.bignumber.equal("2002407296469467895");
        });

        it("Returns correct amount of received token", async function () {
          const receipt = await this.contract.removeLiquidityOneToken(
            String(1e18),
            0,
            0,
            MAX_UINT256,
            {
              from: user1,
            }
          );

          expectEvent(receipt, this.contract, "return$removeLiquidityOneToken", [
            new BN("1000940086154542003"),
          ]);
        });

        it("Reverts when user tries to burn more LP tokens than they own", async function () {
          await expectRevert(
            this.contract.removeLiquidityOneToken(currentUser1Balance.addn(1), 0, 0, MAX_UINT256, {
              from: user1,
            }),
            "LML:>LP.balanceOf"
          );
        });

        it("Reverts when minAmount of underlying token is not reached due to front running", async function () {
          // User 1 calculates the amount of underlying token to receive.
          const calculatedFirstTokenAmount = await this.contract.calculateRemoveLiquidityOneToken(
            currentUser1Balance,
            0
          );
          expect(calculatedFirstTokenAmount).to.be.bignumber.equal("2009272526202775311");

          // User 2 adds liquidity before User 1 initiates withdrawal
          await this.contract.addLiquidity([String(1e16), String(1e20)], 0, MAX_UINT256, {
            value: ethers.parseEther("0.01").toString(),
            from: user2,
          });

          // User 1 initiates one token withdrawal
          await expectRevert(
            this.contract.removeLiquidityOneToken(
              currentUser1Balance,
              0,
              calculatedFirstTokenAmount,
              MAX_UINT256,
              {
                from: user1,
              }
            ),
            "LML:dy < minAmount"
          );
        });

        it("Reverts when block is mined after deadline", async function () {
          const currentTimestamp = await getBlockTimestamp();
          await setTimestamp(currentTimestamp.addn(600).toNumber());

          await expectRevert(
            this.contract.removeLiquidityOneToken(
              currentUser1Balance,
              0,
              0,
              currentTimestamp.addn(599).toNumber(),
              {
                from: user1,
              }
            ),
            "LM:Deadline not met"
          );
        });

        it("Emits RemoveLiquidityOne event", async function () {
          expectEvent(
            await this.contract.removeLiquidityOneToken(currentUser1Balance, 0, 0, MAX_UINT256, {
              from: user1,
            }),
            this.contract,
            "RemoveLiquidityOne"
          );
        });
      });
    });

    describe("swap", function () {
      it("Reverts when contract is paused", async function () {
        await this.contract.pause();
        await expectCustomError(
          this.contract.swap(0, 1, String(1e16), 0, MAX_UINT256, {
            value: ethers.parseEther("0.01").toString(),
            from: user1,
          }),
          this.contract,
          "EnforcedPause"
        );
      });

      it("Reverts with 'Token index out of range'", async function () {
        await expectRevert(
          this.contract.calculateSwap(0, 9, String(1e17)),
          "LML:Token index out of range"
        );
      });

      it("Reverts with 'Cannot swap more/less than you sent'", async function () {
        await expectRevert(
          this.contract.swap(1, 0, MAX_UINT256, 0, MAX_UINT256, {
            value: ethers.parseEther("0.01").toString(),
            from: user1,
          }),
          "LML:Cannot swap > you own"
        );
      });
      it("Reverts with 'Cannot swap != eth sent'", async function () {
        await expectRevert(
          this.contract.swap(0, 1, MAX_UINT256, 0, MAX_UINT256, {
            value: ethers.parseEther("0.01").toString(),
            from: user1,
          }),
          "LML:Cannot swap != eth sent"
        );
      });
      it("Succeeds with expected swap amounts (Ether => gEther)", async function () {
        // User 1 calculates how much token to receive
        const calculatedSwapReturn = await this.contract.calculateSwap(0, 1, String(1e17));
        expect(calculatedSwapReturn).to.be.bignumber.equal("99794806641066759");

        const tokenFromBalanceBefore = await balance.current(user1);
        const tokenToBalanceBefore = await this.gETH.balanceOf(user1, tokenId);

        // User 1 successfully initiates swap
        const tx = await this.contract.swap(0, 1, String(1e17), calculatedSwapReturn, MAX_UINT256, {
          from: user1,
          value: ethers.parseEther("0.1").toString(),
        });
        const gasUsed = new BN(tx.receipt.cumulativeGasUsed.toString()).mul(
          new BN(tx.receipt.effectiveGasPrice.toString())
        );

        const tokenFromBalanceAfter = await balance.current(user1);
        // Check the sent and received amounts are as expected
        const tokenToBalanceAfter = await this.gETH.balanceOf(user1, tokenId);

        expect(
          tokenFromBalanceBefore.sub(tokenFromBalanceAfter.add(gasUsed))
        ).to.be.bignumber.equal(String(1e17));

        expect(tokenToBalanceAfter.sub(tokenToBalanceBefore)).to.be.bignumber.equal(
          calculatedSwapReturn
        );
      });

      it("Succeeds with expected swap amounts (gEther => Ether)", async function () {
        // User 1 calculates how much token to receive
        const calculatedSwapReturn = await this.contract.calculateSwap(1, 0, String(1e17));
        expect(calculatedSwapReturn).to.be.bignumber.equal("99794806641066759");

        const tokenToBalanceBefore = await balance.current(user1);
        const tokenFromBalanceBefore = await this.gETH.balanceOf(user1, tokenId);

        // User 1 successfully initiates swap
        const tx = await this.contract.swap(1, 0, String(1e17), calculatedSwapReturn, MAX_UINT256, {
          from: user1,
        });
        const gasUsed = new BN(tx.receipt.cumulativeGasUsed.toString()).mul(
          new BN(tx.receipt.effectiveGasPrice.toString())
        );

        const tokenToBalanceAfter = await balance.current(user1);
        // Check the sent and received amounts are as expected
        const tokenFromBalanceAfter = await this.gETH.balanceOf(user1, tokenId);

        expect(tokenFromBalanceBefore.sub(tokenFromBalanceAfter)).to.be.bignumber.equal(
          String(1e17)
        );

        expect(tokenToBalanceAfter.sub(tokenToBalanceBefore).add(gasUsed)).to.be.bignumber.equal(
          calculatedSwapReturn
        );
      });

      it("Succeeds when using lower minDy even when transaction is front-ran", async function () {
        // User 1 calculates how much token to receive with 1% slippage
        const calculatedSwapReturn = await this.contract.calculateSwap(0, 1, String(1e17));
        expect(calculatedSwapReturn).to.be.bignumber.equal("99794806641066759");

        const tokenFromBalanceBefore = await balance.current(user1);
        const tokenToBalanceBefore = await this.gETH.balanceOf(user1, tokenId);

        const calculatedSwapReturnWithNegativeSlippage = calculatedSwapReturn.muln(99).divn(100);

        // User2 swaps before User1
        await this.contract.swap(0, 1, String(1e17), 0, MAX_UINT256, {
          from: user2,
          value: ethers.parseEther("0.1").toString(),
        });

        // User 1 successfully initiates swap with 1% slippage from initial calculated amount
        const tx = await this.contract.swap(
          0,
          1,
          String(1e17),
          calculatedSwapReturnWithNegativeSlippage,
          MAX_UINT256,
          {
            from: user1,
            value: ethers.parseEther("0.1").toString(),
          }
        );
        const gasUsed = new BN(tx.receipt.cumulativeGasUsed.toString()).mul(
          new BN(tx.receipt.effectiveGasPrice.toString())
        );

        // Check the sent and received amounts are as expected
        const tokenFromBalanceAfter = await balance.current(user1);
        const tokenToBalanceAfter = await this.gETH.balanceOf(user1, tokenId);

        expect(
          tokenFromBalanceBefore.sub(tokenFromBalanceAfter.add(gasUsed))
        ).to.be.bignumber.equal(String(1e17));

        const actualReceivedAmount = tokenToBalanceAfter.sub(tokenToBalanceBefore);

        expect(actualReceivedAmount).to.be.bignumber.equal("99445844521513912");
        expect(actualReceivedAmount).to.be.bignumber.gt(calculatedSwapReturnWithNegativeSlippage);
        expect(actualReceivedAmount).to.be.bignumber.lt(calculatedSwapReturn);
      });

      it("Succeeds when using lower minDy even when transaction is front-ran gEther => Ether", async function () {
        // User 1 calculates how much token to receive with 1% slippage
        const calculatedSwapReturn = await this.contract.calculateSwap(1, 0, String(1e17));
        expect(calculatedSwapReturn).to.be.bignumber.equal("99794806641066759");

        const tokenToBalanceBefore = await balance.current(user1);
        const tokenFromBalanceBefore = await this.gETH.balanceOf(user1, tokenId);

        const calculatedSwapReturnWithNegativeSlippage = calculatedSwapReturn.muln(99).divn(100);

        // User 2 swaps before User 1 does
        await this.contract.swap(1, 0, String(1e17), 0, MAX_UINT256, {
          from: user2,
        });

        // User 1 successfully initiates swap with 1% slippage from initial calculated amount
        const tx = await this.contract.swap(
          1,
          0,
          String(1e17),
          calculatedSwapReturnWithNegativeSlippage,
          MAX_UINT256,
          {
            from: user1,
          }
        );
        const gasUsed = new BN(tx.receipt.cumulativeGasUsed.toString()).mul(
          new BN(tx.receipt.effectiveGasPrice.toString())
        );

        // Check the sent and received amounts are as expected
        const tokenToBalanceAfter = await balance.current(user1);
        const tokenFromBalanceAfter = await this.gETH.balanceOf(user1, tokenId);

        expect(tokenFromBalanceBefore.sub(tokenFromBalanceAfter)).to.be.bignumber.equal(
          String(1e17)
        );

        const actualReceivedAmount = tokenToBalanceAfter.add(gasUsed).sub(tokenToBalanceBefore);

        expect(actualReceivedAmount).to.be.bignumber.equal("99445844521513912");
        expect(actualReceivedAmount).to.be.bignumber.gt(calculatedSwapReturnWithNegativeSlippage);
        expect(actualReceivedAmount).to.be.bignumber.lt(calculatedSwapReturn);
      });

      it("Reverts when minDy (minimum amount token to receive) is not reached due to front running", async function () {
        // User 1 calculates how much token to receive
        const calculatedSwapReturn = await this.contract.calculateSwap(0, 1, String(1e17));
        expect(calculatedSwapReturn).to.be.bignumber.equal("99794806641066759");

        // User 2 swaps before User 1 does
        await this.contract.swap(0, 1, String(1e17), 0, MAX_UINT256, {
          from: user2,
          value: ethers.parseEther("0.1").toString(),
        });

        // User 1 initiates swap
        await expectRevert(
          this.contract.swap(0, 1, String(1e17), calculatedSwapReturn, MAX_UINT256, {
            from: user1,
            value: ethers.parseEther("0.1").toString(),
          }),
          "LML:Swap didnot result in min tokens"
        );
      });

      it("Returns correct amount of received token Ether => gEther", async function () {
        const receipt = await this.contract.swap(0, 1, String(1e18), 0, MAX_UINT256, {
          value: ethers.parseEther("1").toString(),
        });
        expectEvent(receipt, this.contract, "return$swap", [new BN("916300000000000000")]);
      });

      it("Returns correct amount of received token gEther => Ether", async function () {
        const receipt = await this.contract.swap(1, 0, String(1e18), 0, MAX_UINT256, {
          value: ethers.parseEther("1").toString(),
        });
        expectEvent(receipt, this.contract, "return$swap", [new BN("916300000000000000")]);
      });

      it("Reverts when block is mined after deadline", async function () {
        const currentTimestamp = await getBlockTimestamp();
        await setTimestamp(currentTimestamp.addn(600).toNumber());

        await expectRevert(
          this.contract.swap(0, 1, String(1e17), 0, currentTimestamp.addn(599).toNumber(), {
            from: user1,
          }),
          "LM:Deadline not met"
        );
      });

      it("Emits TokenSwap event", async function () {
        expectEvent(
          await this.contract.swap(0, 1, String(1e17), 0, MAX_UINT256, {
            from: user1,
            value: ethers.parseEther("0.1").toString(),
          }),
          this.contract,
          "TokenSwap"
        );
      });
    });
  });
});
