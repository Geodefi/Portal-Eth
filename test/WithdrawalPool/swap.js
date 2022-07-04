/* eslint-disable camelcase */
const { BigNumber, utils } = require("ethers");

const {
  TIME,
  MAX_UINT256,
  asyncForEach,
  getCurrentBlockTimestamp,
  getUserTokenBalance,
  setNextTimestamp,
  setTimestamp,
  forceAdvanceOneBlock,
} = require("../testUtils");

const { solidity } = require("ethereum-waffle");
const { deployments, waffle } = require("hardhat");

const chai = require("chai");

chai.use(solidity);
const { expect } = chai;
const provider = waffle.provider;

describe("Swap", async () => {
  let signers;
  let test_pool; // swap
  let testSwapReturnValues;
  let test_pool_swapToken; // LPToken
  let owner;
  let user1;
  let user2;
  let ownerAddress;
  let user1Address;
  let user2Address;
  let test_pool_swapStorage; // swapStorage
  let gETHReference;

  // Test Values
  const INITIAL_A_VALUE = 60;
  const SWAP_FEE = 4e6; // 4bps
  const ADMIN_FEE = 0; // 0
  const LP_TOKEN_NAME = "GeoDex Test_pool LP Token";
  const LP_TOKEN_SYMBOL = "Test_pool_GeoDexLP";

  const randId = 69;

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      const { get } = deployments;
      await deployments.fixture(); // ensure you start from a fresh deployments

      signers = await ethers.getSigners();
      owner = signers[0];
      user1 = signers[1];
      user2 = signers[2];
      ownerAddress = await owner.getAddress();
      user1Address = await user1.getAddress();
      user2Address = await user2.getAddress();

      gETHReference = await ethers.getContractAt(
        "gETH",
        (
          await get("gETH")
        ).address
      );
      await asyncForEach(
        [ownerAddress, user1Address, user2Address],
        async (signerAddress) => {
          await gETHReference.mint(
            signerAddress,
            randId,
            String(1e20),
            utils.formatBytes32String("")
          );
          new_balance_1 = await gETHReference.balanceOf(signerAddress, randId);
          expect(new_balance_1).to.be.eq(String(1e20));
        }
      );
      new_balance_1 = await gETHReference.setPricePerShare(
        String(1e18),
        randId
      );
      swap = await ethers.getContract("Swap");

      await swap.initialize(
        gETHReference.address,
        randId,
        LP_TOKEN_NAME,
        LP_TOKEN_SYMBOL,
        INITIAL_A_VALUE,
        SWAP_FEE,
        ADMIN_FEE,
        (
          await get("LPToken")
        ).address
      );
      test_pool = swap;

      expect(await test_pool.getVirtualPrice()).to.be.eq(0);
      swapStorage = await swap.swapStorage();

      test_pool_swapStorage = await swap.swapStorage();

      test_pool_swapToken = await ethers.getContractAt(
        "LPToken",
        test_pool_swapStorage.lpToken
      );

      const testSwapReturnValuesFactory = await ethers.getContractFactory(
        "TestSwapReturnValues"
      );

      testSwapReturnValues = await testSwapReturnValuesFactory.deploy(
        test_pool.address,
        gETHReference.address,
        test_pool_swapToken.address,
        2
      );

      await asyncForEach([owner, user1, user2], async (signer) => {
        await gETHReference
          .connect(signer)
          .setApprovalForAll(test_pool.address, true);
        await test_pool_swapToken
          .connect(signer)
          .approve(test_pool.address, MAX_UINT256);
      });

      await test_pool.addLiquidity(
        [String(1e18), String(1e18)],
        0,
        MAX_UINT256,
        {
          value: String(1e18),
        }
      );

      expect(await provider.getBalance(test_pool.address)).to.eq(String(1e18));
      expect(await gETHReference.balanceOf(test_pool.address, randId)).to.eq(
        String(1e18)
      );
    }
  );

  beforeEach(async () => {
    await setupTest();
  });

  describe("swapStorage", () => {
    describe("lpToken", async () => {
      it("Returns correct lpTokenName", async () => {
        expect(await test_pool_swapToken.name()).to.eq(LP_TOKEN_NAME);
      });

      it("Returns correct lpTokenSymbol", async () => {
        expect(await test_pool_swapToken.symbol()).to.eq(LP_TOKEN_SYMBOL);
      });

      it("Returns true after successfully calling transferFrom", async () => {
        // User 1 adds liquidity
        await test_pool
          .connect(user1)
          .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
            value: ethers.utils.parseEther("2"),
          });

        // User 1 approves User 2 for MAX_UINT256
        test_pool_swapToken.connect(user1).approve(user2Address, MAX_UINT256);

        // User 2 transfers 1337 from User 1 to themselves using transferFrom
        await test_pool_swapToken
          .connect(user2)
          .transferFrom(user1Address, user2Address, 1337);

        expect(await test_pool_swapToken.balanceOf(user2Address)).to.eq(1337);
      });
    });

    describe("A", async () => {
      it("Returns correct A value", async () => {
        expect(await test_pool.getA()).to.eq(INITIAL_A_VALUE);
        expect(await test_pool.getAPrecise()).to.eq(INITIAL_A_VALUE * 100);
      });
    });

    describe("fee", async () => {
      it("Returns correct fee value", async () => {
        expect((await test_pool.swapStorage()).swapFee).to.eq(SWAP_FEE);
      });
    });

    describe("adminFee", async () => {
      it("Returns correct adminFee value", async () => {
        expect(test_pool_swapStorage.adminFee).to.eq(ADMIN_FEE);
      });
    });
  });

  describe("getToken", () => {
    it("Returns correct integer value of pooled tokens", async () => {
      expect(await test_pool.getToken()).to.eq(randId);
    });
  });

  describe("getTokenBalance", () => {
    it("Returns correct balances of pooled tokens", async () => {
      expect(await test_pool.getTokenBalance(0)).to.eq(
        BigNumber.from(String(1e18))
      );
      expect(await test_pool.getTokenBalance(1)).to.eq(
        BigNumber.from(String(1e18))
      );
    });

    it("Reverts when index is out of range", async () => {
      await expect(test_pool.getTokenBalance(2)).to.be.reverted;
    });
  });

  describe("getA", () => {
    it("Returns correct value", async () => {
      expect(await test_pool.getA()).to.eq(INITIAL_A_VALUE);
    });
  });

  describe("getVirtualPrice", () => {
    it("Returns expected value after initial deposit", async () => {
      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from(String(1e18))
      );
    });

    it("Returns expected values after swaps", async () => {
      // With each swap, virtual price will increase due to the fees
      await test_pool.connect(user1).swap(0, 1, String(1e17), 0, MAX_UINT256, {
        value: ethers.utils.parseEther("0.1"),
      });
      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from("1000020001975421763")
      );

      await test_pool.connect(user1).swap(1, 0, String(1e17), 0, MAX_UINT256);

      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from("1000040035070723434")
      );
    });

    it("Returns expected values after imbalanced withdrawal", async () => {
      await test_pool
        .connect(user1)
        .addLiquidity([String(1e18), String(1e18)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("1"),
        });
      await test_pool
        .connect(user2)
        .addLiquidity([String(1e18), String(1e18)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("1"),
        });
      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from(String(1e18))
      );

      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, String(2e18));
      await test_pool
        .connect(user1)
        .removeLiquidityImbalance([String(1e18), 0], String(2e18), MAX_UINT256);

      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from("1000040029773424026")
      );

      await test_pool_swapToken
        .connect(user2)
        .approve(test_pool.address, String(2e18));
      await test_pool
        .connect(user2)
        .removeLiquidityImbalance([0, String(1e18)], String(2e18), MAX_UINT256);

      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from("1000080046628378343")
      );
    });

    it("Value is unchanged after balanced deposits", async () => {
      // pool is 1:1:1 ratio
      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from(String(1e18))
      );
      await test_pool
        .connect(user1)
        .addLiquidity([String(1e18), String(1e18)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("1"),
        });
      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from(String(1e18))
      );

      // pool changes to 1:2:1 ratio, thus changing the virtual price
      await test_pool
        .connect(user2)
        .addLiquidity([String(2e18), String(0)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });

      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from("1000066822646615457")
      );
      // User 2 makes balanced deposit, keeping the ratio 2:1
      await test_pool
        .connect(user2)
        .addLiquidity([String(2e18), String(1e18)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });

      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from("1000066822646615457")
      );
    });

    it("Value is unchanged after balanced withdrawals", async () => {
      await test_pool
        .connect(user1)
        .addLiquidity([String(1e18), String(1e18)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("1"),
        });

      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, String(1e18));

      await test_pool
        .connect(user1)
        .removeLiquidity(String(1e18), [0, 0], MAX_UINT256);
      expect(await test_pool.getVirtualPrice()).to.eq(
        BigNumber.from(String(1e18))
      );
    });
  });

  describe("setSwapFee", () => {
    it("Emits NewSwapFee event", async () => {
      await expect(test_pool.setSwapFee(BigNumber.from(1e8))).to.emit(
        test_pool,
        "NewSwapFee"
      );
    });

    it("Reverts when called by non-owners", async () => {
      await expect(test_pool.connect(user1).setSwapFee(0)).to.be.reverted;
      await expect(test_pool.connect(user2).setSwapFee(BigNumber.from(1e8))).to
        .be.reverted;
    });

    it("Reverts when fee is higher than the limit", async () => {
      await expect(test_pool.setSwapFee(BigNumber.from(1e8).add(1))).to.be
        .reverted;
    });

    it("Succeeds when fee is within the limit", async () => {
      await test_pool.setSwapFee(BigNumber.from(1e8));
      expect((await test_pool.swapStorage()).swapFee).to.eq(
        BigNumber.from(1e8)
      );
    });
  });

  describe("setAdminFee", () => {
    it("Emits NewAdminFee event", async () => {
      await expect(test_pool.setAdminFee(BigNumber.from(1e10))).to.emit(
        test_pool,
        "NewAdminFee"
      );
    });

    it("Reverts when called by non-owners", async () => {
      await expect(test_pool.connect(user1).setSwapFee(0)).to.be.reverted;
      await expect(test_pool.connect(user2).setSwapFee(BigNumber.from(1e10))).to
        .be.reverted;
    });

    it("Reverts when adminFee is higher than the limit", async () => {
      await expect(test_pool.setAdminFee(BigNumber.from(1e10).add(1))).to.be
        .reverted;
    });

    it("Succeeds when adminFee is within the limit", async () => {
      await test_pool.setAdminFee(BigNumber.from(1e10));
      expect((await test_pool.swapStorage()).adminFee).to.eq(
        BigNumber.from(1e10)
      );
    });
  });

  describe("getAdminBalance", () => {
    it("Reverts with 'Token index out of range'", async () => {
      await expect(test_pool.getAdminBalance(3)).to.be.revertedWith(
        "Token index out of range"
      );
    });

    it("Is always 0 when adminFee is set to 0", async () => {
      expect(await test_pool.getAdminBalance(0)).to.eq(0);
      expect(await test_pool.getAdminBalance(1)).to.eq(0);

      await test_pool.connect(user1).swap(0, 1, String(1e17), 0, MAX_UINT256, {
        value: ethers.utils.parseEther("0.1"),
      });

      expect(await test_pool.getAdminBalance(0)).to.eq(0);
      expect(await test_pool.getAdminBalance(1)).to.eq(0);
    });

    it("Returns expected amounts after swaps when adminFee is higher than 0", async () => {
      // Sets adminFee to 1% of the swap fees
      await test_pool.setAdminFee(BigNumber.from(10 ** 8));

      await test_pool.connect(user1).swap(0, 1, String(1e17), 0, MAX_UINT256, {
        value: ethers.utils.parseEther("0.1"),
      });
      expect(await test_pool.getAdminBalance(0)).to.eq(0);
      expect(await test_pool.getAdminBalance(1)).to.eq(String(399338962149));

      // After the first swap, the pool becomes imbalanced; there are more 1st token than 2nd token in the pool.
      // Therefore swapping from 2nd -> 1st will result in more 1st token returned
      // Also results in higher fees collected on the second swap.

      await test_pool.connect(user1).swap(1, 0, String(1e17), 0, MAX_UINT256);

      expect(await test_pool.getAdminBalance(0)).to.eq(String(400660758190));
      expect(await test_pool.getAdminBalance(1)).to.eq(String(399338962149));
    });
  });

  describe("withdrawAdminFees", () => {
    it("Reverts when called by non-owners", async () => {
      await expect(test_pool.connect(user1).withdrawAdminFees()).to.be.reverted;
      await expect(test_pool.connect(user2).withdrawAdminFees()).to.be.reverted;
    });

    it("Succeeds when there are no fees withdrawn", async () => {
      // Sets adminFee to 1% of the swap fees
      await test_pool.setAdminFee(BigNumber.from(10 ** 8));

      const EtherBefore = await provider.getBalance(owner.address);
      const firstTokenBefore = await getUserTokenBalance(
        owner,
        randId,
        gETHReference
      );

      const tx = await test_pool.withdrawAdminFees();
      const receipt = await tx.wait();
      const gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);

      const EtherAfter = await provider.getBalance(owner.address);
      const firstTokenAfter = await getUserTokenBalance(
        owner,
        randId,
        gETHReference
      );
      expect(EtherBefore.sub(gasUsed)).to.eq(EtherAfter);
      expect(firstTokenBefore).to.eq(firstTokenAfter);
    });

    it("Succeeds with expected amount of fees withdrawn", async () => {
      // Sets adminFee to 1% of the swap fees
      await test_pool.setAdminFee(BigNumber.from(10 ** 8));
      await test_pool.connect(user1).swap(0, 1, String(1e17), 0, MAX_UINT256, {
        value: ethers.utils.parseEther("0.1"),
      });
      await test_pool.connect(user1).swap(1, 0, String(1e17), 0, MAX_UINT256);

      expect(await test_pool.getAdminBalance(0)).to.eq(String(400660758190));
      expect(await test_pool.getAdminBalance(1)).to.eq(String(399338962149));

      const EtherBefore = await provider.getBalance(owner.address);
      const firstTokenBefore = await getUserTokenBalance(
        owner,
        randId,
        gETHReference
      );

      const tx = await test_pool.withdrawAdminFees();
      const receipt = await tx.wait();
      const gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);

      const EtherAfter = await provider.getBalance(owner.address);

      const firstTokenAfter = await getUserTokenBalance(
        owner,
        randId,
        gETHReference
      );

      expect(EtherAfter.add(gasUsed).sub(EtherBefore)).to.eq(
        String(400660758190)
      );
      expect(firstTokenAfter.sub(firstTokenBefore)).to.eq(String(399338962149));
    });

    it("Withdrawing admin fees has no impact on users' withdrawal", async () => {
      // Sets adminFee to 1% of the swap fees
      await test_pool.setAdminFee(BigNumber.from(10 ** 8));
      await test_pool
        .connect(user1)
        .addLiquidity([String(1e18), String(1e18)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("1"),
        });

      for (let i = 0; i < 10; i++) {
        await test_pool
          .connect(user2)
          .swap(0, 1, String(1e17), 0, MAX_UINT256, {
            value: ethers.utils.parseEther("0.1"),
          });
        await test_pool.connect(user2).swap(1, 0, String(1e17), 0, MAX_UINT256);
      }

      await test_pool.withdrawAdminFees();
      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, MAX_UINT256);

      const EtherBefore = await provider.getBalance(user1.address);
      const firstTokenBefore = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      const user1LPTokenBalance = await test_pool_swapToken.balanceOf(
        user1Address
      );

      const tx = await test_pool
        .connect(user1)
        .removeLiquidity(user1LPTokenBalance, [0, 0], MAX_UINT256);
      const receipt = await tx.wait();
      const gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);

      const EtherAfter = await provider.getBalance(user1.address);

      const firstTokenAfter = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      expect(EtherAfter.add(gasUsed).sub(EtherBefore)).to.eq(
        BigNumber.from("999790899571521545")
      );

      expect(firstTokenAfter.sub(firstTokenBefore)).to.eq(
        BigNumber.from("1000605270122712963")
      );
    });
  });

  describe("addLiquidity", () => {
    it("Reverts when contract is paused", async () => {
      const beforePoolTokenAmount = await test_pool_swapToken.balanceOf(
        user1Address
      );
      await test_pool.pause();
      await expect(
        test_pool
          .connect(user1)
          .addLiquidity([String(1e18), String(3e18)], 0, MAX_UINT256, {
            value: ethers.utils.parseEther("1"),
          })
      ).to.be.reverted;
      const afterPoolTokenAmount = await test_pool_swapToken.balanceOf(
        user1Address
      );

      expect(afterPoolTokenAmount).to.eq(beforePoolTokenAmount);
      // unpause
      await test_pool.unpause();

      await test_pool
        .connect(user1)
        .addLiquidity([String(1e18), String(3e18)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("1"),
        });

      const finalPoolTokenAmount = await test_pool_swapToken.balanceOf(
        user1Address
      );

      expect(finalPoolTokenAmount).to.gt(beforePoolTokenAmount);
      expect(finalPoolTokenAmount).to.eq(BigNumber.from("3993470625071427531"));
    });

    it("Reverts with 'Amounts must match pooled tokens'", async () => {
      await expect(
        test_pool.connect(user1).addLiquidity([String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("1"),
        })
      ).to.be.revertedWith("Amounts must match pooled tokens");
    });

    it("Reverts with 'Cannot withdraw more than available'", async () => {
      await expect(
        test_pool
          .connect(user1)
          .calculateTokenAmount([MAX_UINT256, String(4e18)], false)
      ).to.be.revertedWith("Cannot withdraw more than available");
    });

    it("Reverts with 'Must supply all tokens in pool'", async () => {
      const PoolTokenAmount = await test_pool_swapToken.balanceOf(ownerAddress);
      test_pool_swapToken.approve(
        test_pool.address,
        PoolTokenAmount.toString()
      );
      await test_pool.removeLiquidity(
        PoolTokenAmount.toString(),
        [0, 0],
        MAX_UINT256
      );
      await test_pool_swapToken.balanceOf(ownerAddress);
      await expect(
        test_pool
          .connect(user1)
          .addLiquidity([String(0), String(3e18)], 0, MAX_UINT256)
      ).to.be.revertedWith("Must supply all tokens in pool");

      await expect(
        test_pool
          .connect(user1)
          .addLiquidity([String(2e18), String(0)], 0, MAX_UINT256, {
            value: ethers.utils.parseEther("2"),
          })
      ).to.be.revertedWith("Must supply all tokens in pool");
    });

    it("Succeeds with expected output amount of pool tokens", async () => {
      const calculatedPoolTokenAmount = await test_pool
        .connect(user1)
        .calculateTokenAmount([String(1e18), String(3e18)], true);

      const calculatedPoolTokenAmountWithSlippage = calculatedPoolTokenAmount
        .mul(999)
        .div(1000);

      await test_pool
        .connect(user1)
        .addLiquidity(
          [String(1e18), String(3e18)],
          calculatedPoolTokenAmountWithSlippage,
          MAX_UINT256,
          { value: ethers.utils.parseEther("1") }
        );

      const actualPoolTokenAmount = await test_pool_swapToken.balanceOf(
        user1Address
      );

      // The actual pool token amount is less than 5e18 due to the imbalance of the underlying tokens
      expect(actualPoolTokenAmount).to.eq(
        BigNumber.from("3993470625071427531")
      );
    });

    it("Succeeds with actual pool token amount being within ±0.1% range of calculated pool token", async () => {
      const calculatedPoolTokenAmount = await test_pool
        .connect(user1)
        .calculateTokenAmount([String(1e18), String(3e18)], true);

      const calculatedPoolTokenAmountWithNegativeSlippage =
        calculatedPoolTokenAmount.mul(999).div(1000);

      const calculatedPoolTokenAmountWithPositiveSlippage =
        calculatedPoolTokenAmount.mul(1001).div(1000);

      await test_pool
        .connect(user1)
        .addLiquidity(
          [String(1e18), String(3e18)],
          calculatedPoolTokenAmountWithNegativeSlippage,
          MAX_UINT256,
          { value: ethers.utils.parseEther("1") }
        );

      const actualPoolTokenAmount = await test_pool_swapToken.balanceOf(
        user1Address
      );

      expect(actualPoolTokenAmount).to.gte(
        calculatedPoolTokenAmountWithNegativeSlippage
      );

      expect(actualPoolTokenAmount).to.lte(
        calculatedPoolTokenAmountWithPositiveSlippage
      );
    });

    it("Succeeds with correctly updated tokenBalance after imbalanced deposit", async () => {
      await test_pool
        .connect(user1)
        .addLiquidity([String(1e18), String(3e18)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("1"),
        });

      // Check updated token balance
      const tokenBalance1 = await test_pool.getTokenBalance(0);
      expect(tokenBalance1).to.eq(BigNumber.from(String(2e18)));

      const tokenBalance2 = await test_pool.getTokenBalance(1);
      expect(tokenBalance2).to.eq(BigNumber.from(String(4e18)));
    });

    it("Returns correct minted lpToken amount", async () => {
      await gETHReference.mint(
        testSwapReturnValues.address,
        randId,
        String(1e20),
        utils.formatBytes32String("")
      );

      await testSwapReturnValues.test_addLiquidity(
        [String(1e18), String(1e18)],
        0,
        { value: ethers.utils.parseEther("1") }
      );
    });

    it("Reverts when minToMint is not reached due to front running", async () => {
      const calculatedLPTokenAmount = await test_pool
        .connect(user1)
        .calculateTokenAmount([String(1e18), String(3e18)], true);

      const calculatedLPTokenAmountWithSlippage = calculatedLPTokenAmount
        .mul(999)
        .div(1000);

      // Someone else deposits thus front running user 1's deposit
      await test_pool.addLiquidity(
        [String(1e19), String(3e19)],
        0,
        MAX_UINT256,
        { value: ethers.utils.parseEther("10") }
      );

      await expect(
        test_pool
          .connect(user1)
          .addLiquidity(
            [String(1e18), String(3e18)],
            calculatedLPTokenAmountWithSlippage,
            MAX_UINT256,
            { value: ethers.utils.parseEther("1") }
          )
      ).to.be.reverted;
    });

    it("Reverts when block is mined after deadline", async () => {
      const currentTimestamp = await getCurrentBlockTimestamp();

      await setNextTimestamp(currentTimestamp + 60 * 10);
      await expect(
        test_pool
          .connect(user1)
          .addLiquidity(
            [String(1e16), String(1e16)],
            0,
            currentTimestamp + 60 * 5,
            { value: ethers.utils.parseEther("0.01") }
          )
      ).to.be.revertedWith("Deadline not met");
    });

    it("Emits addLiquidity event", async () => {
      const calculatedLPTokenAmount = await test_pool
        .connect(user1)
        .calculateTokenAmount([String(1e16), String(1e16)], true);

      const calculatedLPTokenAmountWithSlippage = calculatedLPTokenAmount
        .mul(999)
        .div(1000);

      await expect(
        test_pool
          .connect(user1)
          .addLiquidity(
            [String(1e16), String(1e16)],
            calculatedLPTokenAmountWithSlippage,
            MAX_UINT256,
            { value: ethers.utils.parseEther("0.01") }
          )
      ).to.emit(test_pool.connect(user1), "AddLiquidity");
    });
  });

  describe("removeLiquidity", () => {
    it("Reverts with 'Cannot exceed total supply'", async () => {
      await expect(
        test_pool.calculateRemoveLiquidity(MAX_UINT256)
      ).to.be.revertedWith("Cannot exceed total supply");
    });

    it("Reverts with 'minAmounts must match poolTokens'", async () => {
      await expect(
        test_pool.removeLiquidity(String(2e18), [0], MAX_UINT256)
      ).to.be.revertedWith("minAmounts must match poolTokens");
    });

    it("Succeeds even when contract is paused", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(1e16), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.01"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("20000000000000000"));

      // Owner pauses the contract
      await test_pool.pause();

      // Owner and user 1 try to remove liquidity
      test_pool_swapToken.approve(test_pool.address, String(3e18));
      test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);

      await test_pool.removeLiquidity(String(2e18), [0, 0], MAX_UINT256);
      await test_pool
        .connect(user1)
        .removeLiquidity(currentUser1Balance, [0, 0], MAX_UINT256);

      await test_pool.unpause();
      expect(await gETHReference.balanceOf(test_pool.address, randId)).to.eq(0);
      expect(await provider.getBalance(test_pool.address)).to.eq(0);
    });

    it("Succeeds with expected return amounts of underlying tokens", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e16), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.02"),
        });

      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, MAX_UINT256);

      const firstTokenBalanceBefore = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      poolTokenBalanceBefore = await test_pool_swapToken.balanceOf(
        user1Address
      );

      expect(poolTokenBalanceBefore).to.eq(BigNumber.from("29997596210674143"));

      const [expectedZerothTokenAmount, expectedFirstTokenAmount] =
        await test_pool.calculateRemoveLiquidity(poolTokenBalanceBefore);

      expect(expectedZerothTokenAmount).to.eq(
        BigNumber.from("15072701658367972")
      );

      expect(expectedFirstTokenAmount).to.eq(
        BigNumber.from("14924930073482011")
      );

      await test_pool
        .connect(user1)
        .removeLiquidity(
          poolTokenBalanceBefore,
          [expectedZerothTokenAmount, expectedFirstTokenAmount],
          MAX_UINT256
        );

      const firstTokenBalanceAfter = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      // Check the actual returned token amounts match the expected amounts

      expect(firstTokenBalanceAfter.sub(firstTokenBalanceBefore)).to.eq(
        expectedFirstTokenAmount
      );
    });

    it("Returns correct amounts of received tokens", async () => {
      await gETHReference.mint(
        testSwapReturnValues.address,
        randId,
        String(1e20),
        utils.formatBytes32String("")
      );

      await testSwapReturnValues.test_addLiquidity(
        [String(1e18), String(2e18)],
        0,
        { value: ethers.utils.parseEther("1") }
      );

      const tokenBalance = await test_pool_swapToken.balanceOf(
        testSwapReturnValues.address
      );

      await testSwapReturnValues.test_removeLiquidity(tokenBalance, [0, 0]);
    });

    it("Reverts when user tries to burn more LP tokens than they own", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      await expect(
        test_pool
          .connect(user1)
          .removeLiquidity(currentUser1Balance.add(1), [0, 0], MAX_UINT256)
      ).to.be.revertedWith(">LP.balanceOf");
    });

    it("Reverts when minAmounts of underlying tokens are not reached due to front running", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      const [expectedZerothTokenAmount, expectedFirstTokenAmount] =
        await test_pool.calculateRemoveLiquidity(currentUser1Balance);

      expect(expectedZerothTokenAmount).to.eq(
        BigNumber.from("1499604416679853312")
      );
      expect(expectedFirstTokenAmount).to.eq(
        BigNumber.from("504866820282217281")
      );

      // User 2 adds liquidity, which leads to change in balance of underlying tokens
      await test_pool
        .connect(user2)
        .addLiquidity([String(1e16), String(2e18)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.01"),
        });

      // User 1 tries to remove liquidity which get reverted due to front running
      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);
      await expect(
        test_pool
          .connect(user1)
          .removeLiquidity(
            currentUser1Balance,
            [expectedZerothTokenAmount, expectedFirstTokenAmount],
            MAX_UINT256
          )
      ).to.be.revertedWith("amounts[i] < minAmounts[i]");
    });

    it("Reverts when block is mined after deadline", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );

      const currentTimestamp = await getCurrentBlockTimestamp();
      await setNextTimestamp(currentTimestamp + 60 * 10);

      // User 1 tries removing liquidity with deadline of +5 minutes
      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);
      await expect(
        test_pool
          .connect(user1)
          .removeLiquidity(
            currentUser1Balance,
            [0, 0],
            currentTimestamp + 60 * 5
          )
      ).to.be.revertedWith("Deadline not met");
    });

    it("Emits removeLiquidity event", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );

      // User 1 tries removes liquidity
      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);
      await expect(
        test_pool
          .connect(user1)
          .removeLiquidity(currentUser1Balance, [0, 0], MAX_UINT256)
      ).to.emit(test_pool.connect(user1), "RemoveLiquidity");
    });
  });

  describe("removeLiquidityImbalance", () => {
    it("Reverts when contract is paused", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      // Owner pauses the contract
      await test_pool.pause();

      // Owner and user 1 try to initiate imbalanced liquidity withdrawal
      test_pool_swapToken.approve(test_pool.address, MAX_UINT256);
      test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, MAX_UINT256);

      await expect(
        test_pool.removeLiquidityImbalance(
          [String(1e18), String(1e16)],
          randId,
          MAX_UINT256
        )
      ).to.be.revertedWith("Pausable: paused");

      await expect(
        test_pool
          .connect(user1)
          .removeLiquidityImbalance(
            [String(1e18), String(1e16)],
            randId,
            MAX_UINT256
          )
      ).to.be.revertedWith("Pausable: paused");
    });
    it("Reverts with 'Amounts should match pool tokens'", async () => {
      await expect(
        test_pool.removeLiquidityImbalance(
          [String(2e18), String(2e18), String(1e16)],
          randId,
          MAX_UINT256
        )
      ).to.be.revertedWith("Amounts should match pool tokens");
    });

    it("Reverts with 'Cannot withdraw more than available'", async () => {
      await expect(
        test_pool.removeLiquidityImbalance(
          [MAX_UINT256, MAX_UINT256],
          randId,
          MAX_UINT256
        )
      ).to.be.revertedWith("Cannot withdraw more than available");
    });

    it("Succeeds with calculated max amount of pool token to be burned (±0.1%)", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      // User 1 calculates amount of pool token to be burned
      const maxPoolTokenAmountToBeBurned = await test_pool.calculateTokenAmount(
        [String(1e18), String(1e16)],
        false
      );

      // ±0.1% range of pool token to be burned
      const maxPoolTokenAmountToBeBurnedNegativeSlippage =
        maxPoolTokenAmountToBeBurned.mul(1001).div(1000);
      const maxPoolTokenAmountToBeBurnedPositiveSlippage =
        maxPoolTokenAmountToBeBurned.mul(999).div(1000);
      await test_pool_swapToken
        .connect(user1)
        .approve(
          test_pool.address,
          maxPoolTokenAmountToBeBurnedNegativeSlippage
        );

      const EtherBefore = await provider.getBalance(user1.address);
      const firstTokenBalanceBefore = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      poolTokenBalanceBefore = await test_pool_swapToken.balanceOf(
        user1.address
      );

      // User 1 withdraws imbalanced tokens

      const tx = await test_pool
        .connect(user1)
        .removeLiquidityImbalance(
          [String(1e18), String(1e16)],
          maxPoolTokenAmountToBeBurnedNegativeSlippage,
          MAX_UINT256
        );
      const receipt = await tx.wait();
      const gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);

      const EtherAfter = await provider.getBalance(user1.address);
      const firstTokenBalanceAfter = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      poolTokenBalanceAfter = await test_pool_swapToken.balanceOf(user1Address);

      // Check the actual returned token amounts match the requested amounts
      expect(EtherAfter.add(gasUsed).sub(EtherBefore)).to.eq(String(1e18));
      expect(firstTokenBalanceAfter.sub(firstTokenBalanceBefore)).to.eq(
        String(1e16)
      );

      // Check the actual burned pool token amount
      const actualPoolTokenBurned = poolTokenBalanceBefore.sub(
        poolTokenBalanceAfter
      );

      expect(actualPoolTokenBurned).to.eq(String("1002407694457888552"));
      expect(actualPoolTokenBurned).to.gte(
        maxPoolTokenAmountToBeBurnedPositiveSlippage
      );
      expect(actualPoolTokenBurned).to.lte(
        maxPoolTokenAmountToBeBurnedNegativeSlippage
      );
    });

    it("Returns correct amount of burned lpToken", async () => {
      await gETHReference.mint(
        testSwapReturnValues.address,
        randId,
        String(1e20),
        utils.formatBytes32String("")
      );

      await testSwapReturnValues.test_addLiquidity(
        [String(1e18), String(2e18)],
        0,
        { value: ethers.utils.parseEther("1") }
      );

      const tokenBalance = await test_pool_swapToken.balanceOf(
        testSwapReturnValues.address
      );
      await testSwapReturnValues.test_removeLiquidityImbalance(
        [String(1e18), String(1e17)],
        tokenBalance
      );
    });

    it("Reverts when user tries to burn more LP tokens than they own", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      await expect(
        test_pool
          .connect(user1)
          .removeLiquidityImbalance(
            [String(1e18), String(1e16)],
            currentUser1Balance.add(1),
            MAX_UINT256
          )
      ).to.be.revertedWith(">LP.balanceOf");
    });

    it("Reverts when minAmounts of underlying tokens are not reached due to front running", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      // User 1 calculates amount of pool token to be burned
      const maxPoolTokenAmountToBeBurned = await test_pool.calculateTokenAmount(
        [String(1e18), String(1e16)],
        false
      );

      // Calculate +0.1% of pool token to be burned
      const maxPoolTokenAmountToBeBurnedNegativeSlippage =
        maxPoolTokenAmountToBeBurned.mul(1001).div(1000);

      // User 2 adds liquidity, which leads to change in balance of underlying tokens
      await test_pool
        .connect(user2)
        .addLiquidity([String(1e16), String(1e20)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.01"),
        });

      // User 1 tries to remove liquidity which get reverted due to front running
      await test_pool_swapToken
        .connect(user1)
        .approve(
          test_pool.address,
          maxPoolTokenAmountToBeBurnedNegativeSlippage
        );
      await expect(
        test_pool
          .connect(user1)
          .removeLiquidityImbalance(
            [String(1e18), String(1e16)],
            maxPoolTokenAmountToBeBurnedNegativeSlippage,
            MAX_UINT256
          )
      ).to.be.revertedWith("tokenAmount > maxBurnAmount");
    });

    it("Reverts when block is mined after deadline", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );

      const currentTimestamp = await getCurrentBlockTimestamp();
      await setNextTimestamp(currentTimestamp + 60 * 10);

      // User 1 tries removing liquidity with deadline of +5 minutes
      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);
      await expect(
        test_pool
          .connect(user1)
          .removeLiquidityImbalance(
            [String(1e18), String(1e16)],
            currentUser1Balance,
            currentTimestamp + 60 * 5
          )
      ).to.be.revertedWith("Deadline not met");
    });

    it("Emits RemoveLiquidityImbalance event", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );

      // User 1 removes liquidity
      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, MAX_UINT256);

      await expect(
        test_pool
          .connect(user1)
          .removeLiquidityImbalance(
            [String(1e18), String(1e16)],
            currentUser1Balance,
            MAX_UINT256
          )
      ).to.emit(test_pool.connect(user1), "RemoveLiquidityImbalance");
    });
  });

  describe("removeLiquidityOneToken", () => {
    it("Reverts when contract is paused", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      // Owner pauses the contract
      await test_pool.pause();

      // Owner and user 1 try to remove liquidity via single token
      test_pool_swapToken.approve(test_pool.address, String(3e18));
      test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);

      await expect(
        test_pool.removeLiquidityOneToken(String(2e18), 0, 0, MAX_UINT256)
      ).to.be.revertedWith("Pausable: paused");
      await expect(
        test_pool
          .connect(user1)
          .removeLiquidityOneToken(currentUser1Balance, 0, 0, MAX_UINT256)
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Reverts with 'Token index out of range'", async () => {
      await expect(
        test_pool.calculateRemoveLiquidityOneToken(1, 5)
      ).to.be.revertedWith("Token index out of range");
    });

    it("Reverts with 'Withdraw exceeds available'", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      await expect(
        test_pool.calculateRemoveLiquidityOneToken(
          currentUser1Balance.mul(2),
          0
        )
      ).to.be.revertedWith("Withdraw exceeds available");

      await expect(
        test_pool
          .connect(user1)
          .calculateRemoveLiquidityOneToken(currentUser1Balance.mul(2), 0)
      ).to.be.revertedWith("Withdraw exceeds available");
    });

    it("Reverts with 'Token not found'", async () => {
      await expect(
        test_pool.connect(user1).removeLiquidityOneToken(0, 9, 1, MAX_UINT256)
      ).to.be.revertedWith("Token not found");
    });

    it("Ether: Succeeds with calculated token amount as minAmount", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      // User 1 calculates the amount of underlying token to receive.
      const calculatedZerothTokenAmount =
        await test_pool.calculateRemoveLiquidityOneToken(
          currentUser1Balance,
          0
        );

      expect(calculatedZerothTokenAmount).to.eq(
        BigNumber.from("2009595512856245490")
      );

      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);

      // User 1 initiates one token withdrawal
      const before = await provider.getBalance(user1.address);

      const tx = await test_pool
        .connect(user1)
        .removeLiquidityOneToken(
          currentUser1Balance,
          0,
          calculatedZerothTokenAmount,
          MAX_UINT256
        );
      const receipt = await tx.wait();
      const gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);

      const after = await provider.getBalance(user1.address);

      expect(after.add(gasUsed).sub(before)).to.eq(
        BigNumber.from("2009595512856245490")
      );
    });

    it("gETH: Succeeds with calculated token amount as minAmount", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(1e16), String(2e18)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.01"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      // User 1 calculates the amount of underlying token to receive.
      const calculatedTokenAmount =
        await test_pool.calculateRemoveLiquidityOneToken(
          currentUser1Balance,
          1
        );

      expect(calculatedTokenAmount).to.eq(
        BigNumber.from("2009595512856245490")
      );

      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);

      // User 1 initiates one token withdrawal
      const before = await gETHReference.balanceOf(user1Address, randId);

      await test_pool
        .connect(user1)
        .removeLiquidityOneToken(
          currentUser1Balance,
          1,
          calculatedTokenAmount,
          MAX_UINT256
        );

      const after = await gETHReference.balanceOf(user1Address, randId);

      expect(after.sub(before)).to.eq(BigNumber.from("2009595512856245490"));
    });

    it("Returns correct amount of received token", async () => {
      await gETHReference.mint(
        testSwapReturnValues.address,
        randId,
        String(1e20),
        utils.formatBytes32String("")
      );

      await testSwapReturnValues.test_addLiquidity(
        [String(1e18), String(2e18)],
        0,
        { value: ethers.utils.parseEther("1") }
      );

      await testSwapReturnValues.test_removeLiquidityOneToken(
        String(1e18),
        0,
        0
      );
      await testSwapReturnValues.test_removeLiquidityOneToken(
        String(5e17),
        1,
        0
      );
    });

    it("Reverts when user tries to burn more LP tokens than they own", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      await expect(
        test_pool
          .connect(user1)
          .removeLiquidityOneToken(
            currentUser1Balance.add(1),
            0,
            0,
            MAX_UINT256
          )
      ).to.be.revertedWith(">LP.balanceOf");
    });

    it("Reverts when minAmount of underlying token is not reached due to front running", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );
      expect(currentUser1Balance).to.eq(BigNumber.from("1998945389270551378"));

      // User 1 calculates the amount of underlying token to receive.
      const calculatedFirstTokenAmount =
        await test_pool.calculateRemoveLiquidityOneToken(
          currentUser1Balance,
          0
        );
      expect(calculatedFirstTokenAmount).to.eq(
        BigNumber.from("2009595512856245490")
      );

      // User 2 adds liquidity before User 1 initiates withdrawal
      await test_pool
        .connect(user2)
        .addLiquidity([String(1e16), String(1e20)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.01"),
        });

      // User 1 initiates one token withdrawal
      test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);
      await expect(
        test_pool
          .connect(user1)
          .removeLiquidityOneToken(
            currentUser1Balance,
            0,
            calculatedFirstTokenAmount,
            MAX_UINT256
          )
      ).to.be.revertedWith("dy < minAmount");
    });

    it("Reverts when block is mined after deadline", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );

      const currentTimestamp = await getCurrentBlockTimestamp();
      await setNextTimestamp(currentTimestamp + 60 * 10);

      // User 1 tries removing liquidity with deadline of +5 minutes
      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);
      await expect(
        test_pool
          .connect(user1)
          .removeLiquidityOneToken(
            currentUser1Balance,
            0,
            0,
            currentTimestamp + 60 * 5
          )
      ).to.be.revertedWith("Deadline not met");
    });

    it("Emits RemoveLiquidityOne event", async () => {
      // User 1 adds liquidity
      await test_pool
        .connect(user1)
        .addLiquidity([String(2e18), String(1e16)], 0, MAX_UINT256, {
          value: ethers.utils.parseEther("2"),
        });
      const currentUser1Balance = await test_pool_swapToken.balanceOf(
        user1Address
      );

      await test_pool_swapToken
        .connect(user1)
        .approve(test_pool.address, currentUser1Balance);
      await expect(
        test_pool
          .connect(user1)
          .removeLiquidityOneToken(currentUser1Balance, 0, 0, MAX_UINT256)
      ).to.emit(test_pool.connect(user1), "RemoveLiquidityOne");
    });
  });

  describe("swap", () => {
    it("Reverts when contract is paused", async () => {
      // Owner pauses the contract
      await test_pool.pause();

      // User 1 try to initiate swap
      await expect(
        test_pool.connect(user1).swap(0, 1, String(1e16), 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.01"),
        })
      ).to.be.revertedWith("Pausable: paused");

      await expect(
        test_pool.connect(user1).swap(1, 0, String(1e16), 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.01"),
        })
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Reverts with 'Token index out of range'", async () => {
      await expect(
        test_pool.calculateSwap(0, 9, String(1e17))
      ).to.be.revertedWith("Token index out of range");
    });

    it("Reverts with 'Cannot swap more/less than you sent'", async () => {
      await expect(
        test_pool.connect(user1).swap(0, 1, MAX_UINT256, 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.01"),
        })
      ).to.be.revertedWith("Cannot swap more/less than you sent");

      await expect(
        test_pool.connect(user1).swap(1, 0, MAX_UINT256, 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.01"),
        })
      ).to.be.revertedWith("Cannot swap more than you own");
    });

    it("Succeeds with expected swap amounts (Ether => gEther)", async () => {
      // User 1 calculates how much token to receive
      const calculatedSwapReturn = await test_pool.calculateSwap(
        0,
        1,
        String(1e17)
      );
      expect(calculatedSwapReturn).to.eq(BigNumber.from("99794806641066759"));

      const tokenFromBalanceBefore = await provider.getBalance(user1.address);
      const tokenToBalanceBefore = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      // User 1 successfully initiates swap
      const tx = await test_pool
        .connect(user1)
        .swap(0, 1, String(1e17), calculatedSwapReturn, MAX_UINT256, {
          value: ethers.utils.parseEther("0.1"),
        });
      const receipt = await tx.wait();
      const gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);

      const tokenFromBalanceAfter = await provider.getBalance(user1.address);
      // Check the sent and received amounts are as expected
      const tokenToBalanceAfter = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      expect(
        tokenFromBalanceBefore.sub(tokenFromBalanceAfter.add(gasUsed))
      ).to.eq(BigNumber.from(String(1e17)));

      expect(tokenToBalanceAfter.sub(tokenToBalanceBefore)).to.eq(
        calculatedSwapReturn
      );
    });

    it("Succeeds with expected swap amounts (gEther => Ether)", async () => {
      // User 1 calculates how much token to receive
      const calculatedSwapReturn = await test_pool.calculateSwap(
        1,
        0,
        String(1e17)
      );
      expect(calculatedSwapReturn).to.eq(BigNumber.from("99794806641066759"));

      const tokenToBalanceBefore = await provider.getBalance(user1.address);
      const tokenFromBalanceBefore = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      // User 1 successfully initiates swap
      const tx = await test_pool
        .connect(user1)
        .swap(1, 0, String(1e17), calculatedSwapReturn, MAX_UINT256, {});
      const receipt = await tx.wait();
      const gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);

      const tokenToBalanceAfter = await provider.getBalance(user1.address);
      // Check the sent and received amounts are as expected
      const tokenFromBalanceAfter = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      expect(tokenFromBalanceBefore.sub(tokenFromBalanceAfter)).to.eq(
        BigNumber.from(String(1e17))
      );

      expect(tokenToBalanceAfter.sub(tokenToBalanceBefore).add(gasUsed)).to.eq(
        calculatedSwapReturn
      );
    });

    it("Succeeds when using lower minDy even when transaction is front-ran", async () => {
      // User 1 calculates how much token to receive with 1% slippage
      const calculatedSwapReturn = await test_pool.calculateSwap(
        0,
        1,
        String(1e17)
      );
      expect(calculatedSwapReturn).to.eq(BigNumber.from("99794806641066759"));

      const tokenFromBalanceBefore = await provider.getBalance(user1.address);
      const tokenToBalanceBefore = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      const calculatedSwapReturnWithNegativeSlippage = calculatedSwapReturn
        .mul(99)
        .div(100);

      // User 2 swaps before User 1 does
      await test_pool.connect(user2).swap(0, 1, String(1e17), 0, MAX_UINT256, {
        value: ethers.utils.parseEther("0.1"),
      });

      // User 1 successfully initiates swap with 1% slippage from initial calculated amount
      const tx = await test_pool
        .connect(user1)
        .swap(
          0,
          1,
          String(1e17),
          calculatedSwapReturnWithNegativeSlippage,
          MAX_UINT256,
          {
            value: ethers.utils.parseEther("0.1"),
          }
        );
      const receipt = await tx.wait();
      const gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);

      // Check the sent and received amounts are as expected
      const tokenFromBalanceAfter = await provider.getBalance(user1.address);
      const tokenToBalanceAfter = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      expect(
        tokenFromBalanceBefore.sub(tokenFromBalanceAfter.add(gasUsed))
      ).to.eq(BigNumber.from(String(1e17)));

      const actualReceivedAmount =
        tokenToBalanceAfter.sub(tokenToBalanceBefore);

      expect(actualReceivedAmount).to.eq(BigNumber.from("99445844521513912"));
      expect(actualReceivedAmount).to.gt(
        calculatedSwapReturnWithNegativeSlippage
      );
      expect(actualReceivedAmount).to.lt(calculatedSwapReturn);
    });

    it("Succeeds when using lower minDy even when transaction is front-ran gEther => Ether", async () => {
      // User 1 calculates how much token to receive with 1% slippage
      const calculatedSwapReturn = await test_pool.calculateSwap(
        1,
        0,
        String(1e17)
      );
      expect(calculatedSwapReturn).to.eq(BigNumber.from("99794806641066759"));

      const tokenToBalanceBefore = await provider.getBalance(user1.address);
      const tokenFromBalanceBefore = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      const calculatedSwapReturnWithNegativeSlippage = calculatedSwapReturn
        .mul(99)
        .div(100);

      // User 2 swaps before User 1 does
      await test_pool.connect(user2).swap(1, 0, String(1e17), 0, MAX_UINT256);

      // User 1 successfully initiates swap with 1% slippage from initial calculated amount
      const tx = await test_pool
        .connect(user1)
        .swap(
          1,
          0,
          String(1e17),
          calculatedSwapReturnWithNegativeSlippage,
          MAX_UINT256
        );
      const receipt = await tx.wait();
      const gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);

      // Check the sent and received amounts are as expected
      const tokenToBalanceAfter = await provider.getBalance(user1.address);
      const tokenFromBalanceAfter = await getUserTokenBalance(
        user1,
        randId,
        gETHReference
      );

      expect(tokenFromBalanceBefore.sub(tokenFromBalanceAfter)).to.eq(
        BigNumber.from(String(1e17))
      );

      const actualReceivedAmount = tokenToBalanceAfter
        .add(gasUsed)
        .sub(tokenToBalanceBefore);

      expect(actualReceivedAmount).to.eq(BigNumber.from("99445844521513912"));
      expect(actualReceivedAmount).to.gt(
        calculatedSwapReturnWithNegativeSlippage
      );
      expect(actualReceivedAmount).to.lt(calculatedSwapReturn);
    });

    it("Reverts when minDy (minimum amount token to receive) is not reached due to front running", async () => {
      // User 1 calculates how much token to receive
      const calculatedSwapReturn = await test_pool.calculateSwap(
        0,
        1,
        String(1e17)
      );
      expect(calculatedSwapReturn).to.eq(BigNumber.from("99794806641066759"));

      // User 2 swaps before User 1 does
      await test_pool.connect(user2).swap(0, 1, String(1e17), 0, MAX_UINT256, {
        value: ethers.utils.parseEther("0.1"),
      });

      // User 1 initiates swap
      await expect(
        test_pool
          .connect(user1)
          .swap(0, 1, String(1e17), calculatedSwapReturn, MAX_UINT256, {
            value: ethers.utils.parseEther("0.1"),
          })
      ).to.be.revertedWith("Swap didn't result in min tokens");
    });

    it("Returns correct amount of received token Ether => gEther", async () => {
      await gETHReference.mint(
        testSwapReturnValues.address,
        randId,
        String(1e20),
        utils.formatBytes32String("")
      );

      await testSwapReturnValues.test_addLiquidity(
        [String(1e18), String(2e18)],
        0,
        { value: ethers.utils.parseEther("1") }
      );
      await testSwapReturnValues.test_swap(0, 1, String(1e18), 0, {
        value: ethers.utils.parseEther("1"),
      });
    });

    it("Returns correct amount of received token gEther => Ether", async () => {
      await gETHReference.mint(
        testSwapReturnValues.address,
        randId,
        String(1e20),
        utils.formatBytes32String("")
      );

      await testSwapReturnValues.test_addLiquidity(
        [String(2e18), String(2e18)],
        0,
        { value: ethers.utils.parseEther("2") }
      );

      await testSwapReturnValues.test_swap(1, 0, String(1e18), 0);
    });

    it("Reverts when block is mined after deadline", async () => {
      const currentTimestamp = await getCurrentBlockTimestamp();
      await setNextTimestamp(currentTimestamp + 60 * 10);

      // User 1 tries swapping with deadline of +5 minutes
      await expect(
        test_pool
          .connect(user1)
          .swap(0, 1, String(1e17), 0, currentTimestamp + 60 * 5, {})
      ).to.be.revertedWith("Deadline not met");

      await expect(
        test_pool
          .connect(user1)
          .swap(1, 0, String(1e17), 0, currentTimestamp + 60 * 5, {})
      ).to.be.revertedWith("Deadline not met");
    });

    it("Emits TokenSwap event", async () => {
      // User 1 initiates swap
      await expect(
        test_pool.connect(user1).swap(0, 1, String(1e17), 0, MAX_UINT256, {
          value: ethers.utils.parseEther("0.1"),
        })
      ).to.emit(test_pool, "TokenSwap");

      await expect(
        test_pool.connect(user1).swap(1, 0, String(1e17), 0, MAX_UINT256)
      ).to.emit(test_pool, "TokenSwap");
    });
  });

  describe("rampA", () => {
    beforeEach(async () => {
      await forceAdvanceOneBlock();
    });

    it("Emits RampA event", async () => {
      await expect(
        test_pool.rampA(
          100,
          (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1
        )
      ).to.emit(test_pool, "RampA");
    });

    it("Succeeds to ramp upwards", async () => {
      // Create imbalanced pool to measure virtual price change
      // We expect virtual price to increase as A decreases
      await test_pool.addLiquidity([String(1e18), 0], 0, MAX_UINT256, {
        value: ethers.utils.parseEther("1"),
      });

      // call rampA(), changing A to 100 within a span of 14 days
      const endTimestamp =
        (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1;
      await test_pool.rampA(100, endTimestamp);

      // +0 seconds since ramp A
      expect(await test_pool.getA()).to.be.eq(60);
      expect(await test_pool.getAPrecise()).to.be.eq(6000);
      expect(await test_pool.getVirtualPrice()).to.be.eq("1000066822646615457");

      // set timestamp to +100000 seconds
      await setTimestamp((await getCurrentBlockTimestamp()) + 100000);
      expect(await test_pool.getA()).to.be.eq(63);
      expect(await test_pool.getAPrecise()).to.be.eq(6330);
      expect(await test_pool.getVirtualPrice()).to.be.eq("1000119154175111724");

      // set timestamp to the end of ramp period
      await setTimestamp(endTimestamp);
      expect(await test_pool.getA()).to.be.eq(100);
      expect(await test_pool.getAPrecise()).to.be.eq(10000);
      expect(await test_pool.getVirtualPrice()).to.be.eq("1000471070200386269");
    });

    it("Succeeds to ramp downwards", async () => {
      // Create imbalanced pool to measure virtual price change
      // We expect virtual price to decrease as A decreases
      await test_pool.addLiquidity([String(1e18), 0], 0, MAX_UINT256, {
        value: ethers.utils.parseEther("1"),
      });

      // call rampA()
      const endTimestamp =
        (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1;
      await test_pool.rampA(30, endTimestamp);

      // +0 seconds since ramp A
      expect(await test_pool.getA()).to.be.eq(60);
      expect(await test_pool.getAPrecise()).to.be.eq(6000);
      expect(await test_pool.getVirtualPrice()).to.be.eq("1000066822646615457");

      // set timestamp to +100000 seconds
      await setTimestamp((await getCurrentBlockTimestamp()) + 100000);
      expect(await test_pool.getA()).to.be.eq(57);
      expect(await test_pool.getAPrecise()).to.be.eq(5752);
      expect(await test_pool.getVirtualPrice()).to.be.eq("1000023622369635453");

      // set timestamp to the end of ramp period
      await setTimestamp(endTimestamp);
      expect(await test_pool.getA()).to.be.eq(30);
      expect(await test_pool.getAPrecise()).to.be.eq(3000);
      expect(await test_pool.getVirtualPrice()).to.be.eq("999083006036060718");
    });

    it("Reverts when non-owner calls it", async () => {
      await expect(
        test_pool
          .connect(user1)
          .rampA(55, (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1)
      ).to.be.reverted;
    });

    it("Reverts with 'Wait 1 day before starting ramp'", async () => {
      await test_pool.rampA(
        55,
        (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1
      );
      await expect(
        test_pool.rampA(
          55,
          (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1
        )
      ).to.be.revertedWith("Wait 1 day before starting ramp");
    });

    it("Reverts with 'Insufficient ramp time'", async () => {
      await expect(
        test_pool.rampA(
          55,
          (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS - 1
        )
      ).to.be.revertedWith("Insufficient ramp time");
    });

    it("Reverts with 'futureA_ must be > 0 and < MAX_A'", async () => {
      await expect(
        test_pool.rampA(
          0,
          (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1
        )
      ).to.be.revertedWith("futureA_ must be > 0 and < MAX_A");
    });

    it("Reverts with 'futureA_ is too small'", async () => {
      await expect(
        test_pool.rampA(
          24,
          (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1
        )
      ).to.be.revertedWith("futureA_ is too small");
    });

    it("Reverts with 'futureA_ is too large'", async () => {
      await expect(
        test_pool.rampA(
          121,
          (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1
        )
      ).to.be.revertedWith("futureA_ is too large");
    });
  });

  describe("stopRampA", () => {
    it("Emits StopRampA event", async () => {
      // call rampA()
      await test_pool.rampA(
        100,
        (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 100
      );

      // Stop ramp
      expect(test_pool.stopRampA()).to.emit(test_pool, "StopRampA");
    });

    it("Stop ramp succeeds", async () => {
      // call rampA()
      const endTimestamp =
        (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 100;
      await test_pool.rampA(100, endTimestamp);

      // set timestamp to +100000 seconds
      await setTimestamp((await getCurrentBlockTimestamp()) + 100000);
      expect(await test_pool.getA()).to.be.eq(63);
      expect(await test_pool.getAPrecise()).to.be.eq(6330);

      // Stop ramp
      await test_pool.stopRampA();
      expect(await test_pool.getA()).to.be.eq(63);
      expect(await test_pool.getAPrecise()).to.be.eq(6330);

      // set timestamp to endTimestamp
      await setTimestamp(endTimestamp);

      // verify ramp has stopped
      expect(await test_pool.getA()).to.be.eq(63);
      expect(await test_pool.getAPrecise()).to.be.eq(6330);
    });

    it("Reverts with 'Ramp is already stopped'", async () => {
      // call rampA()
      const endTimestamp =
        (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 100;
      await test_pool.rampA(100, endTimestamp);

      // set timestamp to +10000 seconds
      await setTimestamp((await getCurrentBlockTimestamp()) + 100000);
      expect(await test_pool.getA()).to.be.eq(63);
      expect(await test_pool.getAPrecise()).to.be.eq(6330);

      // Stop ramp
      await test_pool.stopRampA();
      expect(await test_pool.getA()).to.be.eq(63);
      expect(await test_pool.getAPrecise()).to.be.eq(6330);

      // check call reverts when ramp is already stopped
      await expect(test_pool.stopRampA()).to.be.revertedWith(
        "Ramp is already stopped"
      );
    });
  });

  describe("getDebt", async () => {
    describe("When no swap fee", async () => {
      beforeEach(async () => {
        await test_pool.setSwapFee(BigNumber.from(0));
      });

      it("Debt must be zero when Ether > gEther", async () => {
        await test_pool
          .connect(user1)
          .addLiquidity([String(2e18), String(1e18)], 0, MAX_UINT256, {
            value: ethers.utils.parseEther("2"),
          });

        expect(await test_pool.getDebt()).to.be.eq(0);
      });

      it("Debt must be non-zero when Ether < gEther", async () => {
        await test_pool
          .connect(user1)
          .addLiquidity([String(1e18), String(2e18)], 0, MAX_UINT256, {
            value: ethers.utils.parseEther("1"),
          });

        expect(await test_pool.getDebt()).to.be.eq("499147041342998336");
      });

      describe("Pool should be balanced after the debt was paid.", async () => {
        beforeEach(async () => {
          await test_pool.addLiquidity(
            [String(1e18), String(2e18)],
            0,
            MAX_UINT256,
            {
              value: ethers.utils.parseEther("1"),
            }
          );
        });

        it("price=1", async () => {
          const debt = await test_pool.getDebt();
          expect(debt).to.be.eq("499147041342998336");

          const expectedDY = await test_pool.calculateSwap(0, 1, debt);
          expect(expectedDY).to.be.eq("500852958657001662");

          await test_pool.connect(user1).swap(0, 1, debt, 0, MAX_UINT256, {
            value: debt,
          });

          const tokenBalance1 = await test_pool.getTokenBalance(0);
          const tokenBalance2 = await test_pool.getTokenBalance(1);

          expect(
            tokenBalance1.mul(String(1e18)).div(tokenBalance2).add(1)
          ).to.be.eq(String(1e18));
          expect(await test_pool.getDebt()).to.be.lte(10);
        });

        it("price=1.2", async () => {
          await gETHReference.setPricePerShare(String(12e17), randId);
          const debt = await test_pool.getDebt();
          expect(debt).to.be.eq("797964337058657421");

          const expectedDY = await test_pool.calculateSwap(0, 1, debt);
          expect(expectedDY).to.be.eq("668363052451118814");

          await test_pool.connect(user1).swap(0, 1, debt, 0, MAX_UINT256, {
            value: debt,
          });

          const tokenBalance1 = await test_pool.getTokenBalance(0);
          const tokenBalance2 = await test_pool.getTokenBalance(1);
          expect(
            tokenBalance1.mul(String(1e18)).div(tokenBalance2).add(1)
          ).to.be.eq(String(12e17));
          expect(await test_pool.getDebt()).to.be.lte(10);
        });

        it("price=2", async () => {
          await gETHReference.setPricePerShare(String(2e18), randId);
          const debt = await test_pool.getDebt();
          expect(debt).to.be.eq("1989158936944686622");

          const expectedDY = await test_pool.calculateSwap(0, 1, debt);
          expect(expectedDY).to.be.eq("1005420531527656688");

          await test_pool.connect(user1).swap(0, 1, debt, 0, MAX_UINT256, {
            value: debt,
          });

          const tokenBalance1 = await test_pool.getTokenBalance(0);
          const tokenBalance2 = await test_pool.getTokenBalance(1);
          expect(
            tokenBalance1.mul(String(1e18)).div(tokenBalance2).add(2)
          ).to.be.eq(String(2e18));
          expect(await test_pool.getDebt()).to.be.lte(10);
        });
      });
    });
    describe("When swap fee is 4e6", async () => {
      it("Debt must be zero when Ether > gEther, and more than no fee", async () => {
        await test_pool
          .connect(user1)
          .addLiquidity([String(2e18), String(1e18)], 0, MAX_UINT256, {
            value: ethers.utils.parseEther("2"),
          });

        expect(await test_pool.getDebt()).to.be.eq(0);
      });
      it("Debt must be non-zero when Ether < gEther", async () => {
        await test_pool
          .connect(user1)
          .addLiquidity([String(1e18), String(2e18)], 0, MAX_UINT256, {
            value: ethers.utils.parseEther("1"),
          });

        expect(await test_pool.getDebt()).to.be.gt("499147041342998336");
        expect(await test_pool.getDebt()).to.be.eq("499247211934729736");
      });

      describe("Pool debt be < 1e15 after the debt was paid.", async () => {
        beforeEach(async () => {
          await test_pool.addLiquidity(
            [String(1e18), String(2e18)],
            0,
            MAX_UINT256,
            {
              value: ethers.utils.parseEther("1"),
            }
          );
        });

        it("price=1", async () => {
          const debt = await test_pool.getDebt();
          expect(debt).to.be.gt("499147041342998336");
          expect(debt).to.be.eq("499247211934729736");

          const expectedDY = await test_pool.calculateSwap(0, 1, debt);
          expect(expectedDY).to.be.eq("500752747931239795");

          await test_pool.connect(user1).swap(0, 1, debt, 0, MAX_UINT256, {
            value: debt,
          });

          const tokenBalance1 = await test_pool.getTokenBalance(0);
          const tokenBalance2 = await test_pool.getTokenBalance(1);

          expect(
            tokenBalance1.mul(String(1e18)).div(tokenBalance2).add(1)
          ).to.be.gt(BigNumber.from(String(1e18)).sub(1e15));
          expect(await test_pool.getDebt()).to.be.lte(1e15);
        });

        it("price=1.2", async () => {
          await gETHReference.setPricePerShare(String(12e17), randId);
          const debt = await test_pool.getDebt();
          expect(debt).to.be.gt("797964337058657421");
          expect(debt).to.be.eq("798124744191245689");

          const expectedDY = await test_pool.calculateSwap(0, 1, debt);
          expect(expectedDY).to.be.eq("668229326246004552");

          await test_pool.connect(user1).swap(0, 1, debt, 0, MAX_UINT256, {
            value: debt,
          });

          const tokenBalance1 = await test_pool.getTokenBalance(0);
          const tokenBalance2 = await test_pool.getTokenBalance(1);
          expect(
            tokenBalance1.mul(String(1e18)).div(tokenBalance2).add(1)
          ).to.be.gt(BigNumber.from(String(12e17)).sub(1e15));
          expect(await test_pool.getDebt()).to.be.lte(1e15);
        });

        it("price=2", async () => {
          await gETHReference.setPricePerShare(String(2e18), randId);
          const debt = await test_pool.getDebt();
          expect(debt).to.be.gt("1989158936944686622");
          expect(debt).to.be.eq("1989561105157297684");

          const expectedDY = await test_pool.calculateSwap(0, 1, debt);
          expect(expectedDY).to.be.eq("1005219366655508469");

          await test_pool.connect(user1).swap(0, 1, debt, 0, MAX_UINT256, {
            value: debt,
          });

          const tokenBalance1 = await test_pool.getTokenBalance(0);
          const tokenBalance2 = await test_pool.getTokenBalance(1);
          expect(
            tokenBalance1.mul(String(1e18)).div(tokenBalance2).add(2)
          ).to.be.gt(BigNumber.from(String(2e18)).sub(1e15));
          expect(await test_pool.getDebt()).to.be.lte(1e15);
        });
      });
    });
  });

  /**
  describe("Check for timestamp manipulations", () => {
    beforeEach(async () => {
      await forceAdvanceOneBlock();
    });

    it("Check for maximum differences in A and virtual price when A is increasing", async () => {
      // Create imbalanced pool to measure virtual price change
      // Sets the pool in 1:2:1 ratio where firstToken is significantly cheaper than secondToken
      await test_pool.addLiquidity([String(1e18), 0], 0, MAX_UINT256, {
        value: ethers.utils.parseEther("1"),
      });

      // Initial A and virtual price
      expect(await test_pool.getA()).to.be.eq(60);
      expect(await test_pool.getAPrecise()).to.be.eq(6000);
      expect(await test_pool.getVirtualPrice()).to.be.eq("1000066822646615457");

      // Start ramp
      await test_pool.rampA(
        100,
        (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1
      );

      // Malicious miner skips 900 seconds
      await setTimestamp((await getCurrentBlockTimestamp()) + 900);

      expect(await test_pool.getA()).to.be.eq(60);
      expect(await test_pool.getAPrecise()).to.be.eq(6002);
      expect(await test_pool.getVirtualPrice()).to.be.eq("1000067156804881210");

      // Max increase of A between two blocks
      // 6002 / 6000
      // = 1.00033...

      // Max increase of virtual price between two blocks (at 1:2:1 ratio of tokens, starting A = 60)
      // 1000050280521250656 / 1000049951127639292
      // = 1.00000032938
    });

    it("Check for maximum differences in A and virtual price when A is decreasing", async () => {
      // Create imbalanced pool to measure virtual price change
      // Sets the pool in 1:2:1 ratio where second Token is significantly cheaper than others
      await test_pool.addLiquidity([String(1e18), 0], 0, MAX_UINT256, {
        value: ethers.utils.parseEther("1"),
      });

      // Initial A and virtual price
      expect(await test_pool.getA()).to.be.eq(60);
      expect(await test_pool.getAPrecise()).to.be.eq(6000);
      expect(await test_pool.getVirtualPrice()).to.be.eq("1000066822646615457");

      // Start ramp
      await test_pool.rampA(
        30,
        (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1
      );

      // Malicious miner skips 900 seconds
      await setTimestamp((await getCurrentBlockTimestamp()) + 900);

      expect(await test_pool.getA()).to.be.eq(59);
      expect(await test_pool.getAPrecise()).to.be.eq(5998);
      expect(await test_pool.getVirtualPrice()).to.be.eq("1000066488269811101");

      // Max decrease of A between two blocks
      // 5998 / 6000
      // = 0.99966666666

      // Max decrease of virtual price between two blocks (at 1:2:1 ratio of tokens, starting A = 60)
      // 1000049621518807462 / 1000049951127639292
      // = 0.9999996704
    });

    // Below tests try to verify the issues found in Curve Vulnerability Report are resolved.
    // https://medium.com/@peter_4205/curve-vulnerability-report-a1d7630140ec
    // The two cases we are most concerned are:
    //
    // 1. A is ramping up, and the pool is at imbalanced state.
    //
    // Attacker can 'resolve' the imbalance prior to the change of A. Then try to recreate the imbalance after A has
    // changed. Due to the price curve becoming more linear, recreating the imbalance will become a lot cheaper. Thus
    // benefiting the attacker.
    //
    // 2. A is ramping down, and the pool is at balanced state
    //
    // Attacker can create the imbalance in token balances prior to the change of A. Then try to resolve them
    // near 1:1 ratio. Since downward change of A will make the price curve less linear, resolving the token balances
    // to 1:1 ratio will be cheaper. Thus benefiting the attacker
    //
    // For visual representation of how price curves differ based on A, please refer to Figure 1 in the above
    // Curve Vulnerability Report.

    describe("Check for attacks while A is ramping upwards", () => {
      let initialAttackerBalances = [];
      let initialPoolBalances = [];
      let attacker;

      beforeEach(async () => {
        // This attack is achieved by creating imbalance in the first block then
        // trading in reverse direction in the second block.
        attacker = user1;

        initialAttackerBalances = await getUserTokenBalances(
          attacker,
          [100, 1, 2],
          gETHReference
        );

        expect(initialAttackerBalances[1]).to.be.eq(String(1e20));
        expect(initialAttackerBalances[2]).to.be.eq(String(1e20));

        // Start ramp upwards
        await test_pool.rampA(
          100,
          (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1
        );
        expect(await test_pool.getAPrecise()).to.be.eq(6000);

        // Check current pool balances
        initialPoolBalances = [
          await test_pool.getTokenBalance(0),
          await test_pool.getTokenBalance(1),
        ];

        expect(initialPoolBalances[0]).to.be.eq(String(1e18));
        expect(initialPoolBalances[1]).to.be.eq(String(1e18));
      });

      describe(
        "When tokens are priced equally: " +
          "attacker creates massive imbalance prior to A change, and resolves it after",
        () => {
          it("Attack fails with 900 seconds between blocks", async () => {
            // Swap 1e18 of firstToken to secondToken, causing massive imbalance in the pool
            await test_pool
              .connect(attacker)
              .swap(0, 1, String(1e18), 0, MAX_UINT256);
            const secondTokenOutput = (
              await getUserTokenBalance(attacker, 2, gETHReference)
            ).sub(initialAttackerBalances[2]);

            // First trade results in 9.9163e17 of secondToken
            expect(secondTokenOutput).to.be.eq("916300000000000000");

            // Pool is imbalanced! Now trades from secondToken -> firstToken may be profitable in small sizes
            // firstToken balance in the pool  : 2.00e18
            // secondToken balance in the pool : 8.37e16
            expect(await test_pool.getTokenBalance(0)).to.be.eq(String(2e18));
            expect(await test_pool.getTokenBalance(1)).to.be.eq(
              "83700000000000000"
            );
            // Malicious miner skips 900 seconds
            await setTimestamp((await getCurrentBlockTimestamp()) + 900);

            // Verify A has changed upwards
            // 6000 -> 6002 (0.03%)
            expect(await test_pool.getAPrecise()).to.be.eq(6002);

            // Trade secondToken to firstToken, taking advantage of the imbalance and change of A
            const balanceBefore = await getUserTokenBalance(
              attacker,
              1,
              gETHReference
            );
            await test_pool
              .connect(attacker)
              .swap(1, 0, secondTokenOutput, 0, MAX_UINT256);

            const firstTokenOutput = (
              await getUserTokenBalance(attacker, 1, gETHReference)
            ).sub(balanceBefore);

            // If firstTokenOutput > 1e18, the malicious user leaves with more firstToken than the start.
            expect(firstTokenOutput).to.be.eq("998870798583751806");

            const finalAttackerBalances = await getUserTokenBalances(
              attacker,
              [100, 1, 2],
              gETHReference
            );

            expect(finalAttackerBalances[1]).to.be.lt(
              initialAttackerBalances[1]
            );

            expect(finalAttackerBalances[2]).to.be.eq(
              initialAttackerBalances[2]
            );

            expect(
              initialAttackerBalances[1].sub(finalAttackerBalances[1])
            ).to.be.eq("1129201416248194");

            expect(
              initialAttackerBalances[2].sub(finalAttackerBalances[2])
            ).to.be.eq("0");

            // Check for pool balance changes
            const finalPoolBalances = [];
            finalPoolBalances.push(await test_pool.getTokenBalance(0));
            finalPoolBalances.push(await test_pool.getTokenBalance(1));

            expect(finalPoolBalances[0]).to.be.gt(initialPoolBalances[0]);

            expect(finalPoolBalances[1]).to.be.eq(initialPoolBalances[1]);

            expect(finalPoolBalances[0].sub(initialPoolBalances[0])).to.be.eq(
              "1129201416248194"
            );

            expect(finalPoolBalances[1].sub(initialPoolBalances[1])).to.be.eq(
              "0"
            );

            // The attack did not benefit the attacker. see the code above.
          });

          it("Attack fails with 2 weeks between transactions (mimics rapid A change)", async () => {
            // This test assumes there are no other transactions during the 2 weeks period of ramping up.
            // Purpose of this test case is to mimic rapid ramp up of A.

            // Swap 1e18 of firstToken to secondToken, causing massive imbalance in the pool
            await test_pool
              .connect(attacker)
              .swap(0, 1, String(1e18), 0, MAX_UINT256);
            const secondTokenOutput = (
              await getUserTokenBalance(attacker, 2, gETHReference)
            ).sub(initialAttackerBalances[1]);

            expect(secondTokenOutput).to.be.eq("916300000000000000");

            // Pool is imbalanced! Now trades from secondToken -> firstToken may be profitable in small sizes
            expect(await test_pool.getTokenBalance(0)).to.be.eq(String(2e18));

            expect(await test_pool.getTokenBalance(1)).to.be.eq(
              "83700000000000000"
            );

            // Assume no transactions occur during 2 weeks
            await setTimestamp(
              (await getCurrentBlockTimestamp()) + 2 * TIME.WEEKS
            );

            // Verify A has changed upwards
            expect(await test_pool.getAPrecise()).to.be.eq(10000);

            // Trade secondToken to firstToken, taking advantage of the imbalance and sudden change of A
            const balanceBefore = await getUserTokenBalance(
              attacker,
              1,
              gETHReference
            );
            await test_pool
              .connect(attacker)
              .swap(1, 0, secondTokenOutput, 0, MAX_UINT256);
            const firstTokenOutput = (
              await getUserTokenBalance(attacker, 1, gETHReference)
            ).sub(balanceBefore);

            // If firstTokenOutput > 1e18, the malicious user leaves with more firstToken than the start.
            expect(firstTokenOutput).to.be.eq("968337196748323044");

            const finalAttackerBalances = await getUserTokenBalances(
              attacker,
              [100, 1, 2],
              gETHReference
            );

            expect(finalAttackerBalances[1]).to.be.lt(
              initialAttackerBalances[1]
            );
            expect(finalAttackerBalances[2]).to.be.eq(
              initialAttackerBalances[2]
            );

            expect(
              initialAttackerBalances[1].sub(finalAttackerBalances[1])
            ).to.be.eq("31662803251676956");
            expect(
              initialAttackerBalances[2].sub(finalAttackerBalances[2])
            ).to.be.eq("0");

            // Check for pool balance changes
            const finalPoolBalances = [
              await test_pool.getTokenBalance(0),
              await test_pool.getTokenBalance(1),
            ];

            expect(finalPoolBalances[0]).to.be.gt(initialPoolBalances[0]);
            expect(finalPoolBalances[1]).to.be.eq(initialPoolBalances[1]);
            expect(finalPoolBalances[0].sub(initialPoolBalances[0])).to.be.eq(
              "31662803251676956"
            );
            expect(finalPoolBalances[1].sub(initialPoolBalances[1])).to.be.eq(
              "0"
            );
            // The attack did not benefit the attacker.
          });
        }
      );

      describe(
        "When token price is unequal: " +
          "attacker 'resolves' the imbalance prior to A change, then recreates the imbalance.",
        () => {
          beforeEach(async () => {
            // Set up pool to be imbalanced prior to the attack
            await test_pool
              .connect(user2)
              .addLiquidity(
                [String(0), String(2e18)],
                0,
                (await getCurrentBlockTimestamp()) + 60
              );

            // Check current pool balances
            initialPoolBalances = [
              await test_pool.getTokenBalance(0),
              await test_pool.getTokenBalance(1),
            ];
            expect(initialPoolBalances[0]).to.be.eq(String(1e18));
            expect(initialPoolBalances[1]).to.be.eq(String(3e18));
          });

          it("Attack fails with 900 seconds between blocks", async () => {
            // Swap 1e18 of firstToken to secondToken, resolving imbalance in the pool

            await test_pool
              .connect(attacker)
              .swap(0, 1, String(1e18), 0, MAX_UINT256);
            const secondTokenOutput = (
              await getUserTokenBalance(attacker, 2, gETHReference)
            ).sub(initialAttackerBalances[2]);

            // Because the pool was imbalanced in the beginning, this trade results in more than 1e18 secondToken
            expect(secondTokenOutput).to.be.eq("1010436485243816357");

            // Pool is now almost balanced!
            expect(await test_pool.getTokenBalance(0)).to.be.eq(String(2e18));
            expect(await test_pool.getTokenBalance(1)).to.be.eq(
              "1989563514756183643"
            );

            // Malicious miner skips 900 seconds
            await setTimestamp((await getCurrentBlockTimestamp()) + 900);

            // Verify A has changed upwards
            expect(await test_pool.getAPrecise()).to.be.eq(6002);

            // Trade secondToken to firstToken, taking advantage of the imbalance and sudden change of A
            const balanceBefore = await getUserTokenBalance(
              attacker,
              1,
              gETHReference
            );
            await test_pool
              .connect(attacker)
              .swap(1, 0, secondTokenOutput, 0, MAX_UINT256);
            const firstTokenOutput = (
              await getUserTokenBalance(attacker, 1, gETHReference)
            ).sub(balanceBefore);

            // If firstTokenOutput > 1e18, the attacker leaves with more firstToken than the start.
            expect(firstTokenOutput).to.be.eq("999206718887357235");

            const finalAttackerBalances = await getUserTokenBalances(
              attacker,
              [100, 1, 2],
              gETHReference
            );

            expect(finalAttackerBalances[1]).to.be.lt(
              initialAttackerBalances[1]
            );
            expect(finalAttackerBalances[2]).to.be.eq(
              initialAttackerBalances[2]
            );
            expect(
              initialAttackerBalances[1].sub(finalAttackerBalances[1])
            ).to.be.eq("793281112642765");
            expect(
              initialAttackerBalances[2].sub(finalAttackerBalances[2])
            ).to.be.eq("0");

            // Check for pool balance changes
            const finalPoolBalances = [];
            finalPoolBalances.push(await test_pool.getTokenBalance(0));
            finalPoolBalances.push(await test_pool.getTokenBalance(1));

            expect(finalPoolBalances[0]).to.be.gt(initialPoolBalances[0]);
            expect(finalPoolBalances[1]).to.be.eq(initialPoolBalances[1]);
            expect(finalPoolBalances[0].sub(initialPoolBalances[0])).to.be.eq(
              "793281112642765"
            );
            expect(finalPoolBalances[1].sub(initialPoolBalances[1])).to.be.eq(
              "0"
            );
            // The attack did not benefit the attacker.
          });

          it("Attack succeeds with 2 weeks between transactions (mimics rapid A change)", async () => {
            // This test assumes there are no other transactions during the 2 weeks period of ramping up.
            // Purpose of this test case is to mimic rapid ramp up of A.

            // Swap 1e18 of firstToken to secondToken, resolving the imbalance in the pool
            await test_pool
              .connect(attacker)
              .swap(0, 1, String(1e18), 0, MAX_UINT256);
            const secondTokenOutput = (
              await getUserTokenBalance(attacker, 2, gETHReference)
            ).sub(initialAttackerBalances[1]);

            expect(secondTokenOutput).to.be.eq("1010436485243816357");

            // Pool is now almost balanced!
            // firstToken balance in the pool  : 2.000e18
            // secondToken balance in the pool : 1.989e18
            expect(await test_pool.getTokenBalance(0)).to.be.eq(String(2e18));
            expect(await test_pool.getTokenBalance(1)).to.be.eq(
              "1989563514756183643"
            );

            // Assume 2 weeks go by without any other transactions
            // This mimics rapid change of A
            await setTimestamp(
              (await getCurrentBlockTimestamp()) + 2 * TIME.WEEKS
            );

            // Verify A has changed upwards
            expect(await test_pool.getAPrecise()).to.be.eq(10000);

            // Trade secondToken to firstToken, taking advantage of the imbalance and sudden change of A
            const balanceBefore = await getUserTokenBalance(
              attacker,
              1,
              gETHReference
            );
            await test_pool
              .connect(attacker)
              .swap(1, 0, secondTokenOutput, 0, MAX_UINT256);
            const firstTokenOutput = (
              await getUserTokenBalance(attacker, 1, gETHReference)
            ).sub(balanceBefore);

            // If firstTokenOutput > 1e18, the malicious user leaves with more firstToken than the start.
            expect(firstTokenOutput).to.be.eq("1003422853322301133");
            // Attack was successful!

            const finalAttackerBalances = await getUserTokenBalances(
              attacker,
              [100, 1, 2],
              gETHReference
            );

            expect(initialAttackerBalances[1]).to.be.lt(
              finalAttackerBalances[1]
            );
            expect(initialAttackerBalances[2]).to.be.eq(
              finalAttackerBalances[2]
            );
            expect(
              finalAttackerBalances[1].sub(initialAttackerBalances[1])
            ).to.be.eq("3422853322301133");
            expect(
              finalAttackerBalances[2].sub(initialAttackerBalances[2])
            ).to.be.eq("0");

            // Check for pool balance changes
            const finalPoolBalances = [
              await test_pool.getTokenBalance(0),
              await test_pool.getTokenBalance(1),
            ];

            expect(finalPoolBalances[0]).to.be.lt(initialPoolBalances[0]);
            expect(finalPoolBalances[1]).to.be.eq(initialPoolBalances[1]);
            expect(initialPoolBalances[0].sub(finalPoolBalances[0])).to.be.eq(
              "3422853322301133"
            );
            expect(initialPoolBalances[1].sub(finalPoolBalances[1])).to.be.eq(
              "0"
            );

            // The attack benefited the attacker.
            // Note that this attack is only possible when there are no swaps happening during the 2 weeks ramp period.
          });
        }
      );
    });

    describe("Check for attacks while A is ramping downwards", () => {
      let initialAttackerBalances = [];
      let initialPoolBalances = [];
      let attacker;

      beforeEach(async () => {
        // Set up the downward ramp A
        attacker = user1;

        initialAttackerBalances = await getUserTokenBalances(
          attacker,
          [100, 1, 2],
          gETHReference
        );

        expect(initialAttackerBalances[1]).to.be.eq(String(1e20));
        expect(initialAttackerBalances[2]).to.be.eq(String(1e20));

        // Start ramp downwards
        await test_pool.rampA(
          30,
          (await getCurrentBlockTimestamp()) + 14 * TIME.DAYS + 1
        );
        expect(await test_pool.getAPrecise()).to.be.eq(6000);

        // Check current pool balances
        initialPoolBalances = [
          await test_pool.getTokenBalance(0),
          await test_pool.getTokenBalance(1),
        ];
        expect(initialPoolBalances[0]).to.be.eq(String(1e18));
        expect(initialPoolBalances[1]).to.be.eq(String(1e18));
      });

      describe(
        "When tokens are priced equally: " +
          "attacker creates massive imbalance prior to A change, and resolves it after",
        () => {
          // This attack is achieved by creating imbalance in the first block then
          // trading in reverse direction in the second block.

          it("Attack fails with 900 seconds between blocks", async () => {
            // Swap 1e18 of firstToken to secondToken, causing massive imbalance in the pool
            await test_pool
              .connect(attacker)
              .swap(0, 1, String(1e18), 0, MAX_UINT256);
            const secondTokenOutput = (
              await getUserTokenBalance(attacker, 2, gETHReference)
            ).sub(initialAttackerBalances[2]);

            // First trade results in 9.163e17 of secondToken
            expect(secondTokenOutput).to.be.eq("916300000000000000");

            // Pool is imbalanced! Now trades from secondToken -> firstToken may be profitable in small sizes
            // firstToken balance in the pool  : 2.00e18
            // secondToken balance in the pool : 8.37e16
            expect(await test_pool.getTokenBalance(0)).to.be.eq(String(2e18));
            expect(await test_pool.getTokenBalance(1)).to.be.eq(
              "83700000000000000"
            );

            // Malicious miner skips 900 seconds
            await setTimestamp((await getCurrentBlockTimestamp()) + 900);

            // Verify A has changed downwards
            expect(await test_pool.getAPrecise()).to.be.eq(5998);

            const balanceBefore = await getUserTokenBalance(
              attacker,
              1,
              gETHReference
            );
            await test_pool
              .connect(attacker)
              .swap(1, 0, secondTokenOutput, 0, MAX_UINT256);
            const firstTokenOutput = (
              await getUserTokenBalance(attacker, 1, gETHReference)
            ).sub(balanceBefore);

            // If firstTokenOutput > 1e18, the malicious user leaves with more firstToken than the start.
            expect(firstTokenOutput).to.be.eq("998919266990600563");

            const finalAttackerBalances = await getUserTokenBalances(
              attacker,
              [100, 1, 2],
              gETHReference
            );

            // Check for attacker's balance changes
            expect(finalAttackerBalances[1]).to.be.lt(
              initialAttackerBalances[1]
            );
            expect(finalAttackerBalances[2]).to.be.eq(
              initialAttackerBalances[2]
            );
            expect(
              initialAttackerBalances[1].sub(finalAttackerBalances[1])
            ).to.be.eq("1080733009399437");
            expect(
              initialAttackerBalances[2].sub(finalAttackerBalances[2])
            ).to.be.eq("0");

            // Check for pool balance changes
            const finalPoolBalances = [
              await test_pool.getTokenBalance(0),
              await test_pool.getTokenBalance(1),
            ];

            expect(finalPoolBalances[0]).to.be.gt(initialPoolBalances[0]);
            expect(finalPoolBalances[1]).to.be.eq(initialPoolBalances[1]);
            expect(finalPoolBalances[0].sub(initialPoolBalances[0])).to.be.eq(
              "1080733009399437"
            );
            expect(finalPoolBalances[1].sub(initialPoolBalances[1])).to.be.eq(
              "0"
            );
            // The attack did not benefit the attacker.
          });

          it("Attack succeeds with 2 weeks between transactions (mimics rapid A change)", async () => {
            // This test assumes there are no other transactions during the 2 weeks period of ramping down.
            // Purpose of this test is to show how dangerous rapid A ramp is.

            // Swap 1e18 of firstToken to secondToken, causing massive imbalance in the pool
            await test_pool
              .connect(attacker)
              .swap(0, 1, String(1e18), 0, MAX_UINT256);
            const secondTokenOutput = (
              await getUserTokenBalance(attacker, 2, gETHReference)
            ).sub(initialAttackerBalances[2]);

            // First trade results in 9.163e17 of secondToken
            expect(secondTokenOutput).to.be.eq("916300000000000000");

            // Pool is imbalanced! Now trades from secondToken -> firstToken may be profitable in small sizes
            // firstToken balance in the pool  : 2.00e18
            // secondToken balance in the pool : 8.37e16
            expect(await test_pool.getTokenBalance(0)).to.be.eq(String(2e18));
            expect(await test_pool.getTokenBalance(1)).to.be.eq(
              "83700000000000000"
            );

            // Assume no transactions occur during 2 weeks ramp time
            await setTimestamp(
              (await getCurrentBlockTimestamp()) + 2 * TIME.WEEKS
            );

            // Verify A has changed downwards
            expect(await test_pool.getAPrecise()).to.be.eq(3000);

            const balanceBefore = await getUserTokenBalance(
              attacker,
              1,
              gETHReference
            );
            await test_pool
              .connect(attacker)
              .swap(1, 0, secondTokenOutput, 0, MAX_UINT256);
            const firstTokenOutput = (
              await getUserTokenBalance(attacker, 1, gETHReference)
            ).sub(balanceBefore);

            // If firstTokenOutput > 1e18, the malicious user leaves with more firstToken than the start.
            expect(firstTokenOutput).to.be.eq("1064051336419513038");

            const finalAttackerBalances = await getUserTokenBalances(
              attacker,
              [100, 1, 2],
              gETHReference
            );

            // Check for attacker's balance changes
            expect(finalAttackerBalances[1]).to.be.gt(
              initialAttackerBalances[1]
            );
            expect(finalAttackerBalances[2]).to.be.eq(
              initialAttackerBalances[2]
            );
            expect(
              finalAttackerBalances[1].sub(initialAttackerBalances[1])
            ).to.be.eq("64051336419513038");
            expect(
              finalAttackerBalances[2].sub(initialAttackerBalances[2])
            ).to.be.eq("0");

            // Check for pool balance changes
            const finalPoolBalances = [
              await test_pool.getTokenBalance(0),
              await test_pool.getTokenBalance(1),
            ];

            expect(finalPoolBalances[0]).to.be.lt(initialPoolBalances[0]);
            expect(finalPoolBalances[1]).to.be.eq(initialPoolBalances[1]);
            expect(initialPoolBalances[0].sub(finalPoolBalances[0])).to.be.eq(
              "64051336419513038"
            );
            expect(initialPoolBalances[1].sub(finalPoolBalances[1])).to.be.eq(
              "0"
            );

            // The attack was successful. The change of A (-50%) gave the attacker a chance to swap
            // more efficiently. The swap fee (0.1%) was not sufficient to counter the efficient trade, giving
            // the attacker more tokens than initial deposit.
          });
        }
      );

      describe(
        "When token price is unequal: " +
          "attacker 'resolves' the imbalance prior to A change, then recreates the imbalance.",
        () => {
          beforeEach(async () => {
            // Set up pool to be imbalanced prior to the attack
            await test_pool
              .connect(user2)
              .addLiquidity(
                [String(0), String(2e18)],
                0,
                (await getCurrentBlockTimestamp()) + 60
              );

            // Check current pool balances
            initialPoolBalances = [
              await test_pool.getTokenBalance(0),
              await test_pool.getTokenBalance(1),
            ];
            expect(initialPoolBalances[0]).to.be.eq(String(1e18));
            expect(initialPoolBalances[1]).to.be.eq(String(3e18));
          });

          it("Attack fails with 900 seconds between blocks", async () => {
            // Swap 1e18 of firstToken to secondToken, resolving imbalance in the pool

            await test_pool
              .connect(attacker)
              .swap(0, 1, String(1e18), 0, MAX_UINT256);
            const secondTokenOutput = (
              await getUserTokenBalance(attacker, 2, gETHReference)
            ).sub(initialAttackerBalances[2]);

            // First trade results in 1.01e18 of secondToken
            // Because the pool was imbalanced in the beginning, this trade results in more than 1e18 secondToken
            expect(secondTokenOutput).to.be.eq("1010436485243816357");

            // Pool is now almost balanced!
            // firstToken balance in the pool  : 2.000e18
            // secondToken balance in the pool : 1.989e18
            expect(await test_pool.getTokenBalance(0)).to.be.eq(String(2e18));
            expect(await test_pool.getTokenBalance(1)).to.be.eq(
              "1989563514756183643"
            );

            // Malicious miner skips 900 seconds
            await setTimestamp((await getCurrentBlockTimestamp()) + 900);

            // Verify A has changed downwards
            expect(await test_pool.getAPrecise()).to.be.eq(5998);

            const balanceBefore = await getUserTokenBalance(
              attacker,
              1,
              gETHReference
            );
            await test_pool
              .connect(attacker)
              .swap(1, 0, secondTokenOutput, 0, MAX_UINT256);
            const firstTokenOutput = (
              await getUserTokenBalance(attacker, 1, gETHReference)
            ).sub(balanceBefore);

            // If firstTokenOutput > 1e18, the malicious user leaves with more firstToken than the start.
            expect(firstTokenOutput).to.be.eq("999199804200707142");

            const finalAttackerBalances = await getUserTokenBalances(
              attacker,
              [100, 1, 2],
              gETHReference
            );

            // Check for attacker's balance changes
            expect(finalAttackerBalances[1]).to.be.lt(
              initialAttackerBalances[1]
            );
            expect(finalAttackerBalances[2]).to.be.eq(
              initialAttackerBalances[2]
            );
            expect(
              initialAttackerBalances[1].sub(finalAttackerBalances[1])
            ).to.be.eq("800195799292858");
            expect(
              initialAttackerBalances[2].sub(finalAttackerBalances[2])
            ).to.be.eq("0");

            // Check for pool balance changes
            const finalPoolBalances = [
              await test_pool.getTokenBalance(0),
              await test_pool.getTokenBalance(1),
            ];

            expect(finalPoolBalances[0]).to.be.gt(initialPoolBalances[0]);
            expect(finalPoolBalances[1]).to.be.eq(initialPoolBalances[1]);
            expect(finalPoolBalances[0].sub(initialPoolBalances[0])).to.be.eq(
              "800195799292858"
            );
            expect(finalPoolBalances[1].sub(initialPoolBalances[1])).to.be.eq(
              "0"
            );
            // The attack did not benefit the attacker.
          });

          it("Attack fails with 2 weeks between transactions (mimics rapid A change)", async () => {
            // This test assumes there are no other transactions during the 2 weeks period of ramping down.
            // Purpose of this test case is to mimic rapid ramp down of A.

            // Swap 1e18 of firstToken to secondToken, resolving imbalance in the pool
            await test_pool
              .connect(attacker)
              .swap(0, 1, String(1e18), 0, MAX_UINT256);
            const secondTokenOutput = (
              await getUserTokenBalance(attacker, 2, gETHReference)
            ).sub(initialAttackerBalances[2]);

            // First trade results in 1.01e18 of secondToken
            // Because the pool was imbalanced in the beginning, this trade results in more than 1e18 secondToken
            expect(secondTokenOutput).to.be.eq("1010436485243816357");

            // Pool is now almost balanced!
            // firstToken balance in the pool  : 2.000e18
            // secondToken balance in the pool : 1.989e18
            expect(await test_pool.getTokenBalance(0)).to.be.eq(String(2e18));
            expect(await test_pool.getTokenBalance(1)).to.be.eq(
              "1989563514756183643"
            );

            // Assume no other transactions occur during the 2 weeks ramp period
            await setTimestamp(
              (await getCurrentBlockTimestamp()) + 2 * TIME.WEEKS
            );

            // Verify A has changed downwards
            expect(await test_pool.getAPrecise()).to.be.eq(3000);

            const balanceBefore = await getUserTokenBalance(
              attacker,
              0,
              gETHReference
            );
            await test_pool
              .connect(attacker)
              .swap(1, 0, secondTokenOutput, 0, MAX_UINT256);
            const firstTokenOutput = (
              await getUserTokenBalance(attacker, 1, gETHReference)
            ).sub(balanceBefore);

            // If firstTokenOutput > 1e18, the malicious user leaves with more firstToken than the start.
            expect(firstTokenOutput).to.be.eq("99989243284728428679");
            // Attack was not successful

            const finalAttackerBalances = await getUserTokenBalances(
              attacker,
              [100, 1, 2],
              gETHReference
            );

            // Check for attacker's balance changes
            expect(finalAttackerBalances[1]).to.be.lt(
              initialAttackerBalances[1]
            );
            expect(finalAttackerBalances[2]).to.be.eq(
              initialAttackerBalances[2]
            );
            expect(
              initialAttackerBalances[1].sub(finalAttackerBalances[1])
            ).to.be.eq("10756715271571321");
            expect(
              initialAttackerBalances[2].sub(finalAttackerBalances[2])
            ).to.be.eq("0");

            // Check for pool balance changes
            const finalPoolBalances = [
              await test_pool.getTokenBalance(0),
              await test_pool.getTokenBalance(1),
            ];

            expect(finalPoolBalances[0]).to.be.gt(initialPoolBalances[0]);
            expect(finalPoolBalances[1]).to.be.eq(initialPoolBalances[1]);
            expect(finalPoolBalances[0].sub(initialPoolBalances[0])).to.be.eq(
              "10756715271571321"
            );
            expect(finalPoolBalances[1].sub(initialPoolBalances[1])).to.be.eq(
              "0"
            );
            // The attack did not benefit the attacker
          });
        }
      );
    });
  });
 */
});
