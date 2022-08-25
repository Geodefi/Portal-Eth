// const { BigNumber, Signer, constants, Bytes } = require("ethers");

const {
  MAX_UINT256,
  ZERO_ADDRESS,
  getCurrentBlockTimestamp,
  // setNextTimestamp,
  // setTimestamp,
} = require("../testUtils");

const { solidity } = require("ethereum-waffle");
const chai = require("chai");

chai.use(solidity);
const { expect } = chai;
const randId = 3131313131;
const operatorId = 420420420;
const planetId = 696969696969;
const wrongId = 69;
const provider = waffle.provider;
const INITIAL_A_VALUE = 60;
const SWAP_FEE = 4e6; // 4bps
const ADMIN_FEE = 5e9; // 0
const PERIOD_PRICE_INCREASE_LIMIT = 5e7;
const MAX_MAINTAINER_FEE = 1e9;

describe("StakeUtils", async () => {
  let gETH;
  let deployer;
  let oracle;
  // let planet;
  // let operator;
  let user1;
  let user2;
  let DEFAULT_DWP;
  let DEFAULT_LP_TOKEN;
  let DEFAULT_GETH_INTERFACE;

  const setupTest = deployments.createFixture(async ({ ethers }) => {
    await deployments.fixture(); // ensure you start from a fresh deployments
    const { get } = deployments;
    signers = await ethers.getSigners();

    deployer = signers[0];
    oracle = signers[1];
    planet = signers[2];
    operator = signers[3];
    user1 = signers[4];
    user2 = signers[5];

    gETH = await ethers.getContractAt("gETH", (await get("gETH")).address);

    DEFAULT_DWP = (await get("Swap")).address;
    DEFAULT_LP_TOKEN = (await get("LPToken")).address;
    DEFAULT_GETH_INTERFACE = (await get("ERC20InterfacePermitUpgradable"))
      .address;

    const TestStakeUtils = await ethers.getContractFactory("TestStakeUtils", {
      libraries: {
        DataStoreUtils: (await get("DataStoreUtils")).address,
        StakeUtils: (await get("StakeUtils")).address,
      },
    });

    testContract = await TestStakeUtils.deploy(
      gETH.address,
      oracle.address,
      DEFAULT_DWP,
      DEFAULT_LP_TOKEN,
      DEFAULT_GETH_INTERFACE
    );
    await gETH.updateMinterRole(testContract.address);
    await gETH.updateOracleRole(testContract.address);
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("After Creation TX", () => {
    let stakepool;
    beforeEach(async () => {
      stakepool = await testContract.getStakePoolParams();
    });
    it("correct ORACLE", async () => {
      expect(stakepool.ORACLE).to.eq(oracle.address);
    });
    it("correct gETH", async () => {
      expect(stakepool.gETH).to.eq(gETH.address);
    });
    it("correct FEE_DENOMINATOR", async () => {
      expect(stakepool.FEE_DENOMINATOR).to.eq(1e10);
    });
    it("correct DEFAULT_DWP", async () => {
      expect(stakepool.DEFAULT_DWP).to.eq(DEFAULT_DWP);
    });
    it("correct DEFAULT_LP_TOKEN", async () => {
      expect(stakepool.DEFAULT_LP_TOKEN).to.eq(DEFAULT_LP_TOKEN);
    });
    it("correct DEFAULT_A", async () => {
      expect(stakepool.DEFAULT_A).to.eq(INITIAL_A_VALUE);
    });
    it("correct DEFAULT_FEE", async () => {
      expect(stakepool.DEFAULT_FEE).to.eq(SWAP_FEE);
    });
    it("correct DEFAULT_ADMIN_FEE", async () => {
      expect(stakepool.DEFAULT_ADMIN_FEE).to.eq(ADMIN_FEE);
    });
    it("correct PERIOD_PRICE_INCREASE_LIMIT", async () => {
      expect(stakepool.PERIOD_PRICE_INCREASE_LIMIT).to.eq(
        PERIOD_PRICE_INCREASE_LIMIT
      );
    });
    it("correct MAX_MAINTAINER_FEE", async () => {
      expect(stakepool.MAX_MAINTAINER_FEE).to.eq(MAX_MAINTAINER_FEE);
    });
  });

  describe("Maintainer Logic", () => {
    beforeEach(async () => {
      await testContract.connect(user1).beController(randId);
      await testContract
        .connect(user1)
        .changeIdMaintainer(randId, user1.address);
    });

    describe("get/set MaintainerFee", () => {
      it("Succeeds set", async () => {
        await testContract.connect(user1).setMaintainerFee(randId, 12345);
        expect(await testContract.getMaintainerFee(randId)).to.be.eq(12345);
      });
      it("Reverts if > MAX", async () => {
        await testContract.connect(user1).setMaintainerFee(randId, 10 ** 9);
        await expect(
          testContract.connect(user1).setMaintainerFee(randId, 10 ** 9 + 1)
        ).to.be.revertedWith("StakeUtils: MAX_MAINTAINER_FEE ERROR");
      });
      it("Reverts if not maintainer", async () => {
        await expect(
          testContract.setMaintainerFee(randId, 10 ** 9 + 1)
        ).to.be.revertedWith("StakeUtils: sender is NOT maintainer");
      });
    });

    describe("setMaxMaintainerFee", () => {
      it("succeeds", async () => {
        await testContract.setMaxMaintainerFee(0);
        expect(
          (await testContract.getStakePoolParams()).MAX_MAINTAINER_FEE
        ).to.be.eq(0);

        await testContract.setMaxMaintainerFee(10 ** 10);
        expect(
          (await testContract.getStakePoolParams()).MAX_MAINTAINER_FEE
        ).to.be.eq(10 ** 10);
      });
      it("Reverts if > 100%", async () => {
        await expect(
          testContract.setMaxMaintainerFee(10 ** 10 + 1)
        ).to.be.revertedWith("StakeUtils: fee more than 100%");
      });
    });

    describe("changeMaintainer", () => {
      it("Succeeds", async () => {
        await testContract
          .connect(user1)
          .changeIdMaintainer(randId, user2.address);
        expect(await testContract.getMaintainerFromId(randId)).to.be.eq(
          user2.address
        );
      });
      it("Reverts if not controller", async () => {
        await expect(
          testContract.changeIdMaintainer(randId, user2.address)
        ).to.be.revertedWith("StakeUtils: sender is NOT CONTROLLER");
      });
      it("Reverts if ZERO ADDRESS", async () => {
        await expect(
          testContract.connect(user1).changeIdMaintainer(randId, ZERO_ADDRESS)
        ).to.be.revertedWith("StakeUtils: maintainer can NOT be zero");
      });
    });
  });

  describe("Helper functions", () => {
    it("getgETH", async () => {
      expect(await testContract.getERC1155()).to.eq(gETH.address);
    });

    it("_mint", async () => {
      await testContract.mintgETH(user2.address, randId, String(2e18));
      expect(await gETH.balanceOf(user2.address, randId)).to.eq(String(2e18));
    });

    it("_setInterface", async () => {
      await testContract.setInterface(randId, DEFAULT_GETH_INTERFACE, true);
      expect(await gETH.isInterface(DEFAULT_GETH_INTERFACE, randId)).to.eq(
        true
      );
      await testContract.setInterface(randId, DEFAULT_GETH_INTERFACE, false);
      expect(await gETH.isInterface(DEFAULT_GETH_INTERFACE, randId)).to.eq(
        false
      );
    });

    it("_setPricePerShare", async () => {
      await testContract.setPricePerShare(String(1e20), randId);
      expect(await gETH.pricePerShare(randId)).to.eq(String(1e20));
      await testContract.setPricePerShare(String(2e19), randId);
      expect(await gETH.pricePerShare(randId)).to.eq(String(2e19));
    });

    it("_getPricePerShare", async () => {
      await testContract.connect(user1).changeOracle();
      await gETH.connect(user1).setPricePerShare(String(1e20), randId);
      expect(await testContract.getPricePerShare(randId)).to.eq(String(1e20));
      await gETH.connect(user1).setPricePerShare(String(2e19), randId);
      expect(await testContract.getPricePerShare(randId)).to.eq(String(2e19));
    });
  });

  describe("deployWithdrawalPool", () => {
    let wpoolContract;

    beforeEach(async () => {
      await testContract.deployWithdrawalPool(randId);
      const wpool = await testContract.withdrawalPoolById(randId);
      wpoolContract = await ethers.getContractAt("Swap", wpool);
    });

    describe("check params", () => {
      it("Returns correct A value", async () => {
        expect(await wpoolContract.getA()).to.eq(INITIAL_A_VALUE);
        expect(await wpoolContract.getAPrecise()).to.eq(INITIAL_A_VALUE * 100);
      });

      it("Returns correct fee value", async () => {
        expect((await wpoolContract.swapStorage()).swapFee).to.eq(SWAP_FEE);
      });

      it("Returns correct adminFee value", async () => {
        expect((await wpoolContract.swapStorage()).adminFee).to.eq(ADMIN_FEE);
      });

      describe("LPToken", async () => {
        let LPcontract;
        it("init() fails with already init", async () => {
          LPcontract = await ethers.getContractAt(
            "LPToken",
            await testContract.LPTokenById(randId)
          );
          await expect(
            LPcontract.initialize("name", "symbol")
          ).to.be.revertedWith(
            "Initializable: contract is already initialized"
          );
        });

        it("Returns correct name", async () => {
          expect(await LPcontract.name()).to.eq("-Geode WP Token");
        });

        it("Returns correct symbol", async () => {
          expect(await LPcontract.symbol()).to.eq("-WP");
        });
      });
    });
  });

  describe("initiateOperator / initiator", () => {
    beforeEach(async () => {
      await testContract.connect(user1).beController(randId);
      await testContract.connect(user1).setType(randId, 4);
      await testContract
        .connect(user1)
        .changeIdMaintainer(randId, user1.address);
    });

    it("reverts if sender is NOT CONTROLLER", async () => {
      await expect(
        testContract.connect(user2).initiateOperator(
          randId, // _id
          1e5, // _fee
          user1.address // _maintainer
        )
      ).to.be.revertedWith("StakeUtils: sender is NOT CONTROLLER");
    });

    it("reverts if id should be Operator TYPE", async () => {
      await testContract.connect(user1).setType(randId, 5);
      await expect(
        testContract.connect(user1).initiateOperator(
          randId, // _id
          1e5, // _fee
          user1.address // _maintainer
        )
      ).to.be.revertedWith("StakeUtils: id should be Operator TYPE");
    });

    describe("success", async () => {
      beforeEach(async () => {
        await testContract.connect(user1).initiateOperator(
          randId, // _id
          1e5, // _fee
          user1.address // _maintainer
        );
      });
      // check initiated parameter is set as 1
      it("check initiated parameter is set as 1", async () => {
        expect(await testContract.isInitiated(randId)).to.be.eq(1);
      });

      // check maintainer is set correctly
      it("check maintainer is set correctly", async () => {
        setMaintainer = await testContract.getMaintainerFromId(randId);
        expect(setMaintainer).to.be.eq(user1.address);
      });

      // check fee is set correctly
      it("check fee is set correctly", async () => {
        setFee = await testContract.getMaintainerFee(randId);
        expect(setFee).to.be.eq(1e5);
      });

      it("after success, reverts if already initiated", async () => {
        await expect(
          testContract.connect(user1).initiateOperator(
            randId, // _id
            1e5, // _fee
            user1.address // _maintainer
          )
        ).to.be.revertedWith("StakeUtils: already initiated");
      });
    });
  });

  describe("initiatePlanet", () => {
    let wPoolContract;

    beforeEach(async () => {
      await testContract.connect(user1).beController(randId);
      await testContract.connect(user1).setType(randId, 5);
      await testContract
        .connect(user1)
        .changeIdMaintainer(randId, user1.address);

      await testContract.connect(user1).initiatePlanet(
        randId, // _id
        1e6, // _fee
        user1.address, // _maintainer
        deployer.address, // _governance
        "beautiful-planet", // _interfaceName
        "BP" // _interfaceSymbol
      );
      const wpool = await testContract.withdrawalPoolById(randId);
      wPoolContract = await ethers.getContractAt("Swap", wpool);
    });

    it("who is the owner of WP", async () => {
      expect(await wPoolContract.owner()).to.be.eq(deployer.address);
    });

    it("check given interface's name and symbol is correctly initialized", async () => {
      const currentInterface = await testContract.currentInterface(randId);
      const erc20interface = await ethers.getContractAt(
        "ERC20InterfacePermitUpgradable",
        currentInterface
      );
      expect(await erc20interface.name()).to.be.eq("beautiful-planet");
      expect(await erc20interface.symbol()).to.be.eq("BP");
    });

    it("check fee is set", async () => {
      setFee = await testContract.getMaintainerFee(randId);
      expect(setFee).to.be.eq(1e6);
    });

    it("check WP is approved for all on gETH", async () => {
      expect(
        await gETH.isApprovedForAll(testContract.address, wPoolContract.address)
      ).to.be.eq(true);
    });

    it("check pricePerShare for randId is 1 ether", async () => {
      const currentPricePerShare = await gETH.pricePerShare(randId);
      expect(currentPricePerShare).to.be.eq(
        ethers.BigNumber.from(String(1e18))
      );
    });
  });

  describe("Pause Pool functionality", () => {
    beforeEach(async () => {
      await testContract.connect(user1).beController(planetId);
      await testContract
        .connect(user1)
        .changeIdMaintainer(planetId, user1.address);
    });

    it("isStakingPausedForPool returns false in the beginning", async () => {
      expect(await testContract.isStakingPausedForPool(planetId)).to.be.eq(
        false
      );
    });

    it("unpauseStakingForPool reverts in the beginning", async () => {
      await expect(
        testContract.connect(user1).unpauseStakingForPool(planetId)
      ).to.be.revertedWith(
        "StakeUtils: staking is already NOT paused for pool"
      );
      expect(await testContract.isStakingPausedForPool(planetId)).to.be.eq(
        false
      );
    });

    describe("pauseStakingForPool functionality", () => {
      it("pauseStakingForPool reverts when it is NOT maintainer", async () => {
        await expect(
          testContract.connect(user2).pauseStakingForPool(planetId)
        ).to.be.revertedWith("StakeUtils: sender is NOT maintainer");
        expect(await testContract.isStakingPausedForPool(planetId)).to.be.eq(
          false
        );
      });
      describe("pauseStakingForPool succeeds when it is maintainer", async () => {
        beforeEach(async () => {
          await testContract.connect(user1).pauseStakingForPool(planetId);
          expect(await testContract.isStakingPausedForPool(planetId)).to.be.eq(
            true
          );
        });
        it("pauseStakingForPool reverts when it is already paused", async () => {
          await expect(
            testContract.connect(user1).pauseStakingForPool(planetId)
          ).to.be.revertedWith(
            "StakeUtils: staking is already paused for pool"
          );
          expect(await testContract.isStakingPausedForPool(planetId)).to.be.eq(
            true
          );
        });
        describe("unpauseStakingForPool when it is already paused", async () => {
          it("unpauseStakingForPool reverts when it is NOT maintainer", async () => {
            await expect(
              testContract.connect(user2).unpauseStakingForPool(planetId)
            ).to.be.revertedWith("StakeUtils: sender is NOT maintainer");

            expect(
              await testContract.isStakingPausedForPool(planetId)
            ).to.be.eq(true);
          });
          describe("unpauseStakingForPool succeeds when called by Maintainer", async () => {
            beforeEach(async () => {
              await testContract.connect(user1).unpauseStakingForPool(planetId);
              expect(
                await testContract.isStakingPausedForPool(planetId)
              ).to.be.eq(false);
            });
            it("unpauseStakingForPool reverts when it is NOT paused", async () => {
              await expect(
                testContract.connect(user1).unpauseStakingForPool(planetId)
              ).to.be.revertedWith(
                "StakeUtils: staking is already NOT paused for pool"
              );
              expect(
                await testContract.isStakingPausedForPool(planetId)
              ).to.be.eq(false);
            });
          });
        });
      });
    });
  });

  describe("Operator-Planet cooperation", () => {
    beforeEach(async () => {
      await testContract.connect(user1).beController(planetId);
      await testContract
        .connect(user1)
        .changeIdMaintainer(planetId, user1.address);
    });

    it("approveOperator reverts if NOT maintainer", async () => {
      await expect(
        testContract.connect(user2).approveOperator(planetId, operatorId, 69)
      ).to.be.revertedWith("StakeUtils: sender is NOT maintainer");
    });

    it("approveOperator succeeds if maintainer", async () => {
      await testContract
        .connect(user1)
        .approveOperator(planetId, operatorId, 69);
      expect(
        await testContract.operatorAllowance(planetId, operatorId)
      ).to.be.eq(69);
    });

    it("operatorAllowance returns correct value", async () => {
      expect(
        await testContract.operatorAllowance(planetId, operatorId)
      ).to.be.eq(0);

      await testContract
        .connect(user1)
        .approveOperator(planetId, operatorId, 69);
      expect(
        await testContract.operatorAllowance(planetId, operatorId)
      ).to.be.eq(69);

      await testContract
        .connect(user1)
        .approveOperator(planetId, operatorId, 31);
      expect(
        await testContract.operatorAllowance(planetId, operatorId)
      ).to.be.eq(31);
    });
  });

  describe("Operator Wallet", () => {
    beforeEach(async () => {
      await testContract.connect(user1).beController(operatorId);
      await testContract
        .connect(user1)
        .changeIdMaintainer(operatorId, user1.address);

      await testContract.connect(user2).beController(randId);
      await testContract
        .connect(user2)
        .changeIdMaintainer(randId, user2.address);
    });

    it("increaseOperatorWallet reverts if NOT maintainer", async () => {
      await expect(
        testContract.connect(user2).increaseOperatorWallet(operatorId, {
          value: String(1e17),
        })
      ).to.be.revertedWith("StakeUtils: sender is NOT maintainer");
    });

    it("increaseOperatorWallet succeeds if maintainer", async () => {
      await testContract.connect(user1).increaseOperatorWallet(operatorId, {
        value: String(2e17),
      });
      expect(await testContract.getOperatorWalletBalance(operatorId)).to.be.eq(
        ethers.BigNumber.from(String(2e17))
      );
    });

    it("decreaseOperatorWallet reverts if NOT maintainer", async () => {
      await testContract.connect(user1).increaseOperatorWallet(operatorId, {
        value: String(2e17),
      });

      await expect(
        testContract
          .connect(user2)
          .decreaseOperatorWallet(
            operatorId,
            ethers.BigNumber.from(String(1e17))
          )
      ).to.be.revertedWith("StakeUtils: sender is NOT maintainer");
    });

    it("decreaseOperatorWallet reverts if underflow", async () => {
      await testContract.connect(user1).increaseOperatorWallet(operatorId, {
        value: String(2e17),
      });

      await expect(
        testContract
          .connect(user1)
          .decreaseOperatorWallet(operatorId, String(3e17))
      ).to.be.reverted;
    });

    it("decreaseOperatorWallet reverts if Contract Balance is NOT sufficient", async () => {
      await expect(
        testContract
          .connect(user1)
          .decreaseOperatorWallet(operatorId, String(3e17))
      ).to.be.revertedWith("StakeUtils: Not enough resources in Portal");
    });

    it("decreaseOperatorWallet reverts if operatorWallet balance is NOT sufficient", async () => {
      await testContract.connect(user1).increaseOperatorWallet(operatorId, {
        value: String(2e17),
      });

      await testContract.connect(user2).increaseOperatorWallet(randId, {
        value: String(2e17),
      });

      await expect(
        testContract
          .connect(user1)
          .decreaseOperatorWallet(operatorId, String(3e17))
      ).to.be.revertedWith(
        "StakeUtils: Not enough resources in operatorWallet"
      );
    });

    it("decreaseOperatorWallet succeeds if maintainer", async () => {
      await testContract.connect(user1).increaseOperatorWallet(operatorId, {
        value: String(2e17),
      });

      await testContract
        .connect(user1)
        .decreaseOperatorWallet(operatorId, String(1e17));
      expect(await testContract.getOperatorWalletBalance(operatorId)).to.be.eq(
        ethers.BigNumber.from(String(1e17))
      );
    });

    it("getOperatorWalletBalance returns correct value", async () => {
      expect(await testContract.getOperatorWalletBalance(operatorId)).to.be.eq(
        0
      );

      await testContract.connect(user1).increaseOperatorWallet(operatorId, {
        value: String(3e17),
      });
      expect(await testContract.getOperatorWalletBalance(operatorId)).to.be.eq(
        ethers.BigNumber.from(String(3e17))
      );

      await testContract
        .connect(user1)
        .decreaseOperatorWallet(operatorId, String(1e17));
      expect(await testContract.getOperatorWalletBalance(operatorId)).to.be.eq(
        ethers.BigNumber.from(String(2e17))
      );
    });
  });

  describe("Staking Operations ", () => {
    let wpoolContract;
    let preContBal;
    let preContgETHBal;

    let preUserBal;
    let preUsergETHBal;

    let preSurplus;
    let preTotSup;
    let debt;
    let preSwapBals;

    beforeEach(async () => {
      await testContract.beController(randId);
      await testContract.changeIdMaintainer(randId, user1.address);
    });

    describe("StakePlanet", () => {
      beforeEach(async () => {
        await testContract.deployWithdrawalPool(randId);
        const wpool = await testContract.withdrawalPoolById(randId);
        wpoolContract = await ethers.getContractAt("Swap", wpool);

        await testContract.setPricePerShare(String(1e18), randId);

        await testContract
          .connect(deployer)
          .mintgETH(deployer.address, randId, String(1e20));

        await gETH.connect(deployer).setApprovalForAll(wpool, true);

        // initially there is no debt
        await wpoolContract
          .connect(deployer)
          .addLiquidity([String(1e20), String(1e20)], 0, MAX_UINT256, {
            value: String(1e20),
          });

        debt = await wpoolContract.getDebt();
        expect(debt).to.be.eq(0);
        preUserBal = await provider.getBalance(user1.address);
        preUsergETHBal = await gETH.balanceOf(user1.address, randId);

        preContBal = await provider.getBalance(testContract.address);
        preContgETHBal = await gETH.balanceOf(testContract.address, randId);

        preSurplus = ethers.BigNumber.from(
          await testContract.surplusById(randId)
        );
        preTotSup = await gETH.totalSupply(randId);

        preSwapBals = [
          await wpoolContract.getTokenBalance(0),
          await wpoolContract.getTokenBalance(1),
        ];
      });

      it("reverts when wrongId is given", async () => {
        await expect(
          testContract.connect(user1).stakePlanet(wrongId, 0, MAX_UINT256, {
            value: String(1e18),
          })
        ).to.be.reverted;
      });

      it("reverts when pool is paused", async () => {
        await testContract.connect(user1).pauseStakingForPool(randId);
        await expect(
          testContract.stakePlanet(randId, 0, MAX_UINT256, {
            value: String(2e18),
          })
        ).to.be.revertedWith("StakeUtils: minting is paused");
      });

      describe("succeeds", () => {
        let gasUsed;

        describe("when NO buyback (no pause, no debt)", () => {
          beforeEach(async () => {
            const tx = await testContract
              .connect(user1)
              .stakePlanet(randId, 0, MAX_UINT256, {
                value: String(1e18),
              });
            const receipt = await tx.wait();
            gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);
          });

          it("user lost ether more than stake (+gas) ", async () => {
            const newBal = await provider.getBalance(user1.address);
            expect(newBal.add(gasUsed)).to.be.eq(
              ethers.BigNumber.from(String(preUserBal)).sub(String(1e18))
            );
          });

          it("user gained gETH (mintedAmount)", async () => {
            const price = await testContract.getPricePerShare(randId);
            expect(price).to.be.eq(String(1e18));
            const mintedAmount = ethers.BigNumber.from(String(1e18))
              .div(price)
              .mul(String(1e18));
            const newBal = await gETH.balanceOf(user1.address, randId);
            expect(newBal).to.be.eq(preUsergETHBal.add(mintedAmount));
          });

          it("contract gained ether = minted gETH", async () => {
            const newBal = await provider.getBalance(testContract.address);
            expect(newBal).to.be.eq(String(preContBal.add(String(1e18))));
          });

          it("contract gEth bal did not change", async () => {
            const newBal = await gETH.balanceOf(testContract.address, randId);
            expect(newBal).to.be.eq(preContgETHBal);
          });

          it("id surplus increased", async () => {
            const newSur = await testContract.surplusById(randId);
            expect(newSur.toString()).to.be.eq(
              String(preSurplus.add(String(1e18)))
            );
          });

          it("gETH minted ", async () => {
            // minted amount from ORACLE PRICE
            const price = await testContract.getPricePerShare(randId);
            expect(price).to.be.eq(String(1e18));
            const mintedAmount = ethers.BigNumber.from(String(1e18))
              .div(price)
              .mul(String(1e18));
            const TotSup = await gETH.totalSupply(randId);
            expect(TotSup.toString()).to.be.eq(
              String(preTotSup.add(mintedAmount))
            );
          });

          it("swapContract gETH balances NOT changed", async () => {
            const swapBals = [
              await wpoolContract.getTokenBalance(0),
              await wpoolContract.getTokenBalance(1),
            ];
            expect(swapBals[0]).to.be.eq(preSwapBals[0]);
            expect(swapBals[1]).to.be.eq(preSwapBals[1]);
          });
        });

        describe("when paused pool is unpaused and not balanced", async () => {
          let gasUsed;
          let newPreUserBal;

          beforeEach(async () => {
            await testContract.connect(user1).pauseStakingForPool(randId);
            await testContract.connect(user1).unpauseStakingForPool(randId);
            newPreUserBal = await provider.getBalance(user1.address);
            await testContract
              .connect(deployer)
              .stakePlanet(randId, 0, MAX_UINT256, {
                value: String(1e20),
              });
            await wpoolContract
              .connect(deployer)
              .addLiquidity([String(0), String(1e20)], 0, MAX_UINT256);
            debt = await wpoolContract.getDebt();
            preSwapBals = [
              await wpoolContract.getTokenBalance(0),
              await wpoolContract.getTokenBalance(1),
            ];
            preContBal = await provider.getBalance(testContract.address);
            preSurplus = ethers.BigNumber.from(
              await testContract.surplusById(randId)
            );
            const tx = await testContract
              .connect(user1)
              .stakePlanet(randId, 0, MAX_UINT256, {
                value: String(5e20),
              });
            const receipt = await tx.wait();
            gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);
          });

          it("user lost ether more than stake (+gas) ", async () => {
            const newBal = await provider.getBalance(user1.address);
            expect(newBal).to.be.eq(
              ethers.BigNumber.from(String(newPreUserBal))
                .sub(String(5e20))
                .sub(gasUsed)
            );
          });

          it("user gained gether more than minted amount (+ wrapped) ", async () => {
            const price = await testContract.getPricePerShare(randId);
            expect(price).to.be.eq(String(1e18));
            const mintedAmount = ethers.BigNumber.from(String(1e18))
              .div(price)
              .mul(String(1e18));
            const newBal = await gETH.balanceOf(user1.address, randId);
            expect(newBal).to.be.gt(preUsergETHBal.add(mintedAmount));
          });

          it("contract gained ether = minted ", async () => {
            const newBal = await provider.getBalance(testContract.address);
            expect(newBal).to.be.eq(
              String(
                preContBal.add(ethers.BigNumber.from("450143212807943082239")) // lower than 5e20 since wp got its part
              )
            );
          });

          it("contract gEth bal did not change", async () => {
            const newBal = await gETH.balanceOf(testContract.address, randId);
            expect(newBal).to.be.eq(preContgETHBal);
          });

          it("id surplus increased", async () => {
            const newSur = await testContract.surplusById(randId);
            expect(newSur).to.be.eq(
              String(
                preSurplus.add(ethers.BigNumber.from("450143212807943082239")) // lower than 5e20 since wp got its part
              )
            );
          });

          it("swapContract gETH and Ether balance changed accordingly", async () => {
            const swapBals = [
              await wpoolContract.getTokenBalance(0),
              await wpoolContract.getTokenBalance(1),
            ];
            expect(swapBals[0]).to.be.eq(
              ethers.BigNumber.from(String(preSwapBals[0])).add(debt)
            );
            expect(swapBals[1]).to.be.lt(preSwapBals[1]); // gEth
          });
        });
      });
    });

    /**
     * 0	pubkey	bytes	0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a
     * 1  withdrawal_credentials	bytes	0x004f58172d06b6d54c015d688511ad5656450933aff85dac123cd09410a0825c
     * 2  signature	bytes	0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181
     * 3  deposit_data_root	bytes32	0xcf73f30d1a20e2af0446c2630acc4392f888dc0532a09592e00faf90b2976ab8
     */
    /**
     * 0	pubkey	bytes	0xa3b3eb55b16999ffeff52e5a898af89e4194b7221b2eaf03cb85fd558a390dc042beba94f907db6091b4cf141b18d1f5
     * 1	withdrawal_credentials	bytes	0x00cfafe208762abcdd05339a6814cac749bb065cf762ed4fea2e0335cbdd08f0
     * 2	signature	bytes	0xa2e94c3def1e53d7d1b5a0f037f765868b4bbae3ee59de673bc7ab7b142b929e08f47c1c2a6cdc91aee9442468ab095406b8ce356aef42403febe385424f97d6d109f6423dcb1acc3def45af56e4407416f0773bd18e50d880cb7d3e00ca9932
     * 3	deposit_data_root	bytes32	0x47bd475f56dc4ae776b1fa445323fd0eee9be77fe20a790e7783c73450274dcb
     */
    /**
     * 0	pubkey	bytes	0x986e1dee05f3a018bab83343b3b3d96dd573a50ffb03e8145b2964a389ceb14cb3780266b99ef7cf0e16ee34648e2151
     * 1	withdrawal_credentials	bytes	0x004f58172d06b6d54c015d688511ad5656450933aff85dac123cd09410a0825c
     * 2	signature	bytes	0xa58af51205a996c87f23c80aeb3cb669001e3f919a88598d063ff6cee9b05fbb8a18dab15a4a5b85eabfd47c26d0f24f11f5f889f6a7fb8cbd5c4ccd7607c449b57a9f0703e1bb63b513cb3e9fcd1d79b0d8f269c7441173054b9284cfb7a13c
     * 3	deposit_data_root	bytes32	0xb4282f23951b5bb3ead393f50dc9468e6166312a4e78f73cc649a8ae16f0d924
     */
    /**
     * 0	pubkey	bytes	0x999c0efe0e07405164c9512f3fc949340ebca1ab6bacdca7c7242de871d957a86918b2d1055d1c3b4be0683b5c8719d7
     * 1	withdrawal_credentials	bytes	0x004f58172d06b6d54c015d688511ad5656450933aff85dac123cd09410a0825c
     * 2	signature	bytes	0xa7290722d0b9350504fd44cd166fabc85db76fab07fb2876bff51e0ede2856e6160e4288853cf713cbf3cd7a0541ab1d0ed5e0858c980870f3a4c791264d8b4ee090677f507b599409e86433590ee3a93cae5103d2e03c66bea623e3ccd590ae
     * 3	deposit_data_root	bytes32	0x2a902df8a7a8a1a5860d54ab73c87c1d1d2fcabe0b12106b5cbe42c3680c0000
     */
    describe("preStake", () => {
      const pubkey1 =
        "0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a";
      const pubkey2 =
        "0xa3b3eb55b16999ffeff52e5a898af89e4194b7221b2eaf03cb85fd558a390dc042beba94f907db6091b4cf141b18d1f5";
      const pubkey3 =
        "0x986e1dee05f3a018bab83343b3b3d96dd573a50ffb03e8145b2964a389ceb14cb3780266b99ef7cf0e16ee34648e2151";
      const pubkey4 =
        "0x999c0efe0e07405164c9512f3fc949340ebca1ab6bacdca7c7242de871d957a86918b2d1055d1c3b4be0683b5c8719d7";
      const signature1 =
        "0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181";
      const signature2 =
        "0xa2e94c3def1e53d7d1b5a0f037f765868b4bbae3ee59de673bc7ab7b142b929e08f47c1c2a6cdc91aee9442468ab095406b8ce356aef42403febe385424f97d6d109f6423dcb1acc3def45af56e4407416f0773bd18e50d880cb7d3e00ca9932";
      const signature3 =
        "0xa58af51205a996c87f23c80aeb3cb669001e3f919a88598d063ff6cee9b05fbb8a18dab15a4a5b85eabfd47c26d0f24f11f5f889f6a7fb8cbd5c4ccd7607c449b57a9f0703e1bb63b513cb3e9fcd1d79b0d8f269c7441173054b9284cfb7a13c";
      const signature4 =
        "0xa7290722d0b9350504fd44cd166fabc85db76fab07fb2876bff51e0ede2856e6160e4288853cf713cbf3cd7a0541ab1d0ed5e0858c980870f3a4c791264d8b4ee090677f507b599409e86433590ee3a93cae5103d2e03c66bea623e3ccd590ae";

      beforeEach(async () => {
        await testContract.beController(operatorId);
        await testContract.changeIdMaintainer(operatorId, user1.address);
        await testContract.beController(planetId);
        await testContract.changeIdMaintainer(planetId, user2.address);
        await testContract.setType(operatorId, 4);
        await testContract.setType(planetId, 5);
      });

      it("reverts if there is no pool with id", async () => {
        await expect(
          testContract
            .connect(user1)
            .preStake(
              wrongId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1, signature2]
            )
        ).to.be.revertedWith("StakeUtils: There is no pool with id");
      });

      it("reverts if pubkeys and signatures are not same length", async () => {
        await expect(
          testContract
            .connect(user1)
            .preStake(planetId, operatorId, [pubkey1, pubkey2], [signature1])
        ).to.be.revertedWith(
          "StakeUtils: pubkeys and signatures should be same length"
        );
      });

      it("1 to 64 nodes per transaction", async () => {
        await expect(
          testContract
            .connect(user1)
            .preStake(
              planetId,
              operatorId,
              Array(65).fill(pubkey1),
              Array(65).fill(signature1)
            )
        ).to.be.revertedWith("StakeUtils: 1 to 64 nodes per transaction");

        await expect(
          testContract.connect(user1).preStake(planetId, operatorId, [], [])
        ).to.be.revertedWith("StakeUtils: 1 to 64 nodes per transaction");
      });

      // TODO: also make this test after a success state to check the calculation of allowance there
      it("not enough allowance", async () => {
        await expect(
          testContract
            .connect(user1)
            .preStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1, signature2]
            )
        ).to.be.revertedWith("StakeUtils: not enough allowance");

        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 1);

        await expect(
          testContract
            .connect(user1)
            .preStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1, signature2]
            )
        ).to.be.revertedWith("StakeUtils: not enough allowance");
      });

      it("StakeUtils: Pubkey is already alienated", async () => {
        await testContract.connect(user1).increaseOperatorWallet(operatorId, {
          value: String(2e18),
        });

        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 2);

        await testContract.alienatePubKey(pubkey2);

        await expect(
          testContract
            .connect(user1)
            .preStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1, signature2]
            )
        ).to.be.revertedWith("StakeUtils: Pubkey is already used or alienated");
      });

      it("PUBKEY_LENGTH ERROR", async () => {
        await testContract.connect(user1).increaseOperatorWallet(operatorId, {
          value: String(2e18),
        });

        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 2);

        await expect(
          testContract
            .connect(user1)
            .preStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2 + "aefe"],
              [signature1, signature2]
            )
        ).to.be.revertedWith("StakeUtils: PUBKEY_LENGTH ERROR");
      });

      it("SIGNATURE_LENGTH ERROR", async () => {
        await testContract.connect(user1).increaseOperatorWallet(operatorId, {
          value: String(2e18),
        });

        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 2);

        await expect(
          testContract
            .connect(user1)
            .preStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1, signature2 + "aefe"]
            )
        ).to.be.revertedWith("StakeUtils: SIGNATURE_LENGTH ERROR");
      });

      describe("Success", () => {
        let prevSurplus;
        let prevAllowance;
        let prevWalletBalance;
        let prevCreatedValidators;

        beforeEach(async () => {
          await testContract
            .connect(user2)
            .approveOperator(planetId, operatorId, 3);

          await testContract.connect(user1).increaseOperatorWallet(operatorId, {
            value: String(5e18),
          });

          prevSurplus = await testContract.surplusById(planetId);
          prevAllowance = await testContract.operatorAllowance(
            planetId,
            operatorId
          );
          prevWalletBalance = await testContract.getOperatorWalletBalance(
            operatorId
          );
          prevCreatedValidators = await testContract.createdValidatorsById(
            planetId,
            operatorId
          );
          await testContract
            .connect(user1)
            .preStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1, signature2]
            );
        });

        it("surplus stays same", async () => {
          expect(await testContract.surplusById(planetId)).to.be.eq(
            prevSurplus
          );
        });

        it("Allowance stays same", async () => {
          expect(
            await testContract.operatorAllowance(planetId, operatorId)
          ).to.be.eq(prevAllowance);
        });

        it("Operator wallet decreased accordingly", async () => {
          expect(
            await testContract.getOperatorWalletBalance(operatorId)
          ).to.be.eq(prevWalletBalance.sub(String(2e18)));
        });

        it("createdValidators increased accordingly", async () => {
          expect(
            await testContract.createdValidatorsById(planetId, operatorId)
          ).to.be.eq(prevCreatedValidators + 2);
        });

        it("reverts if pubKey is already created", async () => {
          await expect(
            testContract
              .connect(user1)
              .preStake(planetId, operatorId, [pubkey1], [signature1])
          ).to.be.revertedWith(
            "StakeUtils: Pubkey is already used or alienated"
          );
        });

        it("reverts if allowance is not enough after success", async () => {
          await expect(
            testContract
              .connect(user1)
              .preStake(
                planetId,
                operatorId,
                [pubkey3, pubkey4],
                [signature3, signature4]
              )
          ).to.be.revertedWith("StakeUtils: not enough allowance");
        });

        it("validator params are correct", async () => {
          const timeStamp = await getCurrentBlockTimestamp();
          const val1 = await testContract.getValidatorData(pubkey1);
          const val2 = await testContract.getValidatorData(pubkey2);
          const signatures = [signature1, signature2];
          [val1, val2].forEach(function (vd, i) {
            expect(vd.planetId).to.be.eq(planetId);
            expect(vd.operatorId).to.be.eq(operatorId);
            expect(vd.blockTimeStamp).to.be.gt(0);
            expect(vd.blockTimeStamp).to.be.eq(timeStamp);
            expect(vd.signature).to.be.eq(signatures[i]);
            expect(vd.alienated).to.be.eq(false);
          });
        });
      });
    });
  });
});
