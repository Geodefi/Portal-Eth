const { expect } = require("chai");

const { expectRevert, expectEvent, constants, BN, balance } = require("@openzeppelin/test-helpers");
const { ZERO_BYTES32, ZERO_ADDRESS, MAX_UINT256 } = constants;
const {
  PERCENTAGE_DENOMINATOR,
  DAY,
  getBlockTimestamp,
  strToBytes,
  intToBytes32,
  strToBytes32,
  getReceiptTimestamp,
  ETHER_STR,
  setTimestamp,
  generateAddress,
} = require("../../../utils");
const { artifacts } = require("hardhat");

const StakeModuleLib = artifacts.require("StakeModuleLib");
const LiquidityModuleLib = artifacts.require("LiquidityModuleLib");
const GeodeModuleLib = artifacts.require("GeodeModuleLib");
const OracleExtensionLib = artifacts.require("OracleExtensionLib");

const StakeModuleLibMock = artifacts.require("$StakeModuleLibMock");

const gETH = artifacts.require("gETH");

const ERC20Middleware = artifacts.require("ERC20Middleware");

const LiquidityPool = artifacts.require("LiquidityPool");

const WithdrawalContract = artifacts.require("WithdrawalContract");

contract("StakeModuleLib", function (accounts) {
  const [
    deployer,
    oracle,
    operatorOwner,
    maliciousOperatorOwner,
    poolOwner,
    operatorMaintainer,
    maliciousOperatorMaintainer,
    poolMaintainer,
    staker,
    attacker,
  ] = accounts;

  const MAX_MAINTENANCE_FEE = PERCENTAGE_DENOMINATOR.divn(100).muln(10);
  const MAX_ALLOWANCE = new BN("1000000").addn(1);
  const MIN_VALIDATOR_PERIOD = DAY.muln(90);
  const MAX_VALIDATOR_PERIOD = DAY.muln(2).muln(365);
  const SWITCH_LATENCY = DAY.muln(3);
  const PRISON_SENTENCE = DAY.muln(14);
  const MONOPOLY_THRESHOLD = new BN("50000");
  const IGNORABLE_DEBT = new BN(String(1e18));

  const operatorFee = new BN(String(8e8)); // 8%
  const poolFee = new BN(String(9e8)); // 9%

  const fallbackThreshold = PERCENTAGE_DENOMINATOR.divn(100).muln(80);

  const unknownName = "unknown";
  const operatorName = "myOperator";
  const maliciousOperatorName = "maliciousOperator";
  let poolNames = ["publicPool", "privatePool", "liquidPool"];

  let unknownId;
  let operatorId;
  let poolIds;

  const liquidityPackageName = "LiquidityPool";
  let liquidityPackageId;

  const withdrawalPackageName = "WithdrawalContract";
  let withdrawalPackageId;

  const middlewareName = "erc20";
  let middlewareId;
  let middlewareData;

  const setLiquidityPackage = async function (packageAddress) {
    await this.contract.$writeUint(liquidityPackageId, strToBytes32("TYPE"), 10021);
    await this.contract.$writeAddress(
      liquidityPackageId,
      strToBytes32("CONTROLLER"),
      packageAddress
    );
    await this.contract.$writeBytes(
      liquidityPackageId,
      strToBytes32("NAME"),
      strToBytes(liquidityPackageName)
    );
    await this.contract.$set_package(10021, liquidityPackageId);
  };

  const setWithdrawalPackage = async function (packageAddress) {
    await this.contract.$writeUint(withdrawalPackageId, strToBytes32("TYPE"), 10011);
    await this.contract.$writeAddress(
      withdrawalPackageId,
      strToBytes32("CONTROLLER"),
      packageAddress
    );
    await this.contract.$writeBytes(
      withdrawalPackageId,
      strToBytes32("NAME"),
      strToBytes(withdrawalPackageName)
    );
    await this.contract.$set_package(10011, withdrawalPackageId);
  };

  const setMiddleware = async function (middlewareAddress) {
    await this.contract.$writeUint(middlewareId, strToBytes32("TYPE"), 20011);
    await this.contract.$writeAddress(middlewareId, strToBytes32("CONTROLLER"), middlewareAddress);
    await this.contract.$set_middleware(20011, middlewareId);
  };

  before(async function () {
    const GML = await GeodeModuleLib.new();
    const LML = await LiquidityModuleLib.new();
    const SML = await StakeModuleLib.new();
    const OEL = await OracleExtensionLib.new();

    await LiquidityPool.link(GML);
    await LiquidityPool.link(LML);

    await WithdrawalContract.link(GML);

    await StakeModuleLibMock.link(SML);
    await StakeModuleLibMock.link(OEL);

    const contract = await StakeModuleLibMock.new({ from: deployer });

    operatorId = await contract.generateId(operatorName, 4);
    maliciousOperatorId = await contract.generateId(maliciousOperatorName, 4);
    poolIds = await Promise.all(
      poolNames.map(async function (e) {
        return await contract.generateId(e, 5);
      })
    );
    unknownId = await contract.generateId(unknownName, 99);

    poolNames = poolNames.map((e) => strToBytes(e));

    withdrawalPackageId = await contract.generateId(withdrawalPackageName, 10011); // 10011 = PACKAGE_WITHDRAWAL_CONTRACT
    liquidityPackageId = await contract.generateId(liquidityPackageName, 10021); // 10021 = PACKAGE_LIQUIDITY_POOL

    middlewareId = await contract.generateId(middlewareName, 20011); // 20011 = MIDDLEWARE_GETH
    const nameBytes = strToBytes("myPool Ether").substr(2);
    const symbolBytes = strToBytes("mpETH").substr(2);
    middlewareData = intToBytes32(nameBytes.length / 2) + nameBytes + symbolBytes;
    this.middleware = await ERC20Middleware.new({
      from: deployer,
    });

    this.setLP = setLiquidityPackage;
    this.setWP = setWithdrawalPackage;
    this.setMiddleware = setMiddleware;

    this.lpTokenImp = (await artifacts.require("LPToken").new()).address;
  });

  beforeEach(async function () {
    this.gETH = await gETH.new("name", "symbol", "uri", { from: deployer });

    this.contract = await StakeModuleLibMock.new();
    await this.contract.initialize(this.gETH.address, oracle);

    await this.gETH.transferMinterRole(this.contract.address);
    await this.gETH.transferMiddlewareManagerRole(this.contract.address);
    await this.gETH.transferOracleRole(this.contract.address);

    this.LiquidityPool = await LiquidityPool.new(
      this.gETH.address,
      this.contract.address,
      this.lpTokenImp
    );

    this.WithdrawalContract = await WithdrawalContract.new(
      this.gETH.address,
      this.contract.address
    );
  });

  context("__StakeModule_init_unchained", function () {
    it("reverts with gETH=0", async function () {
      await expectRevert(
        (await StakeModuleLibMock.new()).initialize(ZERO_ADDRESS, oracle),
        "SM:gETH cannot be zero address"
      );
    });

    it("reverts with oracle=0", async function () {
      await expectRevert(
        (await StakeModuleLibMock.new()).initialize(this.gETH.address, ZERO_ADDRESS),
        "SM:oracle cannot be zero address"
      );
    });

    context("success", function () {
      let params;
      beforeEach(async function () {
        params = await this.contract.StakeParams();
      });
      it("sets gETH", async function () {
        expect(params.gETH).to.be.equal(this.gETH.address);
      });
      it("sets ORACLE_POSITION", async function () {
        expect(params.oraclePosition).to.be.equal(oracle);
      });
      it("sets DAILY_PRICE_INCREASE_LIMIT", async function () {
        expect(params.dailyPriceIncreaseLimit).to.be.bignumber.equal(
          PERCENTAGE_DENOMINATOR.divn(100).muln(7)
        );
      });
      it("sets DAILY_PRICE_DECREASE_LIMIT", async function () {
        expect(params.dailyPriceDecreaseLimit).to.be.bignumber.equal(
          PERCENTAGE_DENOMINATOR.divn(100).muln(7)
        );
      });
    });
  });
  context("reverts when paused", function () {
    beforeEach(async function () {
      await this.contract.pause();
    });

    it("initiateOperator", async function () {
      await expectRevert(this.contract.initiateOperator(0, 0, 0, ZERO_ADDRESS), "Pausable: paused");
    });
    it("deployLiquidityPool", async function () {
      await expectRevert(this.contract.deployLiquidityPool(0), "Pausable: paused");
    });
    it("initiatePool", async function () {
      await expectRevert(
        this.contract.initiatePool(0, 0, ZERO_ADDRESS, "0x", "0x", [false, false, false]),
        "Pausable: paused"
      );
    });
    it("setYieldReceiver", async function () {
      await expectRevert(this.contract.setYieldReceiver(0, ZERO_ADDRESS), "Pausable: paused");
    });
    it("changeMaintainer", async function () {
      await expectRevert(this.contract.changeMaintainer(0, ZERO_ADDRESS), "Pausable: paused");
    });
    it("switchMaintenanceFee", async function () {
      await expectRevert(this.contract.switchMaintenanceFee(0, 0), "Pausable: paused");
    });
    it("blameOperator", async function () {
      await expectRevert(this.contract.blameOperator("0x"), "Pausable: paused");
    });
    it("switchValidatorPeriod", async function () {
      await expectRevert(this.contract.switchValidatorPeriod(0, 0), "Pausable: paused");
    });
    it("delegate", async function () {
      await expectRevert(this.contract.delegate(0, [], []), "Pausable: paused");
    });
    it("deposit", async function () {
      await expectRevert(this.contract.deposit(0, 0, [], 0, 0, ZERO_ADDRESS), "Pausable: paused");
    });
    it("proposeStake", async function () {
      await expectRevert(this.contract.proposeStake(0, 0, [], [], []), "Pausable: paused");
    });
    it("stake", async function () {
      await expectRevert(this.contract.stake(0, []), "Pausable: paused");
    });
  });

  describe("_authenticate", function () {
    it("reverts if not initiated", async function () {
      await expectRevert(
        this.contract.$_authenticate(0, false, false, [false, false]),
        "SML:not initiated"
      );
    });
    context("initiated", function () {
      beforeEach(async function () {
        await this.contract.$writeUint(unknownId, strToBytes32("initiated"), 1);
      });
      it("reverts if type is not known", async function () {
        await expectRevert(
          this.contract.$_authenticate(unknownId, false, false, [false, false]),
          "SML:invalid TYPE"
        );
      });
      it("reverts if operator, but not expected", async function () {
        await this.contract.$writeUint(unknownId, strToBytes32("TYPE"), 4);
        await expectRevert(
          this.contract.$_authenticate(unknownId, false, false, [false, false]),
          "SML:TYPE NOT allowed"
        );
      });
      it("reverts if pool, but not expected", async function () {
        await this.contract.$writeUint(unknownId, strToBytes32("TYPE"), 5);
        await expectRevert(
          this.contract.$_authenticate(unknownId, false, false, [false, false]),
          "SML:TYPE NOT allowed"
        );
      });
      it("reverts if maintainer is expected but not", async function () {
        await this.contract.$writeUint(unknownId, strToBytes32("TYPE"), 5);
        await expectRevert(
          this.contract.$_authenticate(unknownId, false, true, [false, true]),
          "SML:sender NOT maintainer"
        );
      });
      it("reverts if CONTROLLER is expected but not", async function () {
        await this.contract.$writeUint(unknownId, strToBytes32("TYPE"), 5);
        await expectRevert(
          this.contract.$_authenticate(unknownId, true, false, [false, true]),
          "SML:sender NOT CONTROLLER"
        );
      });
      context("operator & prisoned", function () {
        beforeEach(async function () {
          await this.contract.$writeUint(unknownId, strToBytes32("TYPE"), 4);
          await this.contract.$writeUint(unknownId, strToBytes32("release"), MAX_UINT256);
        });
        it("revert: expectMaintainer", async function () {
          await expectRevert(
            this.contract.$_authenticate(unknownId, false, true, [true, false]),
            "SML:prisoned, get in touch with governance"
          );
        });
        it("revert: expectCONTROLLER", async function () {
          await expectRevert(
            this.contract.$_authenticate(unknownId, true, false, [true, false]),
            "SML:prisoned, get in touch with governance"
          );
        });
        it("does not revert: NOT expectMaintainer, NOT expectCONTROLLER ", async function () {
          await this.contract.$_authenticate(unknownId, false, false, [true, false]);
        });
      });
    });
  });

  context("initiators", function () {
    context("Operator", function () {
      describe("initiateOperator", function () {
        it("reverts: if already initiated", async function () {
          await this.contract.$writeUint(unknownId, strToBytes32("initiated"), 1);
          await expectRevert(
            this.contract.initiateOperator(unknownId, 0, 0, ZERO_ADDRESS),
            "SML:already initiated"
          );
        });
        it("reverts: if unknown TYPE", async function () {
          await this.contract.$writeUint(unknownId, strToBytes32("TYPE"), 5);
          await expectRevert(
            this.contract.initiateOperator(unknownId, 0, 0, ZERO_ADDRESS),
            "SML:TYPE NOT allowed"
          );
        });
        it("reverts: if not CONTROLLER", async function () {
          await this.contract.$writeUint(unknownId, strToBytes32("TYPE"), 4);
          await expectRevert(
            this.contract.initiateOperator(unknownId, 0, 0, ZERO_ADDRESS),
            "SML:sender NOT CONTROLLER"
          );
        });
        context("success", function () {
          let tx;
          beforeEach(async function () {
            await this.contract.$writeUint(unknownId, strToBytes32("TYPE"), 4);
            await this.contract.$writeAddress(unknownId, strToBytes32("CONTROLLER"), deployer);
            tx = await this.contract.initiateOperator(unknownId, 0, MIN_VALIDATOR_PERIOD, deployer);
          });
          it("sets initiated", async function () {
            expect(
              await this.contract.readUint(unknownId, strToBytes32("initiated"))
            ).to.be.bignumber.equal(await getReceiptTimestamp(tx));
          });
          it("emits IdInitiated", async function () {
            await expectEvent(tx, "IdInitiated", { id: unknownId, TYPE: "4" });
          });
        });
      });
    });

    context("Pool", async function () {
      describe("_setgETHMiddleware", function () {
        beforeEach(async function () {
          await this.contract.$_setgETHMiddleware(unknownId, this.middleware.address);
        });
        it("reverts: if already middleware for id", async function () {
          await expectRevert(
            this.contract.$_setgETHMiddleware(unknownId, this.middleware.address),
            "SML:already middleware"
          );
        });
        it("sets as middleware for id", async function () {
          expect(await this.gETH.isMiddleware(this.middleware.address, unknownId)).to.be.equal(
            true
          );
        });
        it("appends middlewares array of id", async function () {
          expect(
            await this.contract.readUint(unknownId, strToBytes32("middlewares"))
          ).to.be.bignumber.equal("1");
          expect(
            await this.contract.readAddressArray(unknownId, strToBytes32("middlewares"), 0)
          ).to.be.equal(this.middleware.address);
        });
      });
      describe("_deploygETHMiddleware", function () {
        it("reverts: if _versionId is zero", async function () {
          await expectRevert(
            this.contract.$_deploygETHMiddleware(unknownId, 0, "0x"),
            "SML:versionId cannot be 0"
          );
        });
        it("reverts: if _versionId is not allowed", async function () {
          await expectRevert(
            this.contract.$_deploygETHMiddleware(unknownId, 1, "0x"),
            "SML:not a middleware"
          );
        });
        describe("success", async function () {
          beforeEach(async function () {
            await this.setMiddleware(this.middleware.address);
            expect(await this.contract.isMiddleware(20011, middlewareId)).to.be.equal(true);
            await this.contract.$_deploygETHMiddleware(unknownId, middlewareId, middlewareData);
          });
          it("contract avoids", async function () {
            expect(await this.gETH.isAvoider(this.contract.address, unknownId)).to.be.equal(true);
          });
        });
      });
      describe("_deployGeodePackage", function () {
        it("reverts: if _versionId is zero", async function () {
          await expectRevert(
            this.contract.$_deployGeodePackage(10021, 0, "0x"),
            "SML:versionId cannot be 0"
          );
        });
        it("success", async function () {
          await this.setLP(this.LiquidityPool.address);
          await this.contract.$writeAddress(unknownId, strToBytes32("CONTROLLER"), deployer);
          await this.contract.$_deployGeodePackage(unknownId, 10021, strToBytes("poolname"));
        });
      });
      describe("_deployWithdrawalContract", function () {
        beforeEach(async function () {
          await this.setWP(this.WithdrawalContract.address);
          await this.contract.$writeAddress(unknownId, strToBytes32("CONTROLLER"), deployer);
          await this.contract.$_deployWithdrawalContract(unknownId);
        });
        it("reverts: if already deployed", async function () {
          await expectRevert(
            this.contract.$_deployWithdrawalContract(unknownId),
            "SML:already deployed"
          );
        });
        it("sets correct withdrawalCredential", async function () {
          const WCAddress = await this.contract.readAddress(
            unknownId,
            strToBytes32("withdrawalContract")
          );
          const withdrawalCredential = "0x01" + "0000000000000000000000" + WCAddress.substring(2);

          expect(
            await this.contract.readBytes(unknownId, strToBytes32("withdrawalCredential"))
          ).to.be.equal(withdrawalCredential.toLowerCase());
        });
      });

      describe("deployLiquidityPool", function () {
        beforeEach(async function () {
          await this.setLP(this.LiquidityPool.address);
          await this.contract.$writeUint(unknownId, strToBytes32("initiated"), 1);
          await this.contract.$writeUint(unknownId, strToBytes32("TYPE"), 5);
          await this.contract.$writeAddress(unknownId, strToBytes32("CONTROLLER"), deployer);
          await this.contract.deployLiquidityPool(unknownId);
        });
        it("reverts: if already deployed", async function () {
          await expectRevert(this.contract.deployLiquidityPool(unknownId), "SML:already deployed");
        });
        it("sets liquidityPool & approves gETH", async function () {
          const lp = await this.contract.readAddress(unknownId, strToBytes32("liquidityPool"));
          expect(await this.gETH.isApprovedForAll(this.contract.address, lp)).to.be.equal(true);
        });
      });

      describe("initiatePool", function () {
        beforeEach(async function () {
          await this.setWP(this.WithdrawalContract.address);
          expect(await this.contract.getPackageVersion(10011)).to.be.bignumber.equal(
            withdrawalPackageId
          );
          await this.setLP(this.LiquidityPool.address);
          expect(await this.contract.getPackageVersion(10021)).to.be.bignumber.equal(
            liquidityPackageId
          );
          await this.setMiddleware(this.middleware.address);
          expect(await this.contract.isMiddleware(20011, middlewareId)).to.be.equal(true);
        });

        it("reverts: if does not send 32 eth", async function () {
          await expectRevert(
            this.contract.initiatePool(0, 0, ZERO_ADDRESS, "0x", "0x", [false, false, false]),
            "SML:need 1 validator worth of funds"
          );
        });

        context("success", function () {
          let tx;

          beforeEach(async function () {
            tx = await this.contract.initiatePool(
              poolFee,
              middlewareId,
              poolOwner,
              poolNames[0],
              middlewareData,
              [true, true, true],
              { from: poolOwner, value: new BN(String(1e18)).muln(32) }
            );
          });

          it("reverts: if already initiated", async function () {
            await expectRevert(
              this.contract.initiatePool(
                poolFee,
                middlewareId,
                poolOwner,
                poolNames[0],
                middlewareData,
                [true, true, true],
                { from: poolOwner, value: new BN(String(1e18)).muln(32) }
              ),
              "SML:already initiated"
            );
          });
          it("sets initiated", async function () {
            expect(
              await this.contract.readUint(poolIds[0], strToBytes32("initiated"))
            ).to.be.bignumber.equal(await getReceiptTimestamp(tx));
          });
          it("sets TYPE", async function () {
            expect(
              await this.contract.readUint(poolIds[0], strToBytes32("TYPE"))
            ).to.be.bignumber.equal("5");
          });
          it("sets CONTROLLER", async function () {
            expect(
              await this.contract.readAddress(poolIds[0], strToBytes32("CONTROLLER"))
            ).to.be.equal(poolOwner);
          });
          it("sets NAME", async function () {
            expect(await this.contract.readBytes(poolIds[0], strToBytes32("NAME"))).to.be.equal(
              poolNames[0]
            );
          });
          it("adds to allIdsByType", async function () {
            expect(await this.contract.allIdsByTypeLength(5)).to.be.bignumber.equal("1");
            expect(await this.contract.allIdsByType(5, 0)).to.be.bignumber.equal(poolIds[0]);
          });
          it("sets PricePerShare to 1 eth", async function () {
            expect(await this.gETH.pricePerShare(poolIds[0])).to.be.bignumber.equal(ETHER_STR);
          });
          it("sends 32 gETH to owner", async function () {
            expect(await this.gETH.balanceOf(poolOwner, poolIds[0])).to.be.bignumber.equal(
              new BN(String(1e18)).muln(32)
            );
          });
          it("emits IdInitiated with correct id", async function () {
            expectEvent(tx, "IdInitiated", { id: poolIds[0], TYPE: "5" });
          });
          it("returns correct id", function () {
            expectEvent(tx, "return$initiatePool", { poolId: poolIds[0] });
          });
        });

        context("config", function () {
          it("private pool", async function () {
            await this.contract.initiatePool(
              poolFee,
              middlewareId,
              poolOwner,
              poolNames[0],
              "0x",
              [true, false, false],
              { from: poolOwner, value: new BN(String(1e18)).muln(32) }
            );
            expect(await this.contract.isPrivatePool(poolIds[0])).to.be.equal(true);
          });
          it("public pool", async function () {
            await this.contract.initiatePool(
              poolFee,
              middlewareId,
              poolOwner,
              poolNames[0],
              "0x",
              [false, false, false],
              { from: poolOwner, value: new BN(String(1e18)).muln(32) }
            );
            expect(await this.contract.isPrivatePool(poolIds[0])).to.be.equal(false);
          });
          it("gETH middleware", async function () {
            await this.contract.initiatePool(
              poolFee,
              middlewareId,
              poolOwner,
              poolNames[0],
              middlewareData,
              [false, true, false],
              { from: poolOwner, value: new BN(String(1e18)).muln(32) }
            );
            expect(
              await this.contract.readUint(poolIds[0], strToBytes32("middlewares"))
            ).to.be.bignumber.equal("1");
          });
          it("no gETH middleware", async function () {
            await this.contract.initiatePool(
              poolFee,
              middlewareId,
              poolOwner,
              poolNames[0],
              "0x",
              [false, false, false],
              { from: poolOwner, value: new BN(String(1e18)).muln(32) }
            );
            expect(
              await this.contract.readAddress(poolIds[0], strToBytes32("middlewares"))
            ).to.be.bignumber.equal(new BN("0"));
          });
          it("liquidity pool", async function () {
            await this.contract.initiatePool(
              poolFee,
              middlewareId,
              poolOwner,
              poolNames[0],
              "0x",
              [false, false, false],
              { from: poolOwner, value: new BN(String(1e18)).muln(32) }
            );
            expect(
              await this.contract.readAddress(poolIds[0], strToBytes32("liquidityPool"))
            ).to.be.equal(ZERO_ADDRESS);
          });
          it("no liquidity pool", async function () {
            await this.contract.initiatePool(
              poolFee,
              middlewareId,
              poolOwner,
              poolNames[0],
              "0x",
              [false, false, true],
              { from: poolOwner, value: new BN(String(1e18)).muln(32) }
            );
            expect(
              await this.contract.readAddress(poolIds[0], strToBytes32("liquidityPool"))
            ).to.be.not.equal(ZERO_ADDRESS);
          });
        });
      });
    });
  });

  context("initiated 2 operators & 3 pools", function () {
    // operators: benevolent, malicious & pools: publicPoolId, privatePoolId, liquidPoolId
    let publicPoolId;
    let privatePoolId;
    let liquidPoolId;

    beforeEach(async function () {
      // initiate the operators
      await this.contract.$writeUint(operatorId, strToBytes32("TYPE"), 4);
      await this.contract.$writeAddress(operatorId, strToBytes32("CONTROLLER"), operatorOwner);
      tx = await this.contract.initiateOperator(
        operatorId,
        operatorFee,
        MIN_VALIDATOR_PERIOD,
        operatorMaintainer,
        { from: operatorOwner, value: new BN(String(1e18)).muln(10) }
      );

      await this.contract.$writeUint(maliciousOperatorId, strToBytes32("TYPE"), 4);
      await this.contract.$writeAddress(
        maliciousOperatorId,
        strToBytes32("CONTROLLER"),
        maliciousOperatorOwner
      );
      tx = await this.contract.initiateOperator(
        maliciousOperatorId,
        operatorFee,
        MIN_VALIDATOR_PERIOD,
        maliciousOperatorMaintainer,
        { from: maliciousOperatorOwner, value: new BN(String(1e18)).muln(10) }
      );

      await this.setWP(this.WithdrawalContract.address);
      await this.setLP(this.LiquidityPool.address);

      publicPoolId = poolIds[0];
      await this.contract.initiatePool(
        poolFee,
        middlewareId,
        poolMaintainer,
        poolNames[0],
        "0x",
        [false, false, false],
        { from: poolOwner, value: new BN(String(1e18)).muln(32) }
      );

      privatePoolId = poolIds[1];
      await this.contract.initiatePool(
        poolFee,
        0,
        poolMaintainer,
        poolNames[1],
        "0x",
        [true, false, false],
        { from: poolOwner, value: new BN(String(1e18)).muln(32) }
      );

      this.whitelist = await artifacts.require("Whitelist").new({ from: poolOwner });

      liquidPoolId = poolIds[2];
      await this.contract.initiatePool(
        poolFee,
        0,
        poolMaintainer,
        poolNames[2],
        "0x",
        [false, false, true],
        { from: poolOwner, value: new BN(String(1e18)).muln(32) }
      );
    });

    context("pool visibility", function () {
      describe("setPoolVisibility", function () {
        it("reverts if already private/public", async function () {
          await expectRevert(
            this.contract.setPoolVisibility(privatePoolId, true, { from: poolOwner }),
            "SML:already set"
          );
          await expectRevert(
            this.contract.setPoolVisibility(publicPoolId, false, { from: poolOwner }),
            "SML:already set"
          );
        });
        it("public -> private", async function () {
          await this.contract.setPoolVisibility(publicPoolId, true, { from: poolOwner });
          expect(await this.contract.isPrivatePool(publicPoolId)).to.be.equal(true);
        });
        it("private -> public", async function () {
          await this.contract.setPoolVisibility(privatePoolId, false, { from: poolOwner });
          expect(await this.contract.isPrivatePool(privatePoolId)).to.be.equal(false);
        });
        it("private -> public: removes whitelist", async function () {
          await this.contract.setPoolVisibility(privatePoolId, false, { from: poolOwner });
          expect(
            await this.contract.readAddress(privatePoolId, strToBytes32("whitelist"))
          ).to.be.equal(ZERO_ADDRESS);
        });
        it("emits VisibilitySet", async function () {
          expectEvent(
            await this.contract.setPoolVisibility(privatePoolId, false, { from: poolOwner }),
            "VisibilitySet",
            { id: privatePoolId, isPrivate: false }
          );
        });
      });

      describe("setWhitelist", function () {
        it("reverts if publicPool", async function () {
          await expectRevert(
            this.contract.setWhitelist(publicPoolId, this.whitelist.address, {
              from: poolOwner,
            }),
            "SML:must be private pool"
          );
        });
        it("sets Whitelist", async function () {
          await this.contract.setWhitelist(privatePoolId, this.whitelist.address, {
            from: poolOwner,
          });
          expect(
            await this.contract.readAddress(privatePoolId, strToBytes32("whitelist"))
          ).to.be.equal(this.whitelist.address);
        });
      });
      describe("isWhitelisted", function () {
        it("return true if the pool controller", async function () {
          expect(await this.contract.isWhitelisted(privatePoolId, poolOwner)).to.be.equal(true);
        });
        it("revert if no whitelist set", async function () {
          await expectRevert(
            this.contract.isWhitelisted(privatePoolId, staker),
            "SML:no whitelist"
          );
        });
        it("return true if whitelist says ok", async function () {
          await this.contract.setWhitelist(privatePoolId, this.whitelist.address, {
            from: poolOwner,
          });
          expect(await this.contract.isWhitelisted(privatePoolId, staker)).to.be.equal(false);
          await this.whitelist.setAddress(staker, true, { from: poolOwner });
          expect(await this.contract.isWhitelisted(privatePoolId, staker)).to.be.equal(true);
          await this.whitelist.setAddress(staker, false, { from: poolOwner });
          expect(await this.contract.isWhitelisted(privatePoolId, staker)).to.be.equal(false);
        });
      });
    });

    context("Yield Receiver", function () {
      describe("setYieldReceiver", function () {
        let yieldReceiver;
        beforeEach(async function () {
          yieldReceiver = generateAddress();
        });

        it("reverts if poolId is not pool type", async function () {
          await expectRevert(
            this.contract.setYieldReceiver(operatorId, yieldReceiver, { from: poolOwner }),
            "SML:TYPE NOT allowed"
          );
        });
        it("reverts if sender is not controller of the pool", async function () {
          await expectRevert(
            this.contract.setYieldReceiver(publicPoolId, yieldReceiver, { from: poolMaintainer }),
            "SML:sender NOT CONTROLLER"
          );
        });
        it("success: sets yieldReceiver and set back 0 address and emits YieldReceiverSet event", async function () {
          let tx = await this.contract.setYieldReceiver(publicPoolId, yieldReceiver, {
            from: poolOwner,
          });

          expect(
            await this.contract.readAddress(publicPoolId, strToBytes32("yieldReceiver"))
          ).to.be.eq(yieldReceiver);

          expectEvent(tx, "YieldReceiverSet", {
            poolId: publicPoolId,
            yieldReceiver: yieldReceiver,
          });

          tx = await this.contract.setYieldReceiver(publicPoolId, ZERO_ADDRESS, {
            from: poolOwner,
          });

          expect(
            await this.contract.readAddress(publicPoolId, strToBytes32("yieldReceiver"))
          ).to.be.eq(ZERO_ADDRESS);

          expectEvent(tx, "YieldReceiverSet", {
            poolId: publicPoolId,
            yieldReceiver: ZERO_ADDRESS,
          });
        });
      });
    });

    context("maintainer", function () {
      describe("_setMaintainer", function () {
        it("reverts if zero address", async function () {
          await expectRevert(
            this.contract.$_setMaintainer(publicPoolId, ZERO_ADDRESS),
            "SML:maintainer can NOT be zero"
          );
        });
        it("sets maintainer", async function () {
          await this.contract.$_setMaintainer(publicPoolId, attacker);
          expect(
            await this.contract.readAddress(publicPoolId, strToBytes32("maintainer"))
          ).to.be.equal(attacker);
        });
        it("emits MaintainerChanged", async function () {
          expectEvent(
            await this.contract.$_setMaintainer(publicPoolId, attacker),
            "MaintainerChanged",
            { id: publicPoolId, newMaintainer: attacker }
          );
        });
      });
      describe("changeMaintainer", function () {
        it("reverts if not initiated", async function () {
          await expectRevert(
            this.contract.changeMaintainer(middlewareId, poolMaintainer),
            "SML:ID is not initiated"
          );
        });
        it("reverts if not CONTROLLER", async function () {
          await expectRevert(
            this.contract.changeMaintainer(publicPoolId, attacker, { from: attacker }),
            "SML:sender NOT CONTROLLER"
          );
        });
        it("reverts if not POOL or Operator", async function () {
          await this.contract.$writeAddress(middlewareId, strToBytes32("CONTROLLER"), attacker);
          await this.contract.$writeUint(middlewareId, strToBytes32("initiated"), 1);
          await expectRevert(
            this.contract.changeMaintainer(middlewareId, attacker, {
              from: attacker,
            }),
            "SML:invalid TYPE"
          );
        });
        it("success", async function () {
          await this.contract.$writeAddress(publicPoolId, strToBytes32("CONTROLLER"), poolOwner);
          await this.contract.$writeUint(publicPoolId, strToBytes32("TYPE"), 5);
          await this.contract.$writeUint(publicPoolId, strToBytes32("initiated"), 1);
          await this.contract.changeMaintainer(publicPoolId, attacker, {
            from: poolOwner,
          });
        });
      });
    });

    context("fee", function () {
      const newFee = MAX_MAINTENANCE_FEE.subn(1);
      describe("_setMaintenanceFee", function () {
        it("reverts if > MAX", async function () {
          await expectRevert(
            this.contract.$_setMaintenanceFee(operatorId, MAX_MAINTENANCE_FEE.addn(1)),
            "SML:> MAX_MAINTENANCE_FEE"
          );
        });
        it("sets fee", async function () {
          await this.contract.$_setMaintenanceFee(operatorId, newFee);
          expect(
            await this.contract.readUint(operatorId, strToBytes32("fee"))
          ).to.be.bignumber.equal(newFee);
        });
      });
      describe("switchMaintenanceFee", function () {
        it("reverts if already switching", async function () {
          const tx = await this.contract.switchMaintenanceFee(operatorId, newFee, {
            from: operatorOwner,
          });

          const ts = new BN((await getReceiptTimestamp(tx)).toString());

          await expectRevert(
            this.contract.switchMaintenanceFee(operatorId, newFee, { from: operatorOwner }),
            "SML:currently switching"
          );

          await setTimestamp(ts.add(SWITCH_LATENCY).toNumber());

          await this.contract.switchMaintenanceFee(operatorId, newFee, { from: operatorOwner });
        });
        context("success", function () {
          let tx;
          let effectiveAfter;
          beforeEach(async function () {
            tx = await this.contract.switchMaintenanceFee(operatorId, newFee, {
              from: operatorOwner,
            });
            effectiveAfter = new BN((await getReceiptTimestamp(tx)).toString()).add(SWITCH_LATENCY);
          });

          it("sets priorFee", async function () {
            expect(
              await this.contract.readUint(operatorId, strToBytes32("priorFee"))
            ).to.be.bignumber.equal(operatorFee);
          });

          it("sets feeSwitch", async function () {
            expect(
              await this.contract.readUint(operatorId, strToBytes32("feeSwitch"))
            ).to.be.bignumber.equal(effectiveAfter);
          });
          it("emits FeeSwitched", async function () {
            expectEvent(tx, "FeeSwitched", { id: operatorId, fee: newFee, effectiveAfter });
          });
        });
      });

      describe("getMaintenanceFee", function () {
        it("returns old if switching", async function () {
          await this.contract.switchMaintenanceFee(operatorId, newFee, { from: operatorOwner });
          expect(await this.contract.getMaintenanceFee(operatorId)).to.be.bignumber.equal(
            operatorFee
          );
        });
        it("returns new if switched", async function () {
          const tx = await this.contract.switchMaintenanceFee(operatorId, newFee, {
            from: operatorOwner,
          });
          const ts = new BN((await getReceiptTimestamp(tx)).toString());

          await setTimestamp(ts.add(SWITCH_LATENCY.addn(1)).toNumber());

          expect(await this.contract.getMaintenanceFee(operatorId)).to.be.bignumber.equal(newFee);
        });
      });
    });

    context("Internal wallet", function () {
      let preBal;
      const amount = new BN(String(1e18));
      beforeEach(async function () {
        preBal = await this.contract.readUint(operatorId, strToBytes32("wallet"));
      });
      describe("_increaseWalletBalance", function () {
        it("increases wallet", async function () {
          await this.contract.$_increaseWalletBalance(operatorId, amount);
          expect(
            await this.contract.readUint(operatorId, strToBytes32("wallet"))
          ).to.be.bignumber.equal(preBal.add(amount));
        });
      });

      describe("_decreaseWalletBalance", function () {
        it("reverts if not enough", async function () {
          await expectRevert(
            this.contract.$_decreaseWalletBalance(operatorId, MAX_UINT256),
            "SML:insufficient wallet balance"
          );
        });
        it("decreases wallet", async function () {
          await this.contract.increaseWalletBalance(operatorId, { value: amount });
          await this.contract.$_decreaseWalletBalance(operatorId, amount.divn(5));
          expect(
            await this.contract.readUint(operatorId, strToBytes32("wallet"))
          ).to.be.bignumber.equal(preBal.add(amount).sub(amount.divn(5)));
        });
      });

      describe("increaseWalletBalance", function () {
        it("returns !!!! todo", async function () {}); // todo all returns
      });

      describe("decreaseWalletBalance", function () {
        it("reverts if contract is short", async function () {
          await expectRevert(
            this.contract.decreaseWalletBalance(operatorId, MAX_UINT256, { from: operatorOwner }),
            "SML:insufficient contract balance"
          );
        });
        it("sends to controller", async function () {
          await this.contract.increaseWalletBalance(operatorId, { value: amount });
          const prevBal = await balance.current(operatorOwner);

          tx = await this.contract.decreaseWalletBalance(operatorId, amount, {
            from: operatorOwner,
          });

          const gasUsed = new BN(tx.receipt.cumulativeGasUsed.toString()).mul(
            new BN(tx.receipt.effectiveGasPrice.toString())
          );
          expect(await balance.current(operatorOwner)).to.be.bignumber.equal(
            prevBal.add(amount).sub(gasUsed)
          );
        });
        it("returns !!!! todo", async function () {}); // todo all returns
      });
    });

    context("prison", function () {
      describe("isPrisoned", function () {
        it("returns true if date < release", async function () {
          await this.contract.$writeUint(operatorId, strToBytes32("release"), MAX_UINT256);
          expect(await this.contract.isPrisoned(operatorId)).to.be.equal(true);
        });
        it("returns false if > release", async function () {
          await this.contract.$writeUint(
            operatorId,
            strToBytes32("release"),
            new BN((await getBlockTimestamp()).toString())
          );
          expect(await this.contract.isPrisoned(operatorId)).to.be.equal(false);
        });
      });

      describe("_imprison", function () {
        let tx;
        beforeEach(async function () {
          tx = await this.contract.$_imprison(operatorId, ZERO_BYTES32);
        });
        it("sets release", async function () {
          expect(
            await this.contract.readUint(operatorId, strToBytes32("release"))
          ).to.be.bignumber.equal(
            new BN((await getReceiptTimestamp(tx)).toString()).add(PRISON_SENTENCE)
          );
          expect(await this.contract.isPrisoned(operatorId)).to.be.equal(true);
        });
        it("isPrisoned returns true", async function () {
          expect(await this.contract.isPrisoned(operatorId)).to.be.equal(true);
        });
        it("emits Prisoned", async function () {
          expectEvent(tx, "Prisoned", {});
        });
      });

      describe("blameOperator", function () {
        it("reverts if not active", async function () {
          await expectRevert(
            this.contract.blameOperator(ZERO_BYTES32),
            "SML:validator is never activated"
          );
        });
      });
    });

    context("validator period", function () {
      const newPeriod = MAX_VALIDATOR_PERIOD.subn(1);
      describe("_setValidatorPeriod", function () {
        it("reverts if < MIN", async function () {
          await expectRevert(
            this.contract.$_setValidatorPeriod(operatorId, MIN_VALIDATOR_PERIOD.subn(1)),
            "SML:< MIN_VALIDATOR_PERIOD"
          );
        });
        it("reverts if > MAX", async function () {
          await expectRevert(
            this.contract.$_setValidatorPeriod(operatorId, MAX_VALIDATOR_PERIOD.addn(1)),
            "SML:> MAX_VALIDATOR_PERIOD"
          );
        });
        it("sets validatorPeriod", async function () {
          await this.contract.$_setValidatorPeriod(operatorId, newPeriod);
          expect(
            await this.contract.readUint(operatorId, strToBytes32("validatorPeriod"))
          ).to.be.bignumber.equal(newPeriod);
        });
      });
      describe("switchValidatorPeriod", function () {
        it("reverts if already switching", async function () {
          const tx = await this.contract.switchValidatorPeriod(operatorId, newPeriod, {
            from: operatorOwner,
          });

          const ts = new BN((await getReceiptTimestamp(tx)).toString());

          await expectRevert(
            this.contract.switchValidatorPeriod(operatorId, newPeriod, { from: operatorOwner }),
            "SML:currently switching"
          );

          await setTimestamp(ts.add(SWITCH_LATENCY).toNumber());

          await this.contract.switchValidatorPeriod(operatorId, newPeriod, { from: operatorOwner });
        });
        context("success", function () {
          let tx;
          let effectiveAfter;
          beforeEach(async function () {
            tx = await this.contract.switchValidatorPeriod(operatorId, newPeriod, {
              from: operatorOwner,
            });
            effectiveAfter = new BN((await getReceiptTimestamp(tx)).toString()).add(SWITCH_LATENCY);
          });

          it("sets priorPeriod", async function () {
            expect(
              await this.contract.readUint(operatorId, strToBytes32("priorPeriod"))
            ).to.be.bignumber.equal(MIN_VALIDATOR_PERIOD);
          });

          it("sets periodSwitch", async function () {
            expect(
              await this.contract.readUint(operatorId, strToBytes32("periodSwitch"))
            ).to.be.bignumber.equal(effectiveAfter);
          });
          it("emits ValidatorPeriodSwitched", async function () {
            expectEvent(tx, "ValidatorPeriodSwitched", {
              operatorId: operatorId,
              period: newPeriod,
              effectiveAfter,
            });
          });
        });
      });
      describe("getValidatorPeriod", function () {
        it("returns old if switching", async function () {
          await this.contract.switchValidatorPeriod(operatorId, newPeriod, { from: operatorOwner });
          expect(await this.contract.getValidatorPeriod(operatorId)).to.be.bignumber.equal(
            MIN_VALIDATOR_PERIOD
          );
        });
        it("returns new if switched", async function () {
          const tx = await this.contract.switchValidatorPeriod(operatorId, newPeriod, {
            from: operatorOwner,
          });
          const ts = new BN((await getReceiptTimestamp(tx)).toString());

          await setTimestamp(ts.add(SWITCH_LATENCY.addn(1)).toNumber());

          expect(await this.contract.getValidatorPeriod(operatorId)).to.be.bignumber.equal(
            newPeriod
          );
        });
      });
    });

    context("delegation", function () {
      const allowance = new BN(420);

      describe("setFallbackOperator", function () {
        it("reverts if sender not maintainer", async function () {
          await expectRevert(
            this.contract.setFallbackOperator(publicPoolId, operatorId, fallbackThreshold, {
              from: attacker,
            }),
            "SML:sender NOT maintainer"
          );
        });
        it("reverts if fallback not operator", async function () {
          await expectRevert(
            this.contract.setFallbackOperator(publicPoolId, privatePoolId, fallbackThreshold, {
              from: poolMaintainer,
            }),
            "SML:fallback not operator"
          );
        });

        it("reverts if fallbackThreshold is greater then 100", async function () {
          await expectRevert(
            this.contract.setFallbackOperator(
              publicPoolId,
              operatorId,
              PERCENTAGE_DENOMINATOR.addn(1),
              {
                from: poolMaintainer,
              }
            ),
            "SML:threshold cannot be greater than 100"
          );
        });
        it("success: sets fallback operator and resets and emits FallbackOperator event", async function () {
          let tx = await this.contract.setFallbackOperator(
            publicPoolId,
            operatorId,
            fallbackThreshold,
            { from: poolMaintainer }
          );

          expect(
            await this.contract.readUint(publicPoolId, strToBytes32("fallbackOperator"))
          ).to.be.bignumber.equal(operatorId);

          expect(
            await this.contract.readUint(publicPoolId, strToBytes32("fallbackThreshold"))
          ).to.be.bignumber.equal(fallbackThreshold);

          await expectEvent(tx, "FallbackOperator", {
            operatorId: operatorId,
            poolId: publicPoolId,
            threshold: fallbackThreshold,
          });

          tx = await this.contract.setFallbackOperator(publicPoolId, 0, fallbackThreshold, {
            from: poolMaintainer,
          });

          expect(
            await this.contract.readUint(publicPoolId, strToBytes32("fallbackOperator"))
          ).to.be.bignumber.equal(new BN("0"));

          expect(
            await this.contract.readUint(publicPoolId, strToBytes32("fallbackThreshold"))
          ).to.be.bignumber.equal(new BN("0"));

          await expectEvent(tx, "FallbackOperator", {
            operatorId: new BN("0"),
            poolId: publicPoolId,
            threshold: new BN("0"),
          });
        });
      });
      describe("_approveOperator", function () {
        let tx;
        beforeEach(async function () {
          tx = await this.contract.$_approveOperator(publicPoolId, operatorId, allowance);
        });
        it("sets allowance", async function () {
          expect(
            await this.contract.readUint(
              publicPoolId,
              await this.contract.getKey(operatorId, strToBytes32("allowance"))
            )
          ).to.be.bignumber.equal(allowance);
        });
        it("returns oldAllowance", async function () {}); // todo all returns
        it("emits Delegation", async function () {
          await expectEvent(tx, "Delegation", { poolId: publicPoolId, operatorId, allowance });
        });
      });
      describe("delegate", function () {
        it("reverts if arrays do not match", async function () {
          await expectRevert(
            this.contract.delegate(publicPoolId, [operatorId], [], {
              from: poolMaintainer,
            }),
            "allowances should match"
          );
        });
        it("reverts if id is not an operator", async function () {
          await expectRevert(
            this.contract.delegate(publicPoolId, [privatePoolId], [allowance], {
              from: poolMaintainer,
            }),
            "SML:id not operator"
          );
        });
        it("reverts if > MAX_ALLOWANCE", async function () {
          await expectRevert(
            this.contract.delegate(publicPoolId, [operatorId], [MAX_ALLOWANCE.addn(1)], {
              from: poolMaintainer,
            }),
            "SML:> MAX_ALLOWANCE, set fallback"
          );
        });
        it("success: updates totalAllowance", async function () {
          await this.contract.delegate(publicPoolId, [operatorId], [allowance], {
            from: poolMaintainer,
          });
          expect(
            await this.contract.readUint(publicPoolId, strToBytes32("totalAllowance"))
          ).to.be.bignumber.equal(allowance);
          await this.contract.delegate(publicPoolId, [operatorId], [MAX_ALLOWANCE.subn(1)], {
            from: poolMaintainer,
          });
          expect(
            await this.contract.readUint(publicPoolId, strToBytes32("totalAllowance"))
          ).to.be.bignumber.equal(MAX_ALLOWANCE.subn(1));

          await this.contract.delegate(
            publicPoolId,
            [operatorId, operatorId, operatorId],
            [MAX_ALLOWANCE.subn(1), MAX_ALLOWANCE.subn(1), MAX_ALLOWANCE.subn(1)],
            {
              from: poolMaintainer,
            }
          );
          expect(
            await this.contract.readUint(publicPoolId, strToBytes32("totalAllowance"))
          ).to.be.bignumber.equal(MAX_ALLOWANCE.subn(1));

          // initiate another operator for unknownId
          await this.contract.$writeUint(unknownId, strToBytes32("TYPE"), 4);
          await this.contract.$writeAddress(unknownId, strToBytes32("CONTROLLER"), operatorOwner);
          tx = await this.contract.initiateOperator(
            unknownId,
            0,
            MIN_VALIDATOR_PERIOD,
            operatorMaintainer,
            { from: operatorOwner }
          );

          await this.contract.delegate(
            publicPoolId,
            [operatorId, unknownId, unknownId],
            [MAX_ALLOWANCE.subn(1), MAX_ALLOWANCE.subn(1), allowance],
            {
              from: poolMaintainer,
            }
          );
          expect(
            await this.contract.readUint(publicPoolId, strToBytes32("totalAllowance"))
          ).to.be.bignumber.equal(MAX_ALLOWANCE.subn(1).add(allowance));

          await this.contract.delegate(
            publicPoolId,
            [operatorId, operatorId, unknownId],
            [MAX_ALLOWANCE.subn(1), allowance, 0],
            {
              from: poolMaintainer,
            }
          );
          expect(
            await this.contract.readUint(publicPoolId, strToBytes32("totalAllowance"))
          ).to.be.bignumber.equal(allowance);
        });
      });

      describe("operatorAllowance", function () {
        beforeEach(async function () {
          await this.contract.$set_MONOPOLY_THRESHOLD(MONOPOLY_THRESHOLD);

          await this.contract.delegate(publicPoolId, [operatorId], [allowance], {
            from: poolMaintainer,
          });

          await this.contract.setFallbackOperator(publicPoolId, operatorId, fallbackThreshold, {
            from: poolMaintainer,
          });
        });
        it("returns 0, if operator has more than MONOPOLY_THRESHOLD", async function () {
          await this.contract.$writeUint(operatorId, strToBytes32("validators"), MAX_UINT256);
          expect(
            await this.contract.operatorAllowance(publicPoolId, operatorId)
          ).to.be.bignumber.equal(new BN("0"));
        });
        it("returns remaining allowance, if not reached (remValidators > remAllowance)", async function () {
          await this.contract.$writeUint(
            publicPoolId,
            await this.contract.getKey(operatorId, strToBytes32("proposedValidators")),
            allowance.subn(69)
          );
          expect(
            await this.contract.operatorAllowance(publicPoolId, operatorId)
          ).to.be.bignumber.equal("69");
        });

        it("returns remaining allowance, if not reached (remValidators < remAllowance)", async function () {
          await this.contract.$set_MONOPOLY_THRESHOLD(121);

          await this.contract.$writeUint(operatorId, strToBytes32("validators"), 119);

          await this.contract.$writeUint(
            publicPoolId,
            await this.contract.getKey(operatorId, strToBytes32("proposedValidators")),
            42
          );

          await this.contract.$writeUint(
            publicPoolId,
            await this.contract.getKey(operatorId, strToBytes32("activeValidators")),
            69
          );

          expect(
            await this.contract.operatorAllowance(publicPoolId, operatorId)
          ).to.be.bignumber.equal("2");
        });

        it("returns 0, if > allowance", async function () {
          await this.contract.$writeUint(
            publicPoolId,
            await this.contract.getKey(operatorId, strToBytes32("proposedValidators")),
            allowance
          );
          expect(
            await this.contract.operatorAllowance(publicPoolId, operatorId)
          ).to.be.bignumber.equal("0");
        });

        context("fallbackOperator", function () {
          it("returns remaining to MONOPOLY_THRESHOLD, if reached fallbackThreshold", async function () {
            await this.contract.$writeUint(
              operatorId,
              strToBytes32("validators"),
              MONOPOLY_THRESHOLD.subn(6969)
            );
            await this.contract.$writeUint(
              publicPoolId,
              strToBytes32("validators"),
              allowance.mul(fallbackThreshold).div(PERCENTAGE_DENOMINATOR)
            );
            expect(
              await this.contract.operatorAllowance(publicPoolId, operatorId)
            ).to.be.bignumber.equal("6969");
          });
          it("returns allowance, if NOT reached fallbackThreshold", async function () {
            expect(
              await this.contract.operatorAllowance(publicPoolId, operatorId)
            ).to.be.bignumber.equal(allowance);
          });
        });
      });
    });

    context("deposit helpers", function () {
      let ts;
      beforeEach(async function () {
        ts = new BN((await getBlockTimestamp()).toString());
        // set to yesterday, before the pools are initiated.
        await this.contract.$set_ORACLE_UPDATE_TIMESTAMP(ts.sub(DAY));
      });
      describe("isPriceValid", function () {
        it("returns true after initiation", async function () {
          expect(await this.contract.isPriceValid(publicPoolId)).to.be.equal(true);
        });
        it("returns false if price expired", async function () {
          await setTimestamp(ts.add(SWITCH_LATENCY).toNumber());
          expect(await this.contract.isPriceValid(publicPoolId)).to.be.equal(false);
        });
        it("returns false if lastupdate < ORACLE_UPDATE_TIMESTAMP", async function () {
          await this.contract.$set_ORACLE_UPDATE_TIMESTAMP(ts.add(DAY));
          expect(await this.contract.isPriceValid(publicPoolId)).to.be.equal(false);
        });
      });
      describe("isMintingAllowed", function () {
        it("returns true after initiation", async function () {
          expect(await this.contract.isMintingAllowed(publicPoolId)).to.be.equal(true);
        });
        it("returns false if price is not valid", async function () {
          await this.contract.$set_ORACLE_UPDATE_TIMESTAMP(ts.add(DAY));
          expect(await this.contract.isMintingAllowed(publicPoolId)).to.be.equal(false);
        });
        it("returns false if withdrawalContract is isolated", async function () {
          // changing only the pool owner will take it to isolation
          await this.contract.$writeAddress(publicPoolId, strToBytes32("CONTROLLER"), attacker);
          expect(await this.contract.isMintingAllowed(publicPoolId)).to.be.equal(false);
        });
      });
    });

    context("deposit", function () {
      describe("_mintgETH", function () {
        it("reverts if minting is not allowed", async function () {
          const ts = new BN((await getBlockTimestamp()).toString());
          await setTimestamp(ts.add(DAY.addn(1)).toNumber());

          await expectRevert(
            this.contract.$_mintgETH(publicPoolId, String(1e18)),
            "SML:minting is not allowed"
          );
        });
        it("reverts if no price?", async function () {
          await this.contract.$set_PricePerShare(0, publicPoolId);

          await expectRevert(
            this.contract.$_mintgETH(publicPoolId, String(1e18)),
            "SML:price is zero?"
          );
        });
        describe("success: price 2 ether", function () {
          let beforeSurplus;
          beforeEach(async function () {
            beforeSurplus = await this.contract.readUint(publicPoolId, strToBytes32("surplus"));
            await this.contract.$set_PricePerShare(String(2e18), publicPoolId);
            await this.contract.$_mintgETH(publicPoolId, String(1e18));
          });
          it("mints correct amount to the contract", async function () {
            expect(
              await this.gETH.balanceOf(this.contract.address, publicPoolId)
            ).to.be.bignumber.equal(String(5e17));
          });
          it("user balance doesn't change", async function () {
            expect(await this.gETH.balanceOf(deployer, publicPoolId)).to.be.bignumber.equal("0");
          });
          it("increases surplus", async function () {
            expect(
              await this.contract.readUint(publicPoolId, strToBytes32("surplus"))
            ).to.be.bignumber.equal(beforeSurplus.add(new BN(String(1e18))));
          });
        });
        describe("success: price 69 ether", function () {
          let beforeSurplus;
          beforeEach(async function () {
            beforeSurplus = await this.contract.readUint(publicPoolId, strToBytes32("surplus"));
            await this.contract.$set_PricePerShare(String(69e18), publicPoolId);
            await this.contract.$_mintgETH(publicPoolId, String(69e17));
          });
          it("mints correct amount to the contract", async function () {
            expect(
              await this.gETH.balanceOf(this.contract.address, publicPoolId)
            ).to.be.bignumber.equal(String(1e17));
          });
          it("user balance doesn't change", async function () {
            expect(await this.gETH.balanceOf(deployer, publicPoolId)).to.be.bignumber.equal("0");
          });
          it("increases surplus", async function () {
            expect(
              await this.contract.readUint(publicPoolId, strToBytes32("surplus"))
            ).to.be.bignumber.equal(beforeSurplus.add(new BN(String(69e17))));
          });
        });
      });
      describe("_buyback", function () {
        const maxEthToSell = new BN(String(1e18));
        it("no LP: returns all eth", async function () {
          await expectEvent(
            await this.contract.$_buyback(privatePoolId, maxEthToSell, MAX_UINT256),
            "return$_buyback",
            {
              remETH: maxEthToSell,
              boughtgETH: "0",
            }
          );
        });
        context("with LP", function () {
          let LP;
          beforeEach(async function () {
            LP = await LiquidityPool.at(
              await this.contract.readAddress(liquidPoolId, strToBytes32("liquidityPool"))
            );

            await this.gETH.setApprovalForAll(LP.address, true, { from: poolOwner });
            await LP.addLiquidity([String(1e19), String(1e19)], 0, MAX_UINT256, {
              value: new BN(String(1e18)).muln(10),
              from: poolOwner,
            });

            expect(await LP.getDebt()).to.be.bignumber.equal("0");
          });
          it("returns all eth if LP is isolated", async function () {
            await this.contract.$writeAddress(liquidPoolId, strToBytes32("CONTROLLER"), deployer);
            await expectEvent(
              await this.contract.$_buyback(liquidPoolId, maxEthToSell, MAX_UINT256),
              "return$_buyback",
              {
                remETH: maxEthToSell,
                boughtgETH: "0",
              }
            );
          });
          it("returns all eth if debt < IGNORABLE_DEBT", async function () {
            await LP.addLiquidity([String(0), String(1e18)], 0, MAX_UINT256, {
              from: poolOwner,
            });
            const debt = await LP.getDebt();
            expect(debt).to.be.bignumber.gt("0");
            expect(debt).to.be.bignumber.lt(IGNORABLE_DEBT);

            await expectEvent(
              await this.contract.$_buyback(liquidPoolId, maxEthToSell, MAX_UINT256),
              "return$_buyback",
              {
                remETH: maxEthToSell,
                boughtgETH: "0",
              }
            );
          });
          context("returns remaining amount if bought", function () {
            it("sell all if, debt > _maxEthToSell", async function () {
              await LP.addLiquidity([String(0), String(1e19)], 0, MAX_UINT256, {
                from: poolOwner,
              });
              const debt = await LP.getDebt();
              expect(debt).to.be.bignumber.gt(IGNORABLE_DEBT);

              const calculatedSwapReturn = await LP.calculateSwap(
                0,
                1,
                debt.sub(new BN(String(1e17)))
              );

              await expectEvent(
                await this.contract.$_buyback(
                  liquidPoolId,
                  debt.sub(new BN(String(1e17))),
                  MAX_UINT256
                ),
                "return$_buyback",
                {
                  remETH: "0",
                  boughtgETH: calculatedSwapReturn,
                }
              );
            });
            it("sell debt if, debt < _maxEthToSell", async function () {
              await LP.addLiquidity([String(0), String(1e19)], 0, MAX_UINT256, {
                from: poolOwner,
              });
              const debt = await LP.getDebt();
              expect(debt).to.be.bignumber.gt(IGNORABLE_DEBT);

              const calculatedSwapReturn = await LP.calculateSwap(0, 1, debt);

              await expectEvent(
                await this.contract.$_buyback(
                  liquidPoolId,
                  debt.add(new BN(String(1e17))),
                  MAX_UINT256
                ),
                "return$_buyback",
                {
                  remETH: String(1e17),
                  boughtgETH: calculatedSwapReturn,
                }
              );
            });
          });
        });
      });

      describe("deposit", function () {
        it("reverts if deadline past", async function () {
          await expectRevert(
            this.contract.deposit(privatePoolId, 0, [], 0, 0, ZERO_ADDRESS),
            "SML:deadline not met"
          );
        });
        it("reverts if receiver is zero", async function () {
          await expectRevert(
            this.contract.deposit(privatePoolId, 0, [], 0, MAX_UINT256, ZERO_ADDRESS),
            "SML:receiver is zero address"
          );
        });
        it("reverts if private pool & not whitelisted", async function () {
          await this.contract.setWhitelist(privatePoolId, this.whitelist.address, {
            from: poolOwner,
          });
          await expectRevert(
            this.contract.deposit(privatePoolId, 0, [], 0, MAX_UINT256, attacker, {
              from: attacker,
            }),
            "SML:sender NOT whitelisted"
          );
        });
        it("reverts if mingETH not achieved", async function () {
          await expectRevert(
            this.contract.deposit(privatePoolId, 0, [], MAX_UINT256, MAX_UINT256, staker, {
              from: poolOwner,
            }),
            "SML:less than minimum"
          );
        });
        context("success", async function () {
          let tx;
          let LP;
          let debt;
          const extra = new BN(String(1e18));
          let expBuy;
          let prevReceiverBalance;

          beforeEach(async function () {
            prevReceiverBalance = await this.gETH.balanceOf(staker, privatePoolId);

            await this.contract.deployLiquidityPool(privatePoolId, {
              from: poolOwner,
            });
            LP = await LiquidityPool.at(
              await this.contract.readAddress(privatePoolId, strToBytes32("liquidityPool"))
            );
            await this.gETH.setApprovalForAll(LP.address, true, { from: poolOwner });
            await LP.addLiquidity([String(1e18), String(1e19)], 0, MAX_UINT256, {
              value: new BN(String(1e18)),
              from: poolOwner,
            });
            debt = await LP.getDebt();
            expBuy = await LP.calculateSwap(0, 1, debt);

            tx = await this.contract.deposit(privatePoolId, 0, [], 0, MAX_UINT256, staker, {
              from: poolOwner,
              value: debt.add(extra),
            });
          });
          it("sends to the Receiver", async function () {
            const expBal = prevReceiverBalance.add(expBuy).add(extra);
            expect(await this.gETH.balanceOf(staker, privatePoolId)).to.be.bignumber.equal(expBal);
          });
          it("emits Deposit", async function () {
            await expectEvent(tx, "Deposit", {
              poolId: privatePoolId,
              boughtgETH: expBuy,
              mintedgETH: extra,
            });
          });
          it("returns correct params", async function () {
            await expectEvent(tx, "return$deposit", {
              boughtgETH: expBuy,
              mintedgETH: extra,
            });
          });
        });
      });
    });

    context("validator creation", function () {
      const pubkey0 =
        "0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a";
      const pubkey1 =
        "0xa3b3eb55b16999ffeff52e5a898af89e4194b7221b2eaf03cb85fd558a390dc042beba94f907db6091b4cf141b18d1f5";
      const pubkey2 =
        "0x986e1dee05f3a018bab83343b3b3d96dd573a50ffb03e8145b2964a389ceb14cb3780266b99ef7cf0e16ee34648e2151";

      const signature01 =
        "0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181";
      const signature11 =
        "0xa2e94c3def1e53d7d1b5a0f037f765868b4bbae3ee59de673bc7ab7b142b929e08f47c1c2a6cdc91aee9442468ab095406b8ce356aef42403febe385424f97d6d109f6423dcb1acc3def45af56e4407416f0773bd18e50d880cb7d3e00ca9932";
      const signature031 =
        "0xa58af51205a996c87f23c80aeb3cb669001e3f919a88598d063ff6cee9b05fbb8a18dab15a4a5b85eabfd47c26d0f24f11f5f889f6a7fb8cbd5c4ccd7607c449b57a9f0703e1bb63b513cb3e9fcd1d79b0d8f269c7441173054b9284cfb7a13c";
      const signature131 =
        "0xa7290722d0b9350504fd44cd166fabc85db76fab07fb2876bff51e0ede2856e6160e4288853cf713cbf3cd7a0541ab1d0ed5e0858c980870f3a4c791264d8b4ee090677f507b599409e86433590ee3a93cae5103d2e03c66bea623e3ccd590ae";

      describe("proposeStake() call", function () {
        context("initial checks", function () {
          it("reverts if withdrawal contract is isolated", async function () {
            await this.contract.$writeAddress(publicPoolId, strToBytes32("CONTROLLER"), attacker);
            await expectRevert(
              this.contract.proposeStake(publicPoolId, operatorId, [], [], [], {
                from: operatorMaintainer,
              }),
              "SML:withdrawalContract is isolated"
            );
          });
          it("reverts if 0 validators", async function () {
            await expectRevert(
              this.contract.proposeStake(publicPoolId, operatorId, [], [], [], {
                from: operatorMaintainer,
              }),
              "SML:1 - 50 validators"
            );
          });
          it("reverts if > 50 validators", async function () {
            await expectRevert(
              this.contract.proposeStake(
                publicPoolId,
                operatorId,
                new Array(51).fill(pubkey0),
                new Array(51).fill(signature01),
                new Array(51).fill(signature031),
                {
                  from: operatorMaintainer,
                }
              ),
              "SML:1 - 50 validators"
            );
          });
          it("reverts if array lenghts are not the same", async function () {
            await expectRevert(
              this.contract.proposeStake(publicPoolId, operatorId, [pubkey0], [], [], {
                from: operatorMaintainer,
              }),
              "SML:invalid input length"
            );
            await expectRevert(
              this.contract.proposeStake(publicPoolId, operatorId, [pubkey0], [signature01], [], {
                from: operatorMaintainer,
              }),
              "SML:invalid input length"
            );
          });
          it("reverts if operator allowance is <", async function () {
            await expectRevert(
              this.contract.proposeStake(
                publicPoolId,
                operatorId,
                [pubkey0],
                [signature01],
                [signature031],
                {
                  from: operatorMaintainer,
                }
              ),
              "SML:insufficient allowance"
            );
          });
        });

        context("after delegation", function () {
          beforeEach(async function () {
            await this.contract.$set_MONOPOLY_THRESHOLD(MONOPOLY_THRESHOLD);
            await this.contract.delegate(publicPoolId, [operatorId], [2], {
              from: poolMaintainer,
            });
          });

          it("reverts if there is not enough funds in the pool", async function () {
            await this.contract.delegate(publicPoolId, [operatorId], [100], {
              from: poolMaintainer,
            });
            await expectRevert(
              this.contract.proposeStake(
                publicPoolId,
                operatorId,
                [pubkey0, pubkey0, pubkey0],
                [signature01, signature01, signature01],
                [signature031, signature031, signature031],
                {
                  from: operatorMaintainer,
                }
              ),
              "SML:NOT enough surplus"
            );
          });

          context("validator checks", function () {
            beforeEach(async function () {
              await this.contract.deposit(publicPoolId, 0, [], 0, MAX_UINT256, staker, {
                from: poolOwner,
                value: new BN(String(1e18)).muln(32),
              });
            });
            it("reverts if invalid pubkey", async function () {
              await expectRevert(
                this.contract.proposeStake(
                  publicPoolId,
                  operatorId,
                  [strToBytes("no")],
                  [signature01],
                  [signature031],
                  {
                    from: operatorMaintainer,
                  }
                ),
                "SML:PUBKEY_LENGTH ERROR"
              );
            });
            it("reverts if invalid sig1", async function () {
              await expectRevert(
                this.contract.proposeStake(
                  publicPoolId,
                  operatorId,
                  [pubkey0],
                  [strToBytes("no")],
                  [signature031],
                  {
                    from: operatorMaintainer,
                  }
                ),
                "SML:SIGNATURE_LENGTH ERROR"
              );
            });
            it("reverts if invalid sig31", async function () {
              await expectRevert(
                this.contract.proposeStake(
                  publicPoolId,
                  operatorId,
                  [pubkey0],
                  [signature01],
                  [strToBytes("no")],
                  {
                    from: operatorMaintainer,
                  }
                ),
                "SML:SIGNATURE_LENGTH ERROR"
              );
            });
            it("reverts if if a used pk", async function () {
              await expectRevert(
                this.contract.proposeStake(
                  publicPoolId,
                  operatorId,
                  [pubkey0, pubkey0],
                  [signature01, signature11],
                  [signature031, signature131],
                  {
                    from: operatorMaintainer,
                  }
                ),
                "SML: used or alienated pk"
              );
            });
          });

          context("success", function () {
            let tx;
            let ts;

            let preWallet;
            let preSurplus;
            let preSecured;
            let preProposedValidators;
            beforeEach(async function () {
              tx = await this.contract.deposit(publicPoolId, 0, [], 0, MAX_UINT256, staker, {
                from: poolOwner,
                value: new BN(String(1e18)).muln(64),
              });

              preWallet = await this.contract.readUint(operatorId, strToBytes32("wallet"));
              preSurplus = await this.contract.readUint(publicPoolId, strToBytes32("surplus"));
              preSecured = await this.contract.readUint(publicPoolId, strToBytes32("secured"));
              preProposedValidators = await this.contract.readUint(
                publicPoolId,
                await this.contract.getKey(operatorId, strToBytes32("proposedValidators"))
              );

              tx = await this.contract.proposeStake(
                publicPoolId,
                operatorId,
                [pubkey0, pubkey1],
                [signature01, signature11],
                [signature031, signature131],
                {
                  from: operatorMaintainer,
                }
              );
              ts = new BN((await getReceiptTimestamp(tx)).toString());
            });
            context("validator data", function () {
              let data;
              beforeEach(async function () {
                data = await this.contract.getValidator(pubkey0);
              });
              it("state", async function () {
                expect(data.state).to.be.bignumber.equal("1");
              });
              it("index", async function () {
                expect(data.index).to.be.bignumber.equal("1");
              });
              it("createdAt", async function () {
                expect(data.createdAt).to.be.bignumber.equal(ts);
              });
              it("period", async function () {
                expect(data.period).to.be.bignumber.equal(MIN_VALIDATOR_PERIOD);
              });
              it("poolId", async function () {
                expect(data.poolId).to.be.bignumber.equal(publicPoolId);
              });
              it("operatorId", async function () {
                expect(data.operatorId).to.be.bignumber.equal(operatorId);
              });
              it("poolFee", async function () {
                expect(data.poolFee).to.be.bignumber.equal(poolFee);
              });
              it("operatorFee", async function () {
                expect(data.operatorFee).to.be.bignumber.equal(operatorFee);
              });
              it("signature31", async function () {
                expect(data.signature31).to.be.equal(signature031);
              });
            });

            it("decreased the operator wallet", async function () {
              expect(
                await this.contract.readUint(operatorId, strToBytes32("wallet"))
              ).to.be.bignumber.equal(preWallet.sub(new BN(String(2e18))));
            });
            it("decreased surplus funds", async function () {
              expect(
                await this.contract.readUint(publicPoolId, strToBytes32("surplus"))
              ).to.be.bignumber.equal(preSurplus.sub(new BN(String(64e18))));
            });
            it("increased secured funds", async function () {
              expect(
                await this.contract.readUint(publicPoolId, strToBytes32("secured"))
              ).to.be.bignumber.equal(preSecured.add(new BN(String(64e18))));
            });
            it("increase proposedValidators", async function () {
              const key = await this.contract.getKey(
                operatorId,
                strToBytes32("proposedValidators")
              );
              expect(await this.contract.readUint(publicPoolId, key)).to.be.bignumber.equal(
                preProposedValidators.addn(2)
              );
            });
            it("append pk to pool's validators array", async function () {
              expect(
                await this.contract.readUint(publicPoolId, strToBytes32("validators"))
              ).to.be.bignumber.equal("2");
              expect(
                await this.contract.readBytesArray(publicPoolId, strToBytes32("validators"), 0)
              ).to.be.bignumber.equal(pubkey0);
              expect(
                await this.contract.readBytesArray(publicPoolId, strToBytes32("validators"), 1)
              ).to.be.bignumber.equal(pubkey1);
            });
            it("append pk to operator's validators array", async function () {
              expect(
                await this.contract.readUint(operatorId, strToBytes32("validators"))
              ).to.be.bignumber.equal("2");
              expect(
                await this.contract.readBytesArray(operatorId, strToBytes32("validators"), 0)
              ).to.be.bignumber.equal(pubkey0);
              expect(
                await this.contract.readBytesArray(operatorId, strToBytes32("validators"), 1)
              ).to.be.bignumber.equal(pubkey1);
            });
            it("increases VALIDATORS_INDEX", async function () {
              expect((await this.contract.StakeParams()).validatorsIndex).to.be.bignumber.equal(
                "2"
              );
            });
            it("emits StakeProposal", async function () {
              await expectEvent(tx, "StakeProposal", {
                poolId: publicPoolId,
                operatorId: operatorId,
                pubkeys: [pubkey0, pubkey1],
              });
            });
          });
        });
      });

      describe("stake() call", function () {
        context("initial checks", function () {
          it("1 - 50 validators", async function () {
            await expectRevert(
              this.contract.stake(operatorId, new Array(51).fill(pubkey0), {
                from: operatorMaintainer,
              }),
              "SML:1 - 50 validators"
            );
            await expectRevert(
              this.contract.stake(operatorId, [], {
                from: operatorMaintainer,
              }),
              "SML:1 - 50 validators"
            );
          });
          it("reverts if not even proposed", async function () {
            await expectRevert(
              this.contract.stake(operatorId, [pubkey0, pubkey1, pubkey2], {
                from: operatorMaintainer,
              }),
              "SML:NOT all pubkeys are stakeable"
            );
          });
        });
        context("proposed: 2 for public pool, 1 for private pool", function () {
          beforeEach(async function () {
            await this.contract.$set_MONOPOLY_THRESHOLD(MONOPOLY_THRESHOLD);

            // for public pool
            await this.contract.delegate(publicPoolId, [operatorId], [2], {
              from: poolMaintainer,
            });

            await this.contract.deposit(publicPoolId, 0, [], 0, MAX_UINT256, staker, {
              from: poolOwner,
              value: new BN(String(1e18)).muln(64),
            });

            await this.contract.proposeStake(
              publicPoolId,
              operatorId,
              [pubkey0, pubkey1],
              [signature01, signature11],
              [signature031, signature131],
              {
                from: operatorMaintainer,
              }
            );

            // for private pool
            await this.contract.delegate(privatePoolId, [operatorId], [1], {
              from: poolMaintainer,
            });

            await this.contract.deposit(privatePoolId, 0, [], 0, MAX_UINT256, staker, {
              from: poolOwner,
              value: new BN(String(1e18)).muln(64),
            });

            await this.contract.proposeStake(
              privatePoolId,
              operatorId,
              [pubkey2],
              [signature11],
              [signature131],
              {
                from: operatorMaintainer,
              }
            );
          });
          context("first 2 approved", function () {
            beforeEach(async function () {
              await this.contract.$set_VERIFICATION_INDEX(2);
            });

            it("reverts for the last one", async function () {
              await expectRevert(
                this.contract.stake(operatorId, [pubkey0, pubkey1, pubkey2], {
                  from: operatorMaintainer,
                }),
                "SML:NOT all pubkeys are stakeable"
              );
            });

            it("reverts if malicious operator maintainer tries to stake other operators validator", async function () {
              await expectRevert(
                this.contract.stake(maliciousOperatorId, [pubkey0], {
                  from: maliciousOperatorMaintainer,
                }),
                "SML:NOT all pubkeys belong to operator"
              );
            });

            context("canStake", function () {
              it("returns false for unknown pk", async function () {
                expect(
                  await this.contract.canStake(
                    "0x6a53268594e7eceab8e2980801b9a2ffc4fb41d53e151ad9d8ce3ffa7c560b58fc7be900052b2a2f49051c6cb202fac5"
                  )
                ).to.be.equal(false);
              });
              it("returns true for pubkey 0", async function () {
                expect(await this.contract.canStake(pubkey0)).to.be.equal(true);
              });
              it("returns true for pubkey 1", async function () {
                expect(await this.contract.canStake(pubkey1)).to.be.equal(true);
              });
              it("returns false for pubkey 2", async function () {
                expect(await this.contract.canStake(pubkey2)).to.be.equal(false);
              });
            });
          });

          describe("all approved", function () {
            let tx;

            let preSecured;
            let preProposedValidators;
            let preActiveValidators;
            let preWallet;

            beforeEach(async function () {
              await this.contract.$set_VERIFICATION_INDEX(3);

              preSecured = [new BN("0"), new BN("0")];
              preProposedValidators = [new BN("0"), new BN("0")];
              preActiveValidators = [new BN("0"), new BN("0")];

              // for public pool
              preSecured[0] = await this.contract.readUint(publicPoolId, strToBytes32("secured"));
              preProposedValidators[0] = await this.contract.readUint(
                publicPoolId,
                await this.contract.getKey(operatorId, strToBytes32("proposedValidators"))
              );
              preActiveValidators[0] = await this.contract.readUint(
                publicPoolId,
                await this.contract.getKey(operatorId, strToBytes32("activeValidators"))
              );

              // for private pool
              preSecured[1] = await this.contract.readUint(privatePoolId, strToBytes32("secured"));
              preProposedValidators[1] = await this.contract.readUint(
                privatePoolId,
                await this.contract.getKey(operatorId, strToBytes32("proposedValidators"))
              );
              preActiveValidators[1] = await this.contract.readUint(
                privatePoolId,
                await this.contract.getKey(operatorId, strToBytes32("activeValidators"))
              );

              preWallet = await this.contract.readUint(operatorId, strToBytes32("wallet"));

              tx = await this.contract.stake(operatorId, [pubkey0, pubkey1, pubkey2], {
                from: operatorMaintainer,
              });
              ts = new BN((await getReceiptTimestamp(tx)).toString());
            });

            it("for both pools: decreases secured", async function () {
              expect(
                await this.contract.readUint(publicPoolId, strToBytes32("secured"))
              ).to.be.bignumber.equal(preSecured[0].sub(new BN(String(64e18))));
              expect(
                await this.contract.readUint(publicPoolId, strToBytes32("secured"))
              ).to.be.bignumber.equal(preSecured[1].sub(new BN(String(32e18))));
            });
            it("for both pools: decreased proposedValidators of operator", async function () {
              const key = await this.contract.getKey(
                operatorId,
                strToBytes32("proposedValidators")
              );
              expect(await this.contract.readUint(publicPoolId, key)).to.be.bignumber.equal(
                preProposedValidators[0].subn(2)
              );
              expect(await this.contract.readUint(privatePoolId, key)).to.be.bignumber.equal(
                preProposedValidators[1].subn(1)
              );
            });
            it("for both pools: increased activeValidators of operator", async function () {
              const key = await this.contract.getKey(operatorId, strToBytes32("activeValidators"));
              expect(await this.contract.readUint(publicPoolId, key)).to.be.bignumber.equal(
                preActiveValidators[0].addn(2)
              );
              expect(await this.contract.readUint(privatePoolId, key)).to.be.bignumber.equal(
                preActiveValidators[1].addn(1)
              );
            });
            it("for all validators: changes validator state", async function () {
              for (const pk of [pubkey0, pubkey1, pubkey2]) {
                expect((await this.contract.getValidator(pk)).state).to.be.bignumber.equal("2");
              }
            });
            it("repays to operator wallet", async function () {
              expect(
                await this.contract.readUint(operatorId, strToBytes32("wallet"))
              ).to.be.bignumber.equal(preWallet.add(new BN(String(3e18))));
            });
            it("emits Stake", async function () {
              await expectEvent(tx, "Stake", { pubkeys: [pubkey0, pubkey1, pubkey2] });
            });
          });
        });
      });
    });
  });
});
