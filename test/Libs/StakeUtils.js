// const { BigNumber, Signer, constants, Bytes } = require("ethers");

const {
  // MAX_UINT256,
  ZERO_ADDRESS,
  // getCurrentBlockTimestamp,
  // setNextTimestamp,
  // setTimestamp,
} = require("../testUtils");

const { solidity } = require("ethereum-waffle");
// const { deployments, waffle } = require("hardhat");
// const web3 = require("web3");

const chai = require("chai");

chai.use(solidity);
const { expect } = chai;
const randId = 3131313131;
const operatorId = 420420420;
const planetId = 696969696969;
// const wrongId = 69;
// const provider = waffle.provider;
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

    // sender is NOT CONTROLLER
    // id should be Operator TYPE
    // check initiated parameter is set as 1
    // check maintainer is set correctly
    // already initiated
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
});
