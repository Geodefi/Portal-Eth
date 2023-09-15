const { expect } = require("chai");

const { expectRevert, constants, BN } = require("@openzeppelin/test-helpers");
const { ZERO_ADDRESS } = constants;
const { strToBytes, strToBytes32 } = require("../../../utils");
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
  const [deployer, oracle, poolOwner] = accounts;

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
    await this.SMLM.initiatePool(0, 0, poolOwner, strToBytes(name), "0x", [false, false, false], {
      from: poolOwner,
      value: new BN(String(1e18)).muln(32),
    });
    const id = await this.SMLM.generateId(name, 5);
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
        expect(params.POOL_ID.toString()).to.be.equal(this.poolId.toString());
      });
      it("sets EXIT_THRESHOLD", async function () {
        expect(params.EXIT_THRESHOLD.toString()).to.be.equal((6 * 10e8).toString());
      });
    });
  });
});
