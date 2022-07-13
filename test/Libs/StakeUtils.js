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
const randId = 696969696969;
// const randId2 = 420420420;
// const randId3 = 3131313131;
// const wrongId = 69;
// const wrappedEtherId = 1;
// const provider = waffle.provider;
const INITIAL_A_VALUE = 60;
const SWAP_FEE = 4e6; // 4bps
const ADMIN_FEE = 5e9; // 0
const PERIOD_PRICE_INCREASE_LIMIT = 5e7;
const MAX_MAINTAINER_FEE = 1e9;

describe("StakeUtils", async () => {
  let gETH;
  // let deployer;
  let oracle;
  // let representative;
  // let operator;
  // let user1;
  // let user2;
  let DEFAULT_DWP;
  let DEFAULT_LP_TOKEN;

  const setupTest = deployments.createFixture(async ({ ethers }) => {
    await deployments.fixture(); // ensure you start from a fresh deployments
    const { get } = deployments;
    signers = await ethers.getSigners();

    deployer = signers[0];
    oracle = signers[1];
    representative = signers[2];
    operator = signers[3];
    user1 = signers[4];
    user2 = signers[5];

    gETH = await ethers.getContractAt("gETH", (await get("gETH")).address);

    DEFAULT_DWP = (await get("Swap")).address;
    DEFAULT_LP_TOKEN = (await get("LPToken")).address;

    const TestGeodeUtils = await ethers.getContractFactory("TestStakeUtils", {
      libraries: {
        DataStoreUtils: (await get("DataStoreUtils")).address,
        StakeUtils: (await get("StakeUtils")).address,
      },
    });

    testContract = await TestGeodeUtils.deploy(
      gETH.address,
      oracle.address,
      DEFAULT_DWP,
      DEFAULT_LP_TOKEN
    );
    await gETH.updateMinterPauserOracle(testContract.address);
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
        ).to.be.revertedWith("StakeUtils: sender not maintainer");
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
        ).to.be.revertedWith("StakeUtils: not CONTROLLER of given id");
      });
      it("Reverts if ZERO ADDRESS", async () => {
        await expect(
          testContract.connect(user1).changeIdMaintainer(randId, ZERO_ADDRESS)
        ).to.be.revertedWith("StakeUtils: maintainer can not be zero");
      });
    });
  });
});
