const { expect } = require("chai");

const { expectRevert, constants, BN } = require("@openzeppelin/test-helpers");
const { ZERO_ADDRESS, MAX_UINT256 } = constants;
const { strToBytes, strToBytes32, PERCENTAGE_DENOMINATOR, DAY } = require("../../../utils");
const { artifacts } = require("hardhat");

const StakeModuleLib = artifacts.require("StakeModuleLib");
const GeodeModuleLib = artifacts.require("GeodeModuleLib");
const OracleExtensionLib = artifacts.require("OracleExtensionLib");
const InitiatorExtensionLib = artifacts.require("InitiatorExtensionLib");
const WithdrawalModuleLib = artifacts.require("WithdrawalModuleLib");

const WithdawalModuleLibMock = artifacts.require("$WithdrawalModuleLibMock");

const StakeModuleLibMock = artifacts.require("$StakeModuleLibMock");

const gETH = artifacts.require("gETH");

const WithdrawalContract = artifacts.require("WithdrawalContract");

contract("WithdrawalModuleLib", function (accounts) {
  const [
    deployer,
    oracle,
    operatorOwner,
    poolOwner,
    operatorMaintainer,
    poolMaintainer,
    staker,
    randomAddress,
  ] = accounts;

  const operatorFee = new BN(String(8e8)); // 8%
  const poolFee = new BN(String(9e8)); // 9%

  const MIN_VALIDATOR_PERIOD = DAY.muln(90);
  const MONOPOLY_THRESHOLD = new BN("50000");

  const setWithdrawalPackage = async function () {
    const wc = await WithdrawalContract.new(this.gETH.address, this.SMLM.address);
    const packageType = new BN(10011);
    const packageName = "WithdrawalContract";

    const withdrawalPackageId = await this.SMLM.generateId(packageName, packageType);

    await this.SMLM.$writeUint(withdrawalPackageId, strToBytes32("TYPE"), packageType);
    await this.SMLM.$writeAddress(withdrawalPackageId, strToBytes32("CONTROLLER"), wc.address);

    await this.SMLM.$writeBytes(
      withdrawalPackageId,
      strToBytes32("NAME"),
      strToBytes("WithdrawalContract")
    );

    await this.SMLM.$set_package(packageType, withdrawalPackageId);
  };

  const createPool = async function (name) {
    await this.SMLM.initiatePool(
      poolFee,
      0,
      poolMaintainer,
      strToBytes(name),
      "0x",
      [false, false, false],
      {
        from: poolOwner,
        value: new BN(String(1e18)).muln(32),
      }
    );
    const id = await this.SMLM.generateId(name, 5);
    return id;
  };

  const createOperator = async function (name) {
    const id = await this.SMLM.generateId(name, 4);

    await this.SMLM.$writeUint(id, strToBytes32("TYPE"), 4);
    await this.SMLM.$writeAddress(id, strToBytes32("CONTROLLER"), operatorOwner);
    await this.SMLM.initiateOperator(id, operatorFee, MIN_VALIDATOR_PERIOD, operatorMaintainer, {
      from: operatorOwner,
      value: new BN(String(1e18)).muln(10),
    });
    return id;
  };

  before(async function () {
    const GML = await GeodeModuleLib.new();
    const SML = await StakeModuleLib.new();
    // this should be before --> await InitiatorExtensionLib.new();
    await InitiatorExtensionLib.link(SML);
    const IEL = await InitiatorExtensionLib.new();
    const OEL = await OracleExtensionLib.new();
    const WML = await WithdrawalModuleLib.new();

    await WithdrawalContract.link(GML);
    await WithdrawalContract.link(WML);

    await StakeModuleLibMock.link(SML);
    await StakeModuleLibMock.link(OEL);
    await StakeModuleLibMock.link(IEL);

    await WithdawalModuleLibMock.link(WML);

    this.createPool = createPool;
    this.createOperator = createOperator;
    this.setWithdrawalPackage = setWithdrawalPackage;
  });

  beforeEach(async function () {
    this.gETH = await gETH.new("name", "symbol", "uri", { from: deployer });
    this.contract = await WithdawalModuleLibMock.new();

    this.SMLM = await StakeModuleLibMock.new({ from: deployer });
    await this.SMLM.initialize(this.gETH.address, oracle);

    await this.gETH.transferMinterRole(this.SMLM.address, { from: deployer });
    await this.gETH.transferMiddlewareManagerRole(this.SMLM.address, { from: deployer });
    await this.gETH.transferOracleRole(this.SMLM.address, { from: deployer });

    this.WithdrawalContract = await WithdrawalContract.new(
      this.gETH.address,
      this.contract.address
    );

    await this.setWithdrawalPackage();
    this.poolId = await this.createPool("perfectPool");

    this.operatorId = await this.createOperator("perfectOperator");

    await this.contract.initialize(this.gETH.address, this.SMLM.address, this.poolId);
  });

  context("__WithdrawalModule_init_unchained", function () {
    it("reverts with gETH=0", async function () {
      await expectRevert(
        (
          await WithdawalModuleLibMock.new()
        ).initialize(ZERO_ADDRESS, this.SMLM.address, this.poolId),
        "WM:gETH cannot be zero address"
      );
    });

    it("reverts with portal=0", async function () {
      await expectRevert(
        (
          await WithdawalModuleLibMock.new()
        ).initialize(this.gETH.address, ZERO_ADDRESS, this.poolId),
        "WM:portal cannot be zero address"
      );
    });

    context("success", function () {
      let params;
      beforeEach(async function () {
        params = await this.contract.$getWithdrawalParams();
      });
      it("sets gETH", async function () {
        expect(params.gETH).to.be.equal(this.gETH.address);
      });
      it("sets PORTAL", async function () {
        expect(params.PORTAL).to.be.equal(this.SMLM.address);
      });
      it("sets POOL_ID", async function () {
        expect(params.POOL_ID).to.be.bignumber.equal(this.poolId);
      });
      it("sets EXIT_THRESHOLD", async function () {
        expect(params.EXIT_THRESHOLD).to.be.bignumber.equal(new BN(6 * 1e9));
      });
    });
  });

  context("setExitThreshold", function () {
    it("reverts if new threshold lower than 60%", async function () {
      await expectRevert(this.contract.setExitThreshold(6 * 1e9 - 1), "WML:min threshold is 60%");
    });
    it("reverts if new threshold higher than 100%", async function () {
      await expectRevert(this.contract.setExitThreshold(1e10 + 1), "WML:max threshold is 100%");
    });
    it("success", async function () {
      await this.contract.setExitThreshold(7 * 1e9);
      expect((await this.contract.$getWithdrawalParams()).EXIT_THRESHOLD).to.be.bignumber.equal(
        new BN(7 * 10e8)
      );
    });
  });

  context("validatorThreshold", function () {
    const pubkeyNotExists =
      "0x986e1dee05f3a018bab83343b3b3d96dd573a50ffb03e8145b2964a389ceb14cb3780266b99ef7cf0e16ee34648e2151";

    it("returns 0 if empty", async function () {
      expect(await this.contract.$validatorThreshold(pubkeyNotExists)).to.be.bignumber.equal(
        new BN(0)
      );
    });
    it("returns correct threshold", async function () {
      const mockBeaconBalance = new BN(String(32e18));
      const mockWithdrawnBalance = new BN(String(2e18));
      const mockPrice = new BN(String(15e17));
      await this.contract.$setMockValidatorData(
        pubkeyNotExists,
        mockBeaconBalance,
        mockWithdrawnBalance,
        0
      );
      await this.SMLM.$set_PricePerShare(mockPrice, this.poolId);
      const exitThreshold = new BN((await this.contract.$getWithdrawalParams()).EXIT_THRESHOLD);

      expect(await this.contract.$validatorThreshold(pubkeyNotExists)).to.be.bignumber.equal(
        exitThreshold
          .mul(mockBeaconBalance)
          .div(new BN(String(PERCENTAGE_DENOMINATOR)))
          .mul(new BN(String(1e18)))
          .div(mockPrice)
      );
    });
  });

  context("_enqueue", function () {
    const mockEnqueueTrigger = new BN(String(2e18));
    const mockEnqueueSize = new BN(String(1e18));
    it("reverts if size less than MIN_REQUEST_SIZE (0.01 gETH)", async function () {
      await expectRevert(
        this.contract.$_enqueue(mockEnqueueTrigger, new BN(String(1e15)), staker),
        "WML:min 0.01 gETH"
      );
    });
    it("reverts if owner is zero address", async function () {
      await expectRevert(
        this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, ZERO_ADDRESS),
        "WML:owner can not be zero address"
      );
    });
    it("success", async function () {
      await this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, staker);

      const req = await this.contract.$getRequestFromLastIndex(0);
      expect(req.owner).to.be.equal(staker);
      expect(req.trigger).to.be.bignumber.equal(mockEnqueueTrigger);
      expect(req.size).to.be.bignumber.equal(mockEnqueueSize);
      expect(req.fulfilled).to.be.bignumber.equal(new BN(String(0)));
      expect(req.claimableETH).to.be.bignumber.equal(new BN(String(0)));
    });
  });

  context("transferRequest", function () {
    const mockEnqueueTrigger = new BN(String(2e18));
    const mockEnqueueSize = new BN(String(1e18));

    beforeEach(async function () {
      await this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, staker);
    });

    it("reverts if not owner", async function () {
      await expectRevert(this.contract.$transferRequest(0, randomAddress), "WML:not owner");
    });
    it("reverts if new owner address is zero address", async function () {
      await expectRevert(
        this.contract.$transferRequest(0, ZERO_ADDRESS, { from: staker }),
        "WML:cannot transfer to zero address"
      );
    });
    it("success", async function () {
      await this.contract.$transferRequest(0, randomAddress, { from: staker });
      expect((await this.contract.$getRequestFromLastIndex(0)).owner).to.be.equal(randomAddress);
    });
  });

  context("fulfillable", function () {
    // can change Rfulfilled parameter from 0 to 0.5 for better testing

    it("returns 0 if realized not bigger than fulfilled", async function () {
      const mockEnqueueTrigger = new BN(String(2e18));
      const mockEnqueueSize = new BN(String(1e18));
      await this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, staker);
      expect(
        await this.contract.$fulfillable(
          new BN(String(0)), // index
          new BN(String(1e18)), // Qrealized
          new BN(String(1e18)) // Qfulfilled
        )
      ).to.be.bignumber.equal(new BN(String(0)));

      expect(
        await this.contract.$fulfillable(
          new BN(String(0)), // index
          new BN(String(1e18)), // Qrealized
          new BN(String(2e18)) // Qfulfilled
        )
      ).to.be.bignumber.equal(new BN(String(0)));
    });
    it("returns Rsize - Rfulfilled if Qrealized bigger than bigger than Rtrigger + Rsize", async function () {
      const mockEnqueueTrigger = new BN(String(4e18)); // Rtrigger
      const mockEnqueueSize = new BN(String(2e18)); // Rsize
      await this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, staker);
      expect(
        await this.contract.$fulfillable(
          new BN(String(0)), // index
          new BN(String(8e18)), // Qrealized
          new BN(String(3e18)) // Qfulfilled
        )
      ).to.be.bignumber.equal(new BN(String(2e18))); // Rsize(2) - Rfulfilled(0)
    });
    it("returns Qrealized - (Rtrigger + Rfulfilled) if Qrealized smaller than Rtrigger + Rsize (Rceil) and bigger than Rtrigger + Rfulfilled", async function () {
      const mockEnqueueTrigger = new BN(String(4e18)); // Rtrigger
      const mockEnqueueSize = new BN(String(2e18)); // Rsize
      await this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, staker);
      expect(
        await this.contract.$fulfillable(
          new BN(String(0)), // index
          new BN(String(5e18)), // Qrealized
          new BN(String(3e18)) // Qfulfilled
        )
      ).to.be.bignumber.equal(new BN(String(1e18))); // Qrealized(5) - (Rtrigger(4) + Rfulfilled(0))
    });
    it("returns 0 if Qrealized bigger than Qfulfilled, and smaller than Rtrigger + Rfulfilled", async function () {
      const mockEnqueueTrigger = new BN(String(4e18)); // Rtrigger
      const mockEnqueueSize = new BN(String(2e18)); // Rsize
      await this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, staker);
      expect(
        await this.contract.$fulfillable(
          new BN(String(0)), // index
          new BN(String(3e18)), // Qrealized
          new BN(String(2e18)) // Qfulfilled
        )
      ).to.be.bignumber.equal(new BN(String(0)));
    });
  });

  context("fulfill", function () {
    it("success", async function () {
      const mockEnqueueTrigger = new BN(String(3e18)); // Rtrigger
      const mockEnqueueSize = new BN(String(2e18)); // Rsize
      const mockRealizedPrice = new BN(String(2e18)); // realizedPrice
      await this.contract.$setMockQueueData(
        0,
        new BN(String(8e18)), // Qrealized
        new BN(String(3e18)), // Qfulfilled
        0,
        mockRealizedPrice,
        0
      );
      await this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, staker);
      await this.contract.$fulfill(
        new BN(String(0)) // index
      );
      const req = await this.contract.$getRequestFromLastIndex(0);
      expect(req.fulfilled).to.be.bignumber.equal(mockEnqueueSize);
      expect(req.claimableETH).to.be.bignumber.equal(
        mockEnqueueSize.mul(mockRealizedPrice).div(new BN(String(1e18)))
      );
      expect((await this.contract.$getQueueData()).fulfilled).to.be.bignumber.equal(
        new BN(String(5e18))
      );
    });
  });

  context("fulfillBatch", function () {
    it("success", async function () {
      const mockEnqueueTrigger0 = new BN(String(3e18)); // Rtrigger0
      const mockEnqueueSize0 = new BN(String(2e18)); // Rsize0
      const mockEnqueueTrigger1 = mockEnqueueTrigger0.add(mockEnqueueSize0); // Rtrigger1
      const mockEnqueueSize1 = new BN(String(4e18)); // Rsize1
      const mockRealizedPrice = new BN(String(2e18)); // realizedPrice
      await this.contract.$setMockQueueData(
        0,
        new BN(String(8e18)), // Qrealized
        new BN(String(3e18)), // Qfulfilled
        0,
        mockRealizedPrice,
        0
      );
      await this.contract.$_enqueue(mockEnqueueTrigger0, mockEnqueueSize0, staker);
      await this.contract.$_enqueue(mockEnqueueTrigger1, mockEnqueueSize1, staker);
      await this.contract.$fulfillBatch(
        [new BN(String(0)), new BN(String(1))] // index
      );
      const req0 = await this.contract.$getRequestFromLastIndex(1);
      const req1 = await this.contract.$getRequestFromLastIndex(0);
      expect(req0.fulfilled).to.be.bignumber.equal(mockEnqueueSize0);
      expect(req0.claimableETH).to.be.bignumber.equal(
        new BN(String(2e18)).mul(mockRealizedPrice).div(new BN(String(1e18)))
      );
      expect(req1.fulfilled).to.be.bignumber.equal(new BN(String(3e18))); // 3e18 since it can be at most it
      expect(req1.claimableETH).to.be.bignumber.equal(
        new BN(String(3e18)).mul(mockRealizedPrice).div(new BN(String(1e18))) // 3e18 since it can be at most it
      );
      expect((await this.contract.$getQueueData()).fulfilled).to.be.bignumber.equal(
        new BN(String(8e18)) // Qrealized (since it can be at most it)
      );
    });
  });

  context("_dequeue", function () {
    const mockEnqueueTrigger = new BN(String(3e18)); // Rtrigger
    const mockEnqueueSize = new BN(String(2e18)); // Rsize
    const mockRealizedPrice = new BN(String(2e18)); // realizedPrice

    beforeEach(async function () {
      await this.contract.$setMockQueueData(
        0,
        new BN(String(8e18)), // Qrealized
        new BN(String(3e18)), // Qfulfilled
        0,
        mockRealizedPrice,
        0
      );
      await this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, staker);
    });

    it("reverts if not owner", async function () {
      await this.contract.$fulfill(new BN(String(0)));
      await expectRevert(
        this.contract.$_dequeue(new BN(String(0)), { from: randomAddress }),
        "WML:not owner"
      );
    });
    it("reverts if claimableETH is 0", async function () {
      await expectRevert(
        this.contract.$_dequeue(new BN(String(0)), { from: staker }),
        "WML:not claimable"
      );
    });
    it("success", async function () {
      await this.contract.$fulfill(new BN(String(0)));

      // to get the return value, not changing the state
      const claimableETH = await this.contract.$_dequeue.call(new BN(String(0)), { from: staker });
      await this.contract.$_dequeue(new BN(String(0)), { from: staker });
      expect(claimableETH).to.be.bignumber.equal(
        mockEnqueueSize.mul(mockRealizedPrice).div(new BN(String(1e18)))
      );
      expect((await this.contract.$getRequestFromLastIndex(0)).claimableETH).to.be.bignumber.equal(
        new BN(String(0))
      );
    });
  });

  context("dequeue", function () {
    const mockEnqueueTrigger = new BN(String(3e18)); // Rtrigger
    const mockEnqueueSize = new BN(String(2e18)); // Rsize
    const mockRealizedPrice = new BN(String(2e18)); // realizedPrice

    beforeEach(async function () {
      await this.contract.$setMockQueueData(
        0,
        new BN(String(8e18)), // Qrealized
        new BN(String(3e18)), // Qfulfilled
        0,
        mockRealizedPrice,
        0
      );
      await this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, staker);
    });

    it("reverts if receiver is ZERO_ADDRESS", async function () {
      await expectRevert(
        this.contract.$dequeue(new BN(String(0)), ZERO_ADDRESS, { from: staker }),
        "WML:receiver can not be zero address"
      );
    });
    it("reverts if WC does not have enough balance", async function () {
      await expectRevert(
        this.contract.$dequeue(new BN(String(0)), randomAddress, { from: staker }),
        "WML:Failed to send Ether"
      );
    });
    it("success", async function () {
      const [deployer] = await ethers.getSigners();
      await deployer.sendTransaction({
        to: this.contract.address,
        value: ethers.utils.parseEther("10.0"), // sends 10.0 ether
      });

      const beforeContractBalance = await ethers.provider.getBalance(this.contract.address);
      const beforeBalance = await ethers.provider.getBalance(randomAddress);

      await this.contract.$dequeue(new BN(String(0)), randomAddress, { from: staker });

      const afterBalance = await ethers.provider.getBalance(randomAddress);
      const afterContractBalance = await ethers.provider.getBalance(this.contract.address);

      expect(new BN(String(afterBalance))).to.be.bignumber.equal(
        new BN(String(beforeBalance)).add(
          mockEnqueueSize.mul(mockRealizedPrice).div(new BN(String(1e18)))
        )
      );
      expect(new BN(String(afterContractBalance))).to.be.bignumber.equal(
        new BN(String(beforeContractBalance)).sub(
          mockEnqueueSize.mul(mockRealizedPrice).div(new BN(String(1e18)))
        )
      );
    });
  });

  context("dequeueBatch", function () {
    const mockEnqueueTrigger0 = new BN(String(3e18)); // Rtrigger
    const mockEnqueueSize0 = new BN(String(2e18)); // Rsize
    const mockEnqueueTrigger1 = mockEnqueueTrigger0.add(mockEnqueueSize0); // Rtrigger
    const mockEnqueueSize1 = new BN(String(4e18)); // Rsize
    const mockRealizedPrice = new BN(String(2e18)); // realizedPrice

    beforeEach(async function () {
      await this.contract.$setMockQueueData(
        0,
        new BN(String(8e18)), // Qrealized
        new BN(String(3e18)), // Qfulfilled
        0,
        mockRealizedPrice,
        0
      );
      await this.contract.$_enqueue(mockEnqueueTrigger0, mockEnqueueSize0, staker);
      await this.contract.$_enqueue(mockEnqueueTrigger1, mockEnqueueSize1, staker);
    });

    it("reverts if receiver is ZERO_ADDRESS", async function () {
      await expectRevert(
        this.contract.$dequeueBatch([new BN(String(0)), new BN(String(1))], ZERO_ADDRESS, {
          from: staker,
        }),
        "WML:receiver can not be zero address"
      );
    });
    it("reverts if WC does not have enough balance", async function () {
      await expectRevert(
        this.contract.$dequeueBatch([new BN(String(0)), new BN(String(1))], randomAddress, {
          from: staker,
        }),
        "WML:Failed to send Ether"
      );
    });
    it("success", async function () {
      const [deployer] = await ethers.getSigners();
      await deployer.sendTransaction({
        to: this.contract.address,
        value: ethers.utils.parseEther("10.0"), // sends 10.0 ether
      });

      const beforeContractBalance = await ethers.provider.getBalance(this.contract.address);
      const beforeBalance = await ethers.provider.getBalance(randomAddress);

      await this.contract.$dequeueBatch([new BN(String(0)), new BN(String(1))], randomAddress, {
        from: staker,
      });

      const afterBalance = await ethers.provider.getBalance(randomAddress);
      const afterContract = await ethers.provider.getBalance(this.contract.address);

      expect(new BN(String(afterBalance))).to.be.bignumber.equal(
        new BN(String(beforeBalance)).add(
          new BN(String(5e18)).mul(mockRealizedPrice).div(new BN(String(1e18))) // 5e18 since it can be at most it
        )
      );
      expect(new BN(String(afterContract))).to.be.bignumber.equal(
        new BN(String(beforeContractBalance)).sub(
          new BN(String(5e18)).mul(mockRealizedPrice).div(new BN(String(1e18))) // 5e18 since it can be at most it
        )
      );
    });
  });

  context("_realizeProcessedEther", function () {
    const mockQrealized = new BN(String(11e18)); // Qrealized
    const mockQfulfilled = new BN(String(1e18)); // Qfulfilled
    const mockRealizedPrice = new BN(String(4e18)); // realizedPrice
    const mockPricePerShare = new BN(String(2e18)); // pricePerShare
    const mockProcessedBalance = new BN(String(20e18)); // processedBalance
    const denominator = new BN(String(1e18)); // denominator
    const processedgEth = mockProcessedBalance.mul(denominator).div(mockPricePerShare); // processedgEth
    const claimable = mockQrealized.sub(mockQfulfilled); // claimable

    beforeEach(async function () {
      // for mocking enqueue and put gETH to the contract
      await this.SMLM.deposit(this.poolId, 0, [], 0, MAX_UINT256, staker, {
        from: poolOwner,
        value: new BN(String(1e18)).muln(64),
      });
      await this.gETH.safeTransferFrom(
        staker,
        this.contract.address,
        this.poolId,
        processedgEth,
        strToBytes(""),
        { from: staker }
      );

      // set price per share
      await this.SMLM.$set_PricePerShare(mockPricePerShare, this.poolId);
    });

    it("sets realizedPrice to pps if internalPrice is 0", async function () {
      const beforegETHBalance = await this.gETH.balanceOf(this.contract.address, this.poolId);
      await this.contract.$_realizeProcessedEther(mockProcessedBalance);
      const aftergETHBalance = await this.gETH.balanceOf(this.contract.address, this.poolId);
      expect(aftergETHBalance).to.be.bignumber.equal(beforegETHBalance.sub(processedgEth));

      const queueData = await this.contract.$getQueueData();
      expect(queueData.realizedPrice).to.be.bignumber.equal(mockPricePerShare);
      expect(queueData.realized).to.be.bignumber.equal(processedgEth);
      expect(queueData.realizedBalance).to.be.bignumber.equal(mockProcessedBalance);
    });
    it("sets realizedPrice to pps if claimable is 0", async function () {
      await this.contract.$setMockQueueData(
        0,
        mockQrealized,
        mockQrealized, // Qfulfilled = Qrealized
        0,
        mockRealizedPrice,
        0
      );
      const beforegETHBalance = await this.gETH.balanceOf(this.contract.address, this.poolId);
      await this.contract.$_realizeProcessedEther(mockProcessedBalance);
      const aftergETHBalance = await this.gETH.balanceOf(this.contract.address, this.poolId);
      expect(aftergETHBalance).to.be.bignumber.equal(beforegETHBalance.sub(processedgEth));

      const queueData = await this.contract.$getQueueData();
      expect(queueData.realizedPrice).to.be.bignumber.equal(mockPricePerShare);
      expect(queueData.realized).to.be.bignumber.equal(mockQrealized.add(processedgEth));
      expect(queueData.realizedBalance).to.be.bignumber.equal(mockProcessedBalance);
    });
    it("calculates realizedPrice correctly", async function () {
      await this.contract.$setMockQueueData(
        0,
        mockQrealized,
        mockQfulfilled,
        0,
        mockRealizedPrice,
        0
      );
      const beforegETHBalance = await this.gETH.balanceOf(this.contract.address, this.poolId);
      await this.contract.$_realizeProcessedEther(mockProcessedBalance);
      const aftergETHBalance = await this.gETH.balanceOf(this.contract.address, this.poolId);
      expect(aftergETHBalance).to.be.bignumber.equal(beforegETHBalance.sub(processedgEth));

      const queueData = await this.contract.$getQueueData();
      expect(queueData.realizedPrice).to.be.bignumber.equal(
        claimable
          .mul(mockRealizedPrice)
          .add(mockProcessedBalance.mul(denominator))
          .div(claimable.add(processedgEth))
      );
      expect(queueData.realized).to.be.bignumber.equal(mockQrealized.add(processedgEth));
      expect(queueData.realizedBalance).to.be.bignumber.equal(mockProcessedBalance);
    });
  });

  context("validator creation needed tests", function () {
    const pubkey0 =
      "0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a";
    const pubkey1 =
      "0xa3b3eb55b16999ffeff52e5a898af89e4194b7221b2eaf03cb85fd558a390dc042beba94f907db6091b4cf141b18d1f5";
    const pubkeyNotExists =
      "0x986e1dee05f3a018bab83343b3b3d96dd573a50ffb03e8145b2964a389ceb14cb3780266b99ef7cf0e16ee34648e2151";

    const signature01 =
      "0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181";
    const signature11 =
      "0xa2e94c3def1e53d7d1b5a0f037f765868b4bbae3ee59de673bc7ab7b142b929e08f47c1c2a6cdc91aee9442468ab095406b8ce356aef42403febe385424f97d6d109f6423dcb1acc3def45af56e4407416f0773bd18e50d880cb7d3e00ca9932";
    const signature031 =
      "0xa58af51205a996c87f23c80aeb3cb669001e3f919a88598d063ff6cee9b05fbb8a18dab15a4a5b85eabfd47c26d0f24f11f5f889f6a7fb8cbd5c4ccd7607c449b57a9f0703e1bb63b513cb3e9fcd1d79b0d8f269c7441173054b9284cfb7a13c";
    const signature131 =
      "0xa7290722d0b9350504fd44cd166fabc85db76fab07fb2876bff51e0ede2856e6160e4288853cf713cbf3cd7a0541ab1d0ed5e0858c980870f3a4c791264d8b4ee090677f507b599409e86433590ee3a93cae5103d2e03c66bea623e3ccd590ae";

    beforeEach(async function () {
      await this.SMLM.deposit(this.poolId, 0, [], 0, MAX_UINT256, staker, {
        from: poolOwner,
        value: new BN(String(1e18)).muln(64),
      });

      await this.SMLM.$set_MONOPOLY_THRESHOLD(MONOPOLY_THRESHOLD);
      await this.SMLM.delegate(this.poolId, [this.operatorId], [2], {
        from: poolMaintainer,
      });

      await this.SMLM.proposeStake(
        this.poolId,
        this.operatorId,
        [pubkey0, pubkey1],
        [signature01, signature11],
        [signature031, signature131],
        {
          from: operatorMaintainer,
        }
      );
    });

    context("canFinalizeExit", function () {
      const mockBeaconBalance = new BN(String(10e18));

      beforeEach(async function () {
        // set mock contract as withdrawalContract
        await this.SMLM.$writeAddress(
          this.poolId,
          strToBytes32("withdrawalContract"),
          this.contract.address
        );

        await this.SMLM.$set_VERIFICATION_INDEX(1);
        await this.SMLM.stake(this.operatorId, [pubkey0], {
          from: operatorMaintainer,
        });
      });
      it("returns false if validator not exists", async function () {
        expect(await this.contract.$canFinalizeExit(pubkeyNotExists)).to.be.equal(false);
      });
      it("returns false if validator in PROPOSE_STAKE state", async function () {
        expect(await this.contract.$canFinalizeExit(pubkey1)).to.be.equal(false);
      });
      it("returns false if validator beaconBalance is not 0", async function () {
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          new BN(String(0)),
          new BN(String(0))
        );
        expect(await this.contract.$canFinalizeExit(pubkey0)).to.be.equal(false);
      });
      it("returns true if validator in ACTIVE state and beaconBalance is not 0", async function () {
        const val = await this.SMLM.getValidator(pubkey0);
        expect(val.state).to.be.bignumber.equal(new BN(String(2))); // ACTIVE;
        expect(await this.contract.$canFinalizeExit(pubkey0)).to.be.equal(true);
      });
      it("returns true if validator in EXIT_REQUESTED state and beaconBalance is not 0", async function () {
        const mockCommonPoll = new BN(String(20e18));
        await this.contract.$_checkAndRequestExit(pubkey0, mockCommonPoll);
        const val = await this.SMLM.getValidator(pubkey0);
        expect(val.state).to.be.bignumber.equal(new BN(String(3))); // EXIT_REQUESTED;
        expect(await this.contract.$canFinalizeExit(pubkey0)).to.be.equal(true);
      });
    });

    context("_checkAndRequestExit", function () {
      const mockBeaconBalance = new BN(String(10e18));
      const mockWithdrawnBalance = new BN(String(2e18));
      const mockPrice = new BN(String(15e17));
      const mockCommonPoll = new BN(String(2e18));

      beforeEach(async function () {
        await this.SMLM.$set_PricePerShare(mockPrice, this.poolId);
        await this.contract.$setMockQueueData(0, 0, 0, 0, 0, mockCommonPoll);

        await this.SMLM.$set_VERIFICATION_INDEX(1);
        await this.SMLM.stake(this.operatorId, [pubkey0], {
          from: operatorMaintainer,
        });

        // set mock contract as withdrawalContract
        await this.SMLM.$writeAddress(
          this.poolId,
          strToBytes32("withdrawalContract"),
          this.contract.address
        );
      });
      it("if commonPoll + validatorPoll is not bigger than validatorThreshold, returns commonPoll as it is and status stay ACTIVE", async function () {
        const mockValidatorPoll = new BN(String(2e18));
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        const returnedCommonPoll = await this.contract.$_checkAndRequestExit.call(
          pubkey0,
          mockCommonPoll
        );
        await this.contract.$_checkAndRequestExit(pubkey0, mockCommonPoll);

        const val = await this.SMLM.getValidator(pubkey0);

        expect(returnedCommonPoll).to.be.bignumber.equal(mockCommonPoll);
        expect(val.state).to.be.bignumber.equal(new BN(String(2))); // ACTIVE;
      });
      it("validator state changes to EXIT_REQUESTED and commonPoll increases if commonPoll + validatorPoll bigger than validatorThreshold and validatorPoll is bigger than validatorThreshold", async function () {
        const mockValidatorPoll = new BN(String(7e18));
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );
        const threshold = await this.contract.$validatorThreshold(pubkey0);

        const returnedCommonPoll = await this.contract.$_checkAndRequestExit.call(
          pubkey0,
          mockCommonPoll
        );
        await this.contract.$_checkAndRequestExit(pubkey0, mockCommonPoll);

        const val = await this.SMLM.getValidator(pubkey0);
        expect(val.state).to.be.bignumber.equal(new BN(String(3))); // EXIT_REQUESTED;
        expect(returnedCommonPoll).to.be.bignumber.equal(
          mockCommonPoll.add(mockValidatorPoll.sub(threshold))
        );
      });
      it("validator state changes to EXIT_REQUESTED and commonPoll decreases if commonPoll + validatorPoll bigger than validatorThreshold and validatorPoll is smaller than validatorThreshold", async function () {
        const mockValidatorPoll = new BN(String(5e18));
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        const threshold = await this.contract.$validatorThreshold(pubkey0);

        const returnedCommonPoll = await this.contract.$_checkAndRequestExit.call(
          pubkey0,
          mockCommonPoll
        );
        await this.contract.$_checkAndRequestExit(pubkey0, mockCommonPoll);

        const val = await this.SMLM.getValidator(pubkey0);
        expect(val.state).to.be.bignumber.equal(new BN(String(3))); // EXIT_REQUESTED;
        expect(returnedCommonPoll).to.be.bignumber.equal(
          mockCommonPoll.sub(threshold.sub(mockValidatorPoll))
        );
      });
    });

    context("_vote", function () {
      const mockVoteSize = new BN(String(2e16));
      it("reverts if validator not belong to pool", async function () {
        await expectRevert(
          this.contract.$_vote(pubkeyNotExists, mockVoteSize),
          "SML:vote for an unknown pool"
        );
      });
      it("reverts if validator not active", async function () {
        await expectRevert(
          this.contract.$_vote(pubkey0, mockVoteSize),
          "SML:voted for inactive validator"
        );
      });
      it("success", async function () {
        await this.SMLM.$set_VERIFICATION_INDEX(1);
        await this.SMLM.stake(this.operatorId, [pubkey0], {
          from: operatorMaintainer,
        });
        await this.contract.$_vote(pubkey0, mockVoteSize);
        await this.contract.$_vote(pubkey0, mockVoteSize.muln(2));

        expect((await this.contract.$getValidatorData(pubkey0)).poll).to.be.bignumber.equal(
          mockVoteSize.muln(3)
        );
      });
    });

    context("enqueue", function () {
      const mockRequested = new BN(String(3e18));
      const mockCommonPoll = new BN(String(3e18));

      const mockBeaconBalance = new BN(String(10e18));
      const mockWithdrawnBalance = new BN(String(2e18));
      const mockValidatorPoll = new BN(String(4e18));
      const mockPrice = new BN(String(1e18));

      beforeEach(async function () {
        await this.contract.$setMockQueueData(mockRequested, 0, 0, 0, 0, mockCommonPoll);
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        // set mock contract as withdrawalContract
        await this.SMLM.$writeAddress(
          this.poolId,
          strToBytes32("withdrawalContract"),
          this.contract.address
        );

        // set mock price
        await this.SMLM.$set_PricePerShare(mockPrice, this.poolId);

        // make validator active
        await this.SMLM.$set_VERIFICATION_INDEX(1);
        await this.SMLM.stake(this.operatorId, [pubkey0], {
          from: operatorMaintainer,
        });

        // need this since WC is not approved by deployment
        await this.gETH.setApprovalForAll(this.contract.address, true, { from: staker });
      });
      it("if pubkey is empty, commonPoll and requested increase by size", async function () {
        const mockRequestSize = new BN(String(1e18));

        const beforeStakerBalance = await this.gETH.balanceOf(staker, this.poolId);
        await this.contract.$enqueue(mockRequestSize, "0x", staker, { from: staker });
        const afterStakerBalance = await this.gETH.balanceOf(staker, this.poolId);

        const req = await this.contract.$getRequestFromLastIndex(0);
        expect(req.owner).to.be.equal(staker);
        expect(req.trigger).to.be.bignumber.equal(mockRequested);
        expect(req.size).to.be.bignumber.equal(mockRequestSize);
        expect(req.fulfilled).to.be.bignumber.equal(new BN(String(0)));
        expect(req.claimableETH).to.be.bignumber.equal(new BN(String(0)));

        const queueData = await this.contract.$getQueueData();
        expect(queueData.requested).to.be.bignumber.equal(mockRequested.add(mockRequestSize));
        expect(queueData.commonPoll).to.be.bignumber.equal(mockCommonPoll.add(mockRequestSize));

        expect(afterStakerBalance).to.be.bignumber.equal(beforeStakerBalance.sub(mockRequestSize));
      });

      it("if pubkey is given, put vote and commonPoll arranged accordingly", async function () {
        const mockRequestSize = new BN(String(4e18));

        const beforeStakerBalance = await this.gETH.balanceOf(staker, this.poolId);
        await this.contract.$enqueue(mockRequestSize, pubkey0, staker, { from: staker });
        const afterStakerBalance = await this.gETH.balanceOf(staker, this.poolId);

        const req = await this.contract.$getRequestFromLastIndex(0);
        expect(req.owner).to.be.equal(staker);
        expect(req.trigger).to.be.bignumber.equal(mockRequested);
        expect(req.size).to.be.bignumber.equal(mockRequestSize);
        expect(req.fulfilled).to.be.bignumber.equal(new BN(String(0)));
        expect(req.claimableETH).to.be.bignumber.equal(new BN(String(0)));

        const threshold = await this.contract.$validatorThreshold(pubkey0);
        const queueData = await this.contract.$getQueueData();
        expect(queueData.requested).to.be.bignumber.equal(mockRequested.add(mockRequestSize));
        expect(queueData.commonPoll).to.be.bignumber.equal(
          mockCommonPoll.add(mockValidatorPoll.add(mockRequestSize).sub(threshold))
        );

        expect(afterStakerBalance).to.be.bignumber.equal(beforeStakerBalance.sub(mockRequestSize));
      });
    });

    context("enqueueBatch", function () {
      const mockRequested = new BN(String(3e18));
      const mockCommonPoll = new BN(String(3e18));

      const mockBeaconBalance = new BN(String(10e18));
      const mockWithdrawnBalance = new BN(String(2e18));
      const mockValidatorPoll = new BN(String(4e18));
      const mockPrice = new BN(String(1e18));

      beforeEach(async function () {
        await this.contract.$setMockQueueData(mockRequested, 0, 0, 0, 0, mockCommonPoll);
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );
        await this.contract.$setMockValidatorData(
          pubkey1,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        // set mock contract as withdrawalContract
        await this.SMLM.$writeAddress(
          this.poolId,
          strToBytes32("withdrawalContract"),
          this.contract.address
        );

        // set mock price
        await this.SMLM.$set_PricePerShare(mockPrice, this.poolId);

        // make validators active
        await this.SMLM.$set_VERIFICATION_INDEX(2);
        await this.SMLM.stake(this.operatorId, [pubkey0, pubkey1], {
          from: operatorMaintainer,
        });

        // need this since WC is not approved by deployment
        await this.gETH.setApprovalForAll(this.contract.address, true, { from: staker });
      });
      it("reverts if pubkey and size arrays length not equal", async function () {
        await expectRevert(
          this.contract.$enqueueBatch(
            [new BN(String(1e18)), new BN(String(2e18)), new BN(String(3e18))],
            [pubkey0, pubkey1],
            staker,
            { from: staker }
          ),
          "WML:invalid input length"
        );
      });
      it("success", async function () {
        const mockRequestSizeCommon = new BN(String(2e18));
        const mockRequestSize0 = new BN(String(1e18));
        const mockRequestSize1 = new BN(String(4e18));

        const beforeStakerBalance = await this.gETH.balanceOf(staker, this.poolId);
        await this.contract.$enqueueBatch(
          [mockRequestSizeCommon, mockRequestSize0, mockRequestSize1],
          ["0x", pubkey0, pubkey1],
          staker,
          { from: staker }
        );
        const afterStakerBalance = await this.gETH.balanceOf(staker, this.poolId);

        const req0 = await this.contract.$getRequestFromLastIndex(1);
        expect(req0.owner).to.be.equal(staker);
        expect(req0.trigger).to.be.bignumber.equal(mockRequested.add(mockRequestSizeCommon));
        expect(req0.size).to.be.bignumber.equal(mockRequestSize0);
        expect(req0.fulfilled).to.be.bignumber.equal(new BN(String(0)));
        expect(req0.claimableETH).to.be.bignumber.equal(new BN(String(0)));
        const req1 = await this.contract.$getRequestFromLastIndex(0);
        expect(req1.owner).to.be.equal(staker);
        expect(req1.trigger).to.be.bignumber.equal(
          mockRequested.add(mockRequestSize0).add(mockRequestSizeCommon)
        );
        expect(req1.size).to.be.bignumber.equal(mockRequestSize1);
        expect(req1.fulfilled).to.be.bignumber.equal(new BN(String(0)));
        expect(req1.claimableETH).to.be.bignumber.equal(new BN(String(0)));

        const threshold0 = await this.contract.$validatorThreshold(pubkey0);
        const threshold1 = await this.contract.$validatorThreshold(pubkey1);
        const queueData = await this.contract.$getQueueData();
        expect(queueData.requested).to.be.bignumber.equal(
          mockRequested.add(mockRequestSizeCommon).add(mockRequestSize0).add(mockRequestSize1)
        );

        expect(queueData.commonPoll).to.be.bignumber.equal(
          mockCommonPoll
            .add(mockRequestSizeCommon)
            .sub(threshold0.sub(mockValidatorPoll.add(mockRequestSize0)))
            .add(mockValidatorPoll)
            .add(mockRequestSize1)
            .sub(threshold1)
        );

        expect(afterStakerBalance).to.be.bignumber.equal(
          beforeStakerBalance.sub(mockRequestSizeCommon).sub(mockRequestSize0).sub(mockRequestSize1)
        );
      });
    });

    context("_distributeFees", function () {
      let beforePoolWallet;
      let beforeOperatorWallet;
      beforeEach(async function () {
        await this.contract.send(new BN(String(5e18)));
        beforePoolWallet = await this.SMLM.readUint(this.poolId, strToBytes32("wallet"));
        beforeOperatorWallet = await this.SMLM.readUint(this.operatorId, strToBytes32("wallet"));
      });
      it("if reportedWithdrawn is not bigger than processedWithdrawn wallet balances stay same", async function () {
        await this.contract.$_distributeFees(pubkey0, new BN(String(1e18)), new BN(String(2e18)));
        const afterPoolWallet = await this.SMLM.readUint(this.poolId, strToBytes32("wallet"));
        const afterOperatorWallet = await this.SMLM.readUint(
          this.operatorId,
          strToBytes32("wallet")
        );
        expect(afterPoolWallet).to.be.bignumber.equal(beforePoolWallet);
        expect(afterOperatorWallet).to.be.bignumber.equal(beforeOperatorWallet);
      });
      it("success, balances updated accordingly", async function () {
        const mockReportedWithdrawn = new BN(String(2e18));
        const mockProcessedWithdrawn = new BN(String(1e18));

        // this one is not changing the values, just to get the return statement
        const extra = await this.contract.$_distributeFees.call(
          pubkey0,
          mockReportedWithdrawn,
          mockProcessedWithdrawn
        );

        await this.contract.$_distributeFees(
          pubkey0,
          mockReportedWithdrawn,
          mockProcessedWithdrawn
        );

        const afterPoolWallet = await this.SMLM.readUint(this.poolId, strToBytes32("wallet"));
        const afterOperatorWallet = await this.SMLM.readUint(
          this.operatorId,
          strToBytes32("wallet")
        );

        const poolProfit = mockReportedWithdrawn
          .sub(mockProcessedWithdrawn)
          .mul(poolFee)
          .div(PERCENTAGE_DENOMINATOR);
        const operatorProfit = mockReportedWithdrawn
          .sub(mockProcessedWithdrawn)
          .mul(operatorFee)
          .div(PERCENTAGE_DENOMINATOR);

        expect(afterPoolWallet).to.be.bignumber.equal(beforePoolWallet.add(poolProfit));
        expect(afterOperatorWallet).to.be.bignumber.equal(beforeOperatorWallet.add(operatorProfit));
        expect(extra).to.be.bignumber.equal(
          mockReportedWithdrawn.sub(mockProcessedWithdrawn).sub(poolProfit).sub(operatorProfit)
        );
      });
    });
  });
});
