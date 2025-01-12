const { expect } = require("chai");

const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const { expectRevert, constants, BN } = require("@openzeppelin/test-helpers");
const { ZERO_ADDRESS, MAX_UINT256 } = constants;
const {
  strToBytes,
  strToBytes32,
  setTimestamp,
  getReceiptTimestamp,
  PERCENTAGE_DENOMINATOR,
  DAY,
} = require("../../../../utils");
const { artifacts } = require("hardhat");
const StakeModuleLib = artifacts.require("StakeModuleLib");
const GeodeModuleLib = artifacts.require("GeodeModuleLib");
const OracleExtensionLib = artifacts.require("OracleExtensionLib");
const InitiatorExtensionLib = artifacts.require("InitiatorExtensionLib");
const WithdrawalModuleLib = artifacts.require("WithdrawalModuleLib");

const WithdrawalModuleLibMock = artifacts.require("$WithdrawalModuleLibMock");

const StakeModuleLibMock = artifacts.require("$StakeModuleLibMock");

const gETH = artifacts.require("gETH");

const WithdrawalPackage = artifacts.require("WithdrawalPackage");

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
    const wp = await WithdrawalPackage.new(this.gETH.address, this.SMLM.address);
    const packageType = new BN(10011);
    const packageName = "WithdrawalPackage";

    const withdrawalPackageId = await this.SMLM.generateId(packageName, packageType);

    await this.SMLM.$writeUint(withdrawalPackageId, strToBytes32("TYPE"), packageType);
    await this.SMLM.$writeAddress(withdrawalPackageId, strToBytes32("CONTROLLER"), wp.address);

    await this.SMLM.$writeBytes(
      withdrawalPackageId,
      strToBytes32("NAME"),
      strToBytes("WithdrawalPackage")
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

    await WithdrawalPackage.link(GML);
    await WithdrawalPackage.link(WML);

    await StakeModuleLibMock.link(SML);
    await StakeModuleLibMock.link(OEL);
    await StakeModuleLibMock.link(IEL);

    await WithdrawalModuleLibMock.link(WML);

    this.createPool = createPool;
    this.createOperator = createOperator;
    this.setWithdrawalPackage = setWithdrawalPackage;
  });

  beforeEach(async function () {
    this.gETH = await gETH.new("name", "symbol", "uri", { from: deployer });
    this.contract = await WithdrawalModuleLibMock.new();

    this.SMLM = await StakeModuleLibMock.new({ from: deployer });
    await this.SMLM.initialize(this.gETH.address, oracle);

    await this.gETH.transferMinterRole(this.SMLM.address, { from: deployer });
    await this.gETH.transferMiddlewareManagerRole(this.SMLM.address, { from: deployer });
    await this.gETH.transferOracleRole(this.SMLM.address, { from: deployer });

    this.WithdrawalPackage = await WithdrawalPackage.new(this.gETH.address, this.contract.address);

    await this.setWithdrawalPackage();
    this.poolId = await this.createPool("perfectPool");

    this.operatorId = await this.createOperator("perfectOperator");

    await this.contract.initialize(this.gETH.address, this.SMLM.address, this.poolId);
  });

  context("__WithdrawalModule_init_unchained", function () {
    it("reverts with gETH=0", async function () {
      await expectRevert(
        (
          await WithdrawalModuleLibMock.new()
        ).initialize(ZERO_ADDRESS, this.SMLM.address, this.poolId),
        "WM:gETH cannot be zero address"
      );
    });

    it("reverts with portal=0", async function () {
      await expectRevert(
        (
          await WithdrawalModuleLibMock.new()
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
      expect(
        (await this.contract.$getValidatorThreshold(pubkeyNotExists)).threshold
      ).to.be.bignumber.equal(new BN(0));
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

      expect(
        (await this.contract.$getValidatorThreshold(pubkeyNotExists)).threshold
      ).to.be.bignumber.equal(
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
    it("reverts if size less than MIN_REQUEST_SIZE (0.05 gETH)", async function () {
      await expectRevert(
        this.contract.$_enqueue(mockEnqueueTrigger, new BN(String(4e16)), staker),
        "WML:min 0.05 gETH"
      );
    });
    it("reverts if owner is zero address", async function () {
      await expectRevert(
        this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, ZERO_ADDRESS),
        "WML:owner cannot be zero address"
      );
    });
    it("success", async function () {
      await this.contract.$_enqueue(mockEnqueueTrigger, mockEnqueueSize, staker);

      const req = await this.contract.$getRequestFromLastIndex(0);
      expect(req.owner).to.be.equal(staker);
      expect(req.trigger).to.be.bignumber.equal(mockEnqueueTrigger);
      expect(req.size).to.be.bignumber.equal(mockEnqueueSize);
      expect(req.fulfilled).to.be.bignumber.equal(new BN(String(0)));
      expect(req.claimableEther).to.be.bignumber.equal(new BN(String(0)));
    });
  });

  context("transferRequest", function () {
    const mockPricePerShare = new BN(String(2e18)); // pricePerShare
    const mockProcessedBalance = new BN(String(20e18)); // processedBalance
    const denominator = new BN(String(1e18)); // denominator
    const processedgEth = mockProcessedBalance.mul(denominator).div(mockPricePerShare); // processedgEth

    const mockEnqueueTrigger = new BN(String(2e18));
    const mockEnqueueSize = new BN(String(1e18));

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
    it("reverts if request is fulfilled", async function () {
      const mockRealizedPrice = new BN(String(2e18)); // realizedPrice
      await this.contract.$setMockQueueData(
        0,
        new BN(String(8e18)), // Qrealized
        new BN(String(3e18)), // Qfulfilled
        0,
        mockRealizedPrice,
        0
      );
      await this.contract.$fulfill(
        new BN(String(0)) // index
      );

      await expectRevert(
        this.contract.$transferRequest(0, randomAddress, { from: staker }),
        "WML:cannot transfer fulfilled"
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
    const mockPricePerShare = new BN(String(2e18)); // pricePerShare
    const mockProcessedBalance = new BN(String(20e18)); // processedBalance
    const denominator = new BN(String(1e18)); // denominator
    const processedgEth = mockProcessedBalance.mul(denominator).div(mockPricePerShare); // processedgEth

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

      const beforegETHBalance = await this.gETH.balanceOf(this.contract.address, this.poolId);

      await this.contract.$fulfill(
        new BN(String(0)) // index
      );

      const aftergETHBalance = await this.gETH.balanceOf(this.contract.address, this.poolId);
      expect(aftergETHBalance).to.be.bignumber.equal(beforegETHBalance.sub(mockEnqueueSize));

      const req = await this.contract.$getRequestFromLastIndex(0);
      expect(req.fulfilled).to.be.bignumber.equal(mockEnqueueSize);
      expect(req.claimableEther).to.be.bignumber.equal(
        mockEnqueueSize.mul(mockRealizedPrice).div(new BN(String(1e18)))
      );
      expect((await this.contract.$getQueueData()).fulfilled).to.be.bignumber.equal(
        new BN(String(5e18))
      );
    });
  });

  context("fulfillBatch", function () {
    const mockPricePerShare = new BN(String(2e18)); // pricePerShare
    const mockProcessedBalance = new BN(String(20e18)); // processedBalance
    const denominator = new BN(String(1e18)); // denominator
    const processedgEth = mockProcessedBalance.mul(denominator).div(mockPricePerShare); // processedgEth

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

      const beforegETHBalance = await this.gETH.balanceOf(this.contract.address, this.poolId);

      await this.contract.$fulfillBatch(
        [new BN(String(0)), new BN(String(1))] // index
      );

      const aftergETHBalance = await this.gETH.balanceOf(this.contract.address, this.poolId);
      expect(aftergETHBalance).to.be.bignumber.equal(
        beforegETHBalance.sub(mockEnqueueSize0.add(new BN(String(3e18)))) // 3e18 since it can be at most it
      );

      const req0 = await this.contract.$getRequestFromLastIndex(1);
      const req1 = await this.contract.$getRequestFromLastIndex(0);
      expect(req0.fulfilled).to.be.bignumber.equal(mockEnqueueSize0);
      expect(req0.claimableEther).to.be.bignumber.equal(
        new BN(String(2e18)).mul(mockRealizedPrice).div(new BN(String(1e18)))
      );
      expect(req1.fulfilled).to.be.bignumber.equal(new BN(String(3e18))); // 3e18 since it can be at most it
      expect(req1.claimableEther).to.be.bignumber.equal(
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
    const mockPricePerShare = new BN(String(2e18)); // pricePerShare
    const mockProcessedBalance = new BN(String(20e18)); // processedBalance
    const denominator = new BN(String(1e18)); // denominator
    const processedgEth = mockProcessedBalance.mul(denominator).div(mockPricePerShare); // processedgEth

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

    it("reverts if not owner", async function () {
      await this.contract.$fulfill(new BN(String(0)));
      await expectRevert(
        this.contract.$_dequeue(new BN(String(0)), { from: randomAddress }),
        "WML:not owner"
      );
    });
    it("reverts if claimableEther is 0", async function () {
      await expectRevert(
        this.contract.$_dequeue(new BN(String(0)), { from: staker }),
        "WML:not claimable"
      );
    });
    it("success", async function () {
      await this.contract.$fulfill(new BN(String(0)));

      // to get the return value, not changing the state
      const claimableEther = await this.contract.$_dequeue.call(new BN(String(0)), {
        from: staker,
      });
      await this.contract.$_dequeue(new BN(String(0)), { from: staker });
      expect(claimableEther).to.be.bignumber.equal(
        mockEnqueueSize.mul(mockRealizedPrice).div(new BN(String(1e18)))
      );
      expect(
        (await this.contract.$getRequestFromLastIndex(0)).claimableEther
      ).to.be.bignumber.equal(new BN(String(0)));
    });
  });

  context("dequeue", function () {
    const mockEnqueueTrigger = new BN(String(3e18)); // Rtrigger
    const mockEnqueueSize = new BN(String(2e18)); // Rsize
    const mockRealizedPrice = new BN(String(2e18)); // realizedPrice
    const mockPricePerShare = new BN(String(2e18)); // pricePerShare
    const mockProcessedBalance = new BN(String(20e18)); // processedBalance
    const denominator = new BN(String(1e18)); // denominator
    const processedgEth = mockProcessedBalance.mul(denominator).div(mockPricePerShare); // processedgEth

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

    it("reverts if receiver is ZERO_ADDRESS", async function () {
      await expectRevert(
        this.contract.$dequeue(new BN(String(0)), ZERO_ADDRESS, { from: staker }),
        "WML:receiver cannot be zero address"
      );
    });
    it("reverts if wp does not have enough balance", async function () {
      await expectRevert(
        this.contract.$dequeue(new BN(String(0)), randomAddress, { from: staker }),
        "WML:Failed to send Ether"
      );
    });
    it("success", async function () {
      const [deployer] = await ethers.getSigners();
      await deployer.sendTransaction({
        to: this.contract.address,
        value: ethers.parseEther("10").toString(), // sends 10.0 ether
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
    const mockPricePerShare = new BN(String(2e18)); // pricePerShare
    const mockProcessedBalance = new BN(String(20e18)); // processedBalance
    const denominator = new BN(String(1e18)); // denominator
    const processedgEth = mockProcessedBalance.mul(denominator).div(mockPricePerShare); // processedgEth

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

    it("reverts if receiver is ZERO_ADDRESS", async function () {
      await expectRevert(
        this.contract.$dequeueBatch([new BN(String(0)), new BN(String(1))], ZERO_ADDRESS, {
          from: staker,
        }),
        "WML:receiver cannot be zero address"
      );
    });
    it("reverts if WP does not have enough balance", async function () {
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
        value: ethers.parseEther("10.0").toString(), // sends 10.0 ether
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
      await this.contract.$_realizeProcessedEther(mockProcessedBalance);

      const queueData = await this.contract.$getQueueData();
      expect(queueData.realizedPrice).to.be.bignumber.equal(mockPricePerShare);
      expect(queueData.realized).to.be.bignumber.equal(processedgEth);
      expect(queueData.realizedEtherBalance).to.be.bignumber.equal(mockProcessedBalance);
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
      await this.contract.$_realizeProcessedEther(mockProcessedBalance);

      const queueData = await this.contract.$getQueueData();
      expect(queueData.realizedPrice).to.be.bignumber.equal(mockPricePerShare);
      expect(queueData.realized).to.be.bignumber.equal(mockQrealized.add(processedgEth));
      expect(queueData.realizedEtherBalance).to.be.bignumber.equal(mockProcessedBalance);
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
      await this.contract.$_realizeProcessedEther(mockProcessedBalance);

      const queueData = await this.contract.$getQueueData();
      expect(queueData.realizedPrice).to.be.bignumber.equal(
        claimable
          .mul(mockRealizedPrice)
          .add(mockProcessedBalance.mul(denominator))
          .div(claimable.add(processedgEth))
      );
      expect(queueData.realized).to.be.bignumber.equal(mockQrealized.add(processedgEth));
      expect(queueData.realizedEtherBalance).to.be.bignumber.equal(mockProcessedBalance);
    });
  });

  context("validator creation needed tests", function () {
    const pubkey0 =
      "0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a";
    const pubkey1 =
      "0xa3b3eb55b16999ffeff52e5a898af89e4194b7221b2eaf03cb85fd558a390dc042beba94f907db6091b4cf141b18d1f5";
    const pubkeyNotExists =
      "0x986e1dee05f3a018bab83343b3b3d96dd573a50ffb03e8145b2964a389ceb14cb3780266b99ef7cf0e16ee34648e2151";
    const pubkey2 =
      "0x8c104d1e9cdf2c1bdd107b34bbd2c060de8a2fab1cfb3ee15bb2334d18b878f2d151cfd8c98fba6eb60df917eb02b7f9";
    const pubkey3 =
      "0xb49c13f4b8ffad378bac0c89eeb8f4087cd763f9f72860a4e176ea4681020d9ee7856279d6a53e6f609b8a97f2cfbc0b";
    const pubkey4 =
      "0x8a8bb626ef9dfb4573a868fca0e9a9e1baf814ef83d393a4f5373593864ee6800eff284a215374d3fc938db8e81fc71b";
    const otherPoolPubkey0 =
      "0x850b60aee6ef58ec9c422e71d8112d4d47f2b780ac3f781cee966f4019c4085bd891055a5ec72c10555ed1545d64ec66";

    const signature01 =
      "0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181";
    const signature11 =
      "0xa2e94c3def1e53d7d1b5a0f037f765868b4bbae3ee59de673bc7ab7b142b929e08f47c1c2a6cdc91aee9442468ab095406b8ce356aef42403febe385424f97d6d109f6423dcb1acc3def45af56e4407416f0773bd18e50d880cb7d3e00ca9932";
    const signature21 =
      "0xa6175becfef2d233fd494bc46ed57db5478ebe94d8cc107a014c9cacae155a3a11f71f092018a98328e2852bf99dde67123c71c7a755cc0aa2bca1104da812a5aea39d72dbbcf48c9b69abf4f7d6280709b1db69c14f7dacdbdbdda298959b8b";
    const signature31 =
      "0xa7a63f12df0cdb8ee84d2a8d65f7d6a9ea8099a1454388d469ace34e7cc165a6748c9490404aead4e4bbd02bc117212e0b0f41e75eb5547f7ea618cc82a6dce8bf414a24bc2b84317075d8e54638e2ec846e54e78afa7d4e9fac2887c84e1cc0";
    const signature41 =
      "0xb0db285096f2eec2a3e17a4d40b4c19ed2fc6e8c91132bb3d168f5fd97ba2910289025dfde92e02f15d1ed9f323c6033016903b19b02180507fe2dd08c9a77bfed5477fbfa59f144c5b40351dce04eef497fb7df90553709947e7e053a8933d6";
    const otherPoolSignature01 =
      "0xb550a2cf6adff7b32595346a1647adfd09b20dd0ae133adefc220be810d66e9c62a6d11152fb453ca378ec26ff78750d12d298144907f0aa8c695f1b44050b0d2bb535d662c4b616e9e5666689f80117ede1db94f1080510eb9d5fd867c1b737";

    const signature031 =
      "0xa58af51205a996c87f23c80aeb3cb669001e3f919a88598d063ff6cee9b05fbb8a18dab15a4a5b85eabfd47c26d0f24f11f5f889f6a7fb8cbd5c4ccd7607c449b57a9f0703e1bb63b513cb3e9fcd1d79b0d8f269c7441173054b9284cfb7a13c";
    const signature131 =
      "0xa7290722d0b9350504fd44cd166fabc85db76fab07fb2876bff51e0ede2856e6160e4288853cf713cbf3cd7a0541ab1d0ed5e0858c980870f3a4c791264d8b4ee090677f507b599409e86433590ee3a93cae5103d2e03c66bea623e3ccd590ae";
    const signature231 =
      "0xae46112c21f86fd0061fedbd77da0f2b6e6aef494bcde7836e75329732af07cff42a3024b58c8281fc51f658f821271811f6b4e991564352a46edaadc5efcff064253598ae3b7193f166f4a892dee048ff9b15311a686f5cd5255cb9aad067ed";
    const signature331 =
      "0x83d9f2df7a87994f4ea9b68cf61ed800d1e1c8ea01ad42d7c286eb5fec81fc66cd8088bb0bc6f35399c313de63169a340366a62748647c8aae09c6c0bd3985937e3509475adc21df2bb441353e37269a0c79100c7b3273038327225146389ed5";
    const signature431 =
      "0x8e3776be0a15f2570c257d78508827cb319e8a8f18ffcf423e241c93b60be9a95a8dbc6f0cfc7a539709bd0fd7a2208a163e6b5735b5bae2195549aedf6b5c0d535ca2fc976a74d1ea6319041ef9c2f5e47ba00664f2022556a4c94adcd9c147";
    const otherPoolSignature031 =
      "0xa7e2415318b51cc034f552f98031e6822db8dc0463e79aec78334fba302bd33f24056631f9eaad52b90cd38d26e624c015da759dc6ef2277e8db62ced4f15433ce9bf613f6c93856ea961ea03b5938199d4cf1dd41f3f3b31e46d91b9b01157d";

    beforeEach(async function () {
      await this.SMLM.deposit(this.poolId, 0, [], 0, MAX_UINT256, staker, {
        from: poolOwner,
        value: new BN(String(160e18)),
      });

      await this.SMLM.$set_MONOPOLY_THRESHOLD(MONOPOLY_THRESHOLD);
      await this.SMLM.delegate(this.poolId, [this.operatorId], [5], {
        from: poolMaintainer,
      });

      await this.SMLM.proposeStake(
        this.poolId,
        this.operatorId,
        [pubkey0, pubkey1, pubkey2, pubkey3, pubkey4],
        [signature01, signature11, signature21, signature31, signature41],
        [signature031, signature131, signature231, signature331, signature431],
        {
          from: operatorMaintainer,
        }
      );
    });

    describe("canFinalizeExit", function () {
      const mockBeaconBalance = new BN(String(10e18));
      let ts;

      beforeEach(async function () {
        // set mock contract as withdrawalPackage
        await this.SMLM.$writeAddress(
          this.poolId,
          strToBytes32("withdrawalPackage"),
          this.contract.address
        );

        await this.SMLM.$set_VERIFICATION_INDEX(1);
        const tx = await this.SMLM.stake(this.operatorId, [pubkey0], {
          from: operatorMaintainer,
        });
        ts = new BN((await getReceiptTimestamp(tx)).toString());
      });
      it("reverts if validator not exists or not belong to that pool", async function () {
        await expectRevert(
          this.contract.$canFinalizeExit(pubkeyNotExists),
          "WML:validator for an unknown pool"
        );
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
        const delay = DAY.muln(91);
        await setTimestamp(ts.add(delay).toNumber());

        const mockCommonPoll = new BN(String(20e18));
        await this.contract.$checkAndRequestExit(pubkey0, mockCommonPoll);
        const val = await this.SMLM.getValidator(pubkey0);
        expect(val.state).to.be.bignumber.equal(new BN(String(3))); // EXIT_REQUESTED;
        expect(await this.contract.$canFinalizeExit(pubkey0)).to.be.equal(true);
      });
    });

    describe("checkAndRequestExit", function () {
      let ts;

      const mockBeaconBalance = new BN(String(10e18));
      const mockWithdrawnBalance = new BN(String(2e18));
      const mockPrice = new BN(String(15e17));
      const mockCommonPoll = new BN(String(2e18));

      beforeEach(async function () {
        await this.SMLM.$set_PricePerShare(mockPrice, this.poolId);
        await this.contract.$setMockQueueData(0, 0, 0, 0, 0, mockCommonPoll);

        await this.SMLM.$set_VERIFICATION_INDEX(1);

        const tx = await this.SMLM.stake(this.operatorId, [pubkey0], {
          from: operatorMaintainer,
        });
        ts = new BN((await getReceiptTimestamp(tx)).toString());

        // set mock contract as withdrawalPackage
        await this.SMLM.$writeAddress(
          this.poolId,
          strToBytes32("withdrawalPackage"),
          this.contract.address
        );
      });
      it("if commonPoll + validatorPoll is not bigger than validatorThreshold, returns commonPoll as it is and status stay ACTIVE", async function () {
        const delay = DAY.muln(91);
        await setTimestamp(ts.add(delay).toNumber());

        const mockValidatorPoll = new BN(String(1e18));
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        await this.contract.$checkAndRequestExit(pubkey0, mockCommonPoll);
        const queueData = await this.contract.$getQueueData();
        const val = await this.SMLM.getValidator(pubkey0);

        expect(queueData.commonPoll).to.be.bignumber.equal(mockCommonPoll);
        expect(val.state).to.be.bignumber.equal(new BN(String(2))); // ACTIVE;
      });
      it("nothing changes when: 'validator state changes to EXIT_REQUESTED and commonPoll increases if commonPoll + validatorPoll bigger than validatorThreshold and validatorPoll is bigger than beaconBalancePriced'", async function () {
        const mockValidatorPoll = new BN(String(18e18)); // beaconBalance for validator is set to 10e18 and price set to 15e17 so 10e18 * 15e17 / 1e18 = 15e18 is bigger than beaconBalancePriced

        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        const beforeCommonPoll = (await this.contract.$getQueueData()).commonPoll;
        const beforeValState = (await this.SMLM.getValidator(pubkey0)).state;

        await this.contract.$checkAndRequestExit(pubkey0, mockCommonPoll);

        const afterCommonPoll = (await this.contract.$getQueueData()).commonPoll;
        const afterValState = (await this.SMLM.getValidator(pubkey0)).state;

        expect(beforeValState).to.be.bignumber.equal(afterValState); // no difference;
        expect(beforeCommonPoll).to.be.bignumber.equal(afterCommonPoll);
      });
      it("validator state changes to EXIT_REQUESTED and commonPoll increases if commonPoll + validatorPoll bigger than validatorThreshold and validatorPoll is bigger than beaconBalancePriced", async function () {
        const delay = DAY.muln(91);
        await setTimestamp(ts.add(delay).toNumber());

        const mockValidatorPoll = new BN(String(18e18)); // beaconBalance for validator is set to 10e18 and price set to 15e17 so 10e18 * 15e17 / 1e18 = 15e18 is bigger than beaconBalancePriced
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        const { beaconBalancePriced } = await this.contract.$getValidatorThreshold(pubkey0);

        const newCommonPoll = await this.contract.$checkAndRequestExit.call(
          pubkey0,
          mockCommonPoll
        );
        await this.contract.$checkAndRequestExit(pubkey0, mockCommonPoll);

        const val = await this.SMLM.getValidator(pubkey0);
        expect(val.state).to.be.bignumber.equal(new BN(String(3))); // EXIT_REQUESTED;
        expect(newCommonPoll).to.be.bignumber.equal(
          mockCommonPoll.add(mockValidatorPoll.sub(beaconBalancePriced))
        );
      });
      it("nothing changes when: 'validator state changes to EXIT_REQUESTED and commonPoll stays same if commonPoll + validatorPoll bigger than validatorThreshold and validatorPoll is bigger than validatorThreshold and smaller than beaconBalancePriced'", async function () {
        const mockValidatorPoll = new BN(String(65e17));
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        const beforeCommonPoll = (await this.contract.$getQueueData()).commonPoll;
        const beforeValState = (await this.SMLM.getValidator(pubkey0)).state;

        await this.contract.$checkAndRequestExit(pubkey0, mockCommonPoll);

        const afterCommonPoll = (await this.contract.$getQueueData()).commonPoll;
        const afterValState = (await this.SMLM.getValidator(pubkey0)).state;

        expect(beforeValState).to.be.bignumber.equal(afterValState); // no difference;
        expect(beforeCommonPoll).to.be.bignumber.equal(afterCommonPoll);
      });
      it("validator state changes to EXIT_REQUESTED and commonPoll stays same if commonPoll + validatorPoll bigger than validatorThreshold and validatorPoll is bigger than validatorThreshold and smaller than beaconBalancePriced", async function () {
        const delay = DAY.muln(91);
        await setTimestamp(ts.add(delay).toNumber());

        const mockValidatorPoll = new BN(String(65e17));
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        const newCommonPoll = await this.contract.$checkAndRequestExit.call(
          pubkey0,
          mockCommonPoll
        );
        await this.contract.$checkAndRequestExit(pubkey0, mockCommonPoll);

        const val = await this.SMLM.getValidator(pubkey0);
        expect(val.state).to.be.bignumber.equal(new BN(String(3))); // EXIT_REQUESTED;
        expect(newCommonPoll).to.be.bignumber.equal(mockCommonPoll);
      });
      it("nothing changes when: 'validator state changes to EXIT_REQUESTED and commonPoll decreases if commonPoll + validatorPoll bigger than validatorThreshold and validatorPoll is smaller than validatorThreshold'", async function () {
        const mockValidatorPoll = new BN(String(3e18));
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        const beforeCommonPoll = (await this.contract.$getQueueData()).commonPoll;
        const beforeValState = (await this.SMLM.getValidator(pubkey0)).state;

        await this.contract.$checkAndRequestExit(pubkey0, mockCommonPoll);

        const afterCommonPoll = (await this.contract.$getQueueData()).commonPoll;
        const afterValState = (await this.SMLM.getValidator(pubkey0)).state;

        expect(beforeValState).to.be.bignumber.equal(afterValState); // no difference;
        expect(beforeCommonPoll).to.be.bignumber.equal(afterCommonPoll);
      });
      it("validator state changes to EXIT_REQUESTED and commonPoll decreases if commonPoll + validatorPoll bigger than validatorThreshold and validatorPoll is smaller than validatorThreshold", async function () {
        const delay = DAY.muln(91);
        await setTimestamp(ts.add(delay).toNumber());

        const mockValidatorPoll = new BN(String(3e18));
        await this.contract.$setMockValidatorData(
          pubkey0,
          mockBeaconBalance,
          mockWithdrawnBalance,
          mockValidatorPoll
        );

        const { threshold } = await this.contract.$getValidatorThreshold(pubkey0);

        const newCommonPoll = await this.contract.$checkAndRequestExit.call(
          pubkey0,
          mockCommonPoll
        );
        await this.contract.$checkAndRequestExit(pubkey0, mockCommonPoll);

        const val = await this.SMLM.getValidator(pubkey0);
        expect(val.state).to.be.bignumber.equal(new BN(String(3))); // EXIT_REQUESTED;
        expect(newCommonPoll).to.be.bignumber.equal(
          mockCommonPoll.sub(threshold.sub(mockValidatorPoll))
        );
      });
    });

    context("_vote", function () {
      const mockVoteSize = new BN(String(2e16));
      it("reverts if validator not belong to pool", async function () {
        await expectRevert(
          this.contract.$_vote(31, pubkeyNotExists, mockVoteSize),
          "WML:vote for an unknown pool"
        );
      });
      it("reverts if validator not active", async function () {
        await expectRevert(
          this.contract.$_vote(31, pubkey0, mockVoteSize),
          "WML:voted for inactive validator"
        );
      });
      it("success", async function () {
        await this.SMLM.$set_VERIFICATION_INDEX(1);
        await this.SMLM.stake(this.operatorId, [pubkey0], {
          from: operatorMaintainer,
        });
        await this.contract.$_vote(31, pubkey0, mockVoteSize);
        await this.contract.$_vote(31, pubkey0, mockVoteSize.muln(2));

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

        // set mock contract as withdrawalPackage
        await this.SMLM.$writeAddress(
          this.poolId,
          strToBytes32("withdrawalPackage"),
          this.contract.address
        );

        // set mock price
        await this.SMLM.$set_PricePerShare(mockPrice, this.poolId);

        // make validator active
        await this.SMLM.$set_VERIFICATION_INDEX(1);
        await this.SMLM.stake(this.operatorId, [pubkey0], {
          from: operatorMaintainer,
        });

        // need this since WP is not approved by deployment
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
        expect(req.claimableEther).to.be.bignumber.equal(new BN(String(0)));

        const queueData = await this.contract.$getQueueData();
        expect(queueData.requested).to.be.bignumber.equal(mockRequested.add(mockRequestSize));
        expect(queueData.commonPoll).to.be.bignumber.equal(mockCommonPoll.add(mockRequestSize));

        expect(afterStakerBalance).to.be.bignumber.equal(beforeStakerBalance.sub(mockRequestSize));
      });

      it("if pubkey is given, put vote and commonPoll arranged accordingly", async function () {
        const mockRequestSize = new BN(String(12e18));

        const beforeStakerBalance = await this.gETH.balanceOf(staker, this.poolId);
        await this.contract.$enqueue(mockRequestSize, pubkey0, staker, { from: staker });
        const afterStakerBalance = await this.gETH.balanceOf(staker, this.poolId);

        const req = await this.contract.$getRequestFromLastIndex(0);
        expect(req.owner).to.be.equal(staker);
        expect(req.trigger).to.be.bignumber.equal(mockRequested);
        expect(req.size).to.be.bignumber.equal(mockRequestSize);
        expect(req.fulfilled).to.be.bignumber.equal(new BN(String(0)));
        expect(req.claimableEther).to.be.bignumber.equal(new BN(String(0)));

        const queueData = await this.contract.$getQueueData();
        expect(queueData.requested).to.be.bignumber.equal(mockRequested.add(mockRequestSize));
        expect(queueData.commonPoll).to.be.bignumber.equal(mockCommonPoll);

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

        // set mock contract as withdrawalPackage
        await this.SMLM.$writeAddress(
          this.poolId,
          strToBytes32("withdrawalPackage"),
          this.contract.address
        );

        // set mock price
        await this.SMLM.$set_PricePerShare(mockPrice, this.poolId);

        // make validators active
        await this.SMLM.$set_VERIFICATION_INDEX(2);
        await this.SMLM.stake(this.operatorId, [pubkey0, pubkey1], {
          from: operatorMaintainer,
        });

        // need this since WP is not approved by deployment
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
        const mockRequestSize1 = new BN(String(12e18));

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
        expect(req0.claimableEther).to.be.bignumber.equal(new BN(String(0)));
        const req1 = await this.contract.$getRequestFromLastIndex(0);
        expect(req1.owner).to.be.equal(staker);
        expect(req1.trigger).to.be.bignumber.equal(
          mockRequested.add(mockRequestSize0).add(mockRequestSizeCommon)
        );
        expect(req1.size).to.be.bignumber.equal(mockRequestSize1);
        expect(req1.fulfilled).to.be.bignumber.equal(new BN(String(0)));
        expect(req1.claimableEther).to.be.bignumber.equal(new BN(String(0)));

        const threshold0 = (await this.contract.$getValidatorThreshold(pubkey0)).threshold;
        const queueData = await this.contract.$getQueueData();
        expect(queueData.requested).to.be.bignumber.equal(
          mockRequested.add(mockRequestSizeCommon).add(mockRequestSize0).add(mockRequestSize1)
        );

        expect(queueData.commonPoll).to.be.bignumber.equal(
          mockCommonPoll.add(mockRequestSizeCommon)
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
      it("reverts if reportedWithdrawn is not bigger than processedWithdrawn", async function () {
        await expectRevert.unspecified(
          this.contract.$_distributeFees(pubkey0, new BN(String(1e18)), new BN(String(2e18)))
        );
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

    describe("processValidators", function () {
      let tree;
      let ts;
      let proofs = [];
      const pks = [pubkey0, pubkey1, pubkey2, pubkey3, pubkey4];
      const beaconBalances = [
        String(0),
        String(0),
        String(32e18),
        String(32e18),
        String(30e18),
        String(32e18), // otherPool
      ];
      const withdrawnBalances = [
        String(31e18),
        String(34e18),
        String(1e18),
        String(7e18), // 5e18 previously now 7e18 so profit from here will be 2e18
        String(0),
        String(1e18), // otherPool
      ];

      const beaconBalancesBN = [
        new BN(String(0)),
        new BN(String(0)),
        new BN(String(32e18)),
        new BN(String(32e18)),
        new BN(String(30e18)),
      ];
      const withdrawnBalancesBN = [
        new BN(String(31e18)),
        new BN(String(34e18)),
        new BN(String(1e18)),
        new BN(String(7e18)), // 5e18 previously now 7e18 so profit from here will be 2e18
        new BN(String(0)),
      ];
      // const isExited = [true, true, false, false, false];

      let profit = new BN(String(0e18))
        .add(new BN(String(2e18)))
        .add(new BN(String(1e18)))
        .add(new BN(String(2e18)));
      const fees = profit.mul(new BN(String(17))).div(new BN(String(100))); // 17% fee
      profit = profit.add(new BN(String(31e18))).add(new BN(String(32e18))); // 31e18 and 32e18 are the beaconBalances of validators who exited without fees

      beforeEach(async function () {
        // add money to contract to distribute fees
        await this.contract.send(new BN(String(160e18)));

        // this assumption is needed for the test to work
        // but actually it is a problem since there is a possiblity
        // that processValidators is called before any enqueue
        // which means that there is no gETH to burn and it will revert
        await this.gETH.safeTransferFrom(
          staker,
          this.contract.address,
          this.poolId,
          new BN(String(100e18)),
          strToBytes(""),
          { from: staker }
        );

        // make validators active
        await this.SMLM.$set_VERIFICATION_INDEX(5);

        const tx = await this.SMLM.stake(
          this.operatorId,
          [pubkey0, pubkey1, pubkey2, pubkey3, pubkey4],
          {
            from: operatorMaintainer,
          }
        );
        ts = new BN((await getReceiptTimestamp(tx)).toString());
        const delay = DAY.muln(91);
        await setTimestamp(ts.add(delay).toNumber());

        // set mock contract as withdrawalPackage
        await this.SMLM.$writeAddress(
          this.poolId,
          strToBytes32("withdrawalPackage"),
          this.contract.address
        );

        const values = [
          [pks[0], beaconBalances[0], withdrawnBalances[0]],
          [pks[1], beaconBalances[1], withdrawnBalances[1]],
          [pks[2], beaconBalances[2], withdrawnBalances[2]],
          [pks[3], beaconBalances[3], withdrawnBalances[3]],
          [pks[4], beaconBalances[4], withdrawnBalances[4]],
          [otherPoolPubkey0, beaconBalances[5], withdrawnBalances[5]],
        ];

        tree = StandardMerkleTree.of(values, ["bytes", "uint256", "uint256"]);
        proofs = [];
        for (let i = 0; i < pks.length; i++) {
          proofs.push(tree.getProof(i));
        }

        await this.SMLM.reportBeacon(strToBytes32("not important"), tree.root, 50001, {
          from: oracle,
        });

        // set validator data to check the cumulative withdrawn balance
        await this.contract.$setMockValidatorData(
          pks[3],
          new BN(String(20e18)),
          new BN(String(5e18)),
          new BN(String(0))
        );

        // set pricePerShare
        await this.SMLM.$set_PricePerShare(new BN(String(2e18)), this.poolId);

        // set mock commonPoll to check the exit of validator
        await this.contract.$setMockQueueData(0, 0, 0, 0, 0, new BN(String(10e18))); // so commonPoll will left 4e17 afterwards since threshold is 9.6e18 for pk[3] which is the only one can utilize the commonPoll
      });

      it("reverts if lengths of arrays are not matching", async function () {
        await expectRevert(
          this.contract.$processValidators(
            pks.slice(1),
            beaconBalancesBN,
            withdrawnBalancesBN,
            proofs
          ),
          "WML:invalid lengths"
        );
        await expectRevert(
          this.contract.$processValidators(
            pks,
            beaconBalancesBN.slice(1),
            withdrawnBalancesBN,
            proofs
          ),
          "WML:invalid lengths"
        );
        await expectRevert(
          this.contract.$processValidators(
            pks,
            beaconBalancesBN,
            withdrawnBalancesBN.slice(1),
            proofs
          ),
          "WML:invalid lengths"
        );
        await expectRevert(
          this.contract.$processValidators(
            pks,
            beaconBalancesBN,
            withdrawnBalancesBN,
            proofs.slice(1)
          ),
          "WML:invalid lengths"
        );
      });
      it("reverts if not all proofs are valid", async function () {
        proofs[0] = proofs[1];
        await expectRevert(
          this.contract.$processValidators(pks, beaconBalancesBN, withdrawnBalancesBN, proofs),
          "WML:not all proofs are valid"
        );
      });
      it("reverts if not all pubkey belong to the pool", async function () {
        otherPoolId = await this.createPool("otherPool");

        await this.SMLM.deposit(otherPoolId, 0, [], 0, MAX_UINT256, staker, {
          from: poolOwner,
          value: new BN(String(160e18)),
        });

        await this.SMLM.delegate(otherPoolId, [this.operatorId], [1], {
          from: poolMaintainer,
        });

        await this.SMLM.proposeStake(
          otherPoolId,
          this.operatorId,
          [otherPoolPubkey0],
          [otherPoolSignature01],
          [otherPoolSignature031],
          {
            from: operatorMaintainer,
          }
        );

        await this.gETH.safeTransferFrom(
          staker,
          this.contract.address,
          otherPoolId,
          new BN(String(100e18)),
          strToBytes(""),
          { from: staker }
        );

        // make validators active
        await this.SMLM.$set_VERIFICATION_INDEX(6);

        const tx = await this.SMLM.stake(this.operatorId, [otherPoolPubkey0], {
          from: operatorMaintainer,
        });
        ts = new BN((await getReceiptTimestamp(tx)).toString());
        const delay = DAY.muln(91);
        await setTimestamp(ts.add(delay).toNumber());

        // set mock contract as withdrawalPackage
        await this.SMLM.$writeAddress(
          otherPoolId,
          strToBytes32("withdrawalPackage"),
          this.contract.address
        );

        const tempPks = pks.concat([otherPoolPubkey0]);
        const tempBeaconBalancesBN = beaconBalancesBN.concat([new BN(String(32e18))]);
        const tempWithdrawnBalancesBN = withdrawnBalancesBN.concat([new BN(String(1e18))]);
        const tempProofs = proofs.concat([tree.getProof(pks.length - 1)]);

        await expectRevert(
          this.contract.$processValidators(
            tempPks,
            tempBeaconBalancesBN,
            tempWithdrawnBalancesBN,
            tempProofs
          ),
          "WML:validator for an unknown pool"
        );
      });
      it("success", async function () {
        await this.contract.$processValidators(pks, beaconBalancesBN, withdrawnBalancesBN, proofs);

        for (let i = 0; i < pks.length; i++) {
          const val = await this.contract.$getValidatorData(pks[i]);
          expect(val.beaconBalance).to.be.bignumber.equal(beaconBalancesBN[i]);
          expect(val.withdrawnBalance).to.be.bignumber.equal(withdrawnBalancesBN[i]);
        }

        const queueData = await this.contract.$getQueueData();
        expect(queueData.realizedEtherBalance).to.be.bignumber.equal(profit.sub(fees));
        expect(queueData.commonPoll).to.be.bignumber.equal(new BN(String(4e17)));
      });
    });
  });
});
