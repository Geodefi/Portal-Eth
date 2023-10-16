const { expect } = require("chai");

const { BN } = require("@openzeppelin/test-helpers");
const { strToBytes, strToBytes32, generateId, DAY } = require("../../utils");
const { upgradePackage } = require("../../scripts/upgrade/package");

const ERC1967Proxy = artifacts.require("ERC1967Proxy");

const Portal = artifacts.require("Portal");
const gETH = artifacts.require("gETH");
// const LPToken = artifacts.require("LPToken");

// const LiquidityModuleLib = artifacts.require("LiquidityModuleLib");
const GeodeModuleLib = artifacts.require("GeodeModuleLib");
const OracleExtensionLib = artifacts.require("OracleExtensionLib");
const StakeModuleLib = artifacts.require("StakeModuleLib");
const InitiatorExtensionLib = artifacts.require("InitiatorExtensionLib");

const WithdrawalModuleLib = artifacts.require("WithdrawalModuleLib");
const WithdrawalContract = artifacts.require("WithdrawalContract");
// const LiquidityPool = artifacts.require("LiquidityPool");

contract("UpgradePackages", function (accounts) {
  const [deployer, poolOwner] = accounts;
  let upgradeWithdrawalPackage;
  let poolId;
  let upgradedPoolWC;
  let portal;

  let poolOwnerSigner;

  const setupTest = deployments.createFixture(async (hre) => {
    poolOwnerSigner = await ethers.getSigner(poolOwner);

    this.gETH = await gETH.new("name", "symbol", "uri", { from: deployer });
    const portalImp = await Portal.new();
    const { address } = await ERC1967Proxy.new(portalImp.address, "0x");
    portal = await Portal.at(address);
    await portal.initialize(deployer, deployer, this.gETH.address, deployer, strToBytes("v1"));

    // set up the portal to gETH
    await this.gETH.transferMinterRole(portal.address);
    await this.gETH.transferMiddlewareManagerRole(portal.address);
    await this.gETH.transferOracleRole(portal.address);

    // set WC as middleware
    const wc = await WithdrawalContract.new(this.gETH.address, portal.address);
    await portal.propose(wc.address, 10011, strToBytes("name"), DAY, { from: deployer });
    await portal.approveProposal(await generateId(strToBytes("name"), 10011), {
      from: deployer,
    });

    // initiate pool
    await portal.initiatePool(0, 0, poolOwner, strToBytes("name"), "0x", [false, false, false], {
      from: poolOwner,
      value: new BN(String(1e18)).muln(32),
    });

    // upgrade the WC with proposal on portal
    await deployments.fixture(["WithdrawalContract"]);
    await upgradePackage(hre, portal, "V2_0_Mock");

    // pull the upgrade
    poolId = await generateId(strToBytes("name"), 5);
    const WCAddress = await portal.readAddress(poolId, strToBytes32("withdrawalContract"));
    const poolWC = await ethers.getContractAt("WithdrawalContract", WCAddress);
    await poolWC.connect(poolOwnerSigner).pullUpgrade();

    // set upgraded WC and initialize
    upgradedPoolWC = await ethers.getContractAt("WithdrawalContractV2_0_Mock", WCAddress);
    await upgradedPoolWC.connect(poolOwnerSigner).initializeV2_0_Mock(8);
  });

  before(async function () {
    this.SML = await StakeModuleLib.new();
    // this should be before --> await InitiatorExtensionLib.new();
    await InitiatorExtensionLib.link(this.SML);
    this.IEL = await InitiatorExtensionLib.new();
    this.OEL = await OracleExtensionLib.new();
    // this.LML = await LiquidityModuleLib.new();
    this.GML = await GeodeModuleLib.new();
    this.WML = await WithdrawalModuleLib.new();

    await Portal.link(this.GML);
    await Portal.link(this.SML);
    await Portal.link(this.OEL);
    await Portal.link(this.IEL);

    // await LiquidityPool.link(this.GML);
    // await LiquidityPool.link(this.LML);

    await WithdrawalContract.link(this.GML);
    await WithdrawalContract.link(this.WML);

    // tokenId = await generateId(strToBytes("name"), 5);
  });

  beforeEach(async function () {
    await setupTest();
  });

  describe("Upgrade WC Package", async function () {
    it("can use reinitializer: freshSlot = 8", async function () {
      expect((await upgradedPoolWC.getFreshSlot()).toString()).to.be.equal(String(8));
    });

    it("Upgrade works correctly: WC version = V2_0_Mock", async function () {
      const version = await upgradedPoolWC.getContractVersion();
      console.log("version: ", await generateId(strToBytes("V2_0_Mock"), 10011));
      expect(version.toString()).to.equal(
        (await generateId(strToBytes("V2_0_Mock"), 10011)).toString()
      );
    });

    it("can add new function with parameter: setFreshSlot, freshSlot", async function () {
      await upgradedPoolWC.setFreshSlot(3);
      expect((await upgradedPoolWC.getFreshSlot()).toString()).to.be.equal(String(3));
    });
  });
});
