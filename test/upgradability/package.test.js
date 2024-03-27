// const { expect } = require("chai");

// const { BN } = require("@openzeppelin/test-helpers");
// const { strToBytes, strToBytes32, generateId, DAY } = require("../../utils");
// const { upgradePackage, upgradeLiquidityPackage } = require("../../scripts/upgrade/package");

// const ERC1967Proxy = artifacts.require("ERC1967Proxy");

// const Portal = artifacts.require("Portal");
// const gETH = artifacts.require("gETH");
// const LPToken = artifacts.require("LPToken");

// const LiquidityModuleLib = artifacts.require("LiquidityModuleLib");
// const GeodeModuleLib = artifacts.require("GeodeModuleLib");
// const OracleExtensionLib = artifacts.require("OracleExtensionLib");
// const StakeModuleLib = artifacts.require("StakeModuleLib");
// const InitiatorExtensionLib = artifacts.require("InitiatorExtensionLib");

// const WithdrawalModuleLib = artifacts.require("WithdrawalModuleLib");
// const WithdrawalPackage = artifacts.require("WithdrawalPackage");
// const LiquidityPackage = artifacts.require("LiquidityPackage");

// contract("UpgradePackages", function (accounts) {
//   const [deployer, poolOwner] = accounts;
//   let upgradeWithdrawalPackage;
//   let upgradedPoolWP;
//   let upgradedPoolLP;
//   let portal;
//   let gETHContract;
//   let tokenId;

//   let poolOwnerSigner;

//   const setupTest = deployments.createFixture(async (hre) => {
//     poolOwnerSigner = await ethers.getSigner(poolOwner);

//     gETHContract = await gETH.new("name", "symbol", "uri", { from: deployer });
//     const portalImp = await Portal.new();
//     const { address } = await ERC1967Proxy.new(portalImp.address, "0x");
//     portal = await Portal.at(address);
//     await portal.initialize(deployer, deployer, gETHContract.address, deployer, strToBytes("v1"));

//     // set up the portal to gETH
//     await gETHContract.transferMinterRole(portal.address);
//     await gETHContract.transferMiddlewareManagerRole(portal.address);
//     await gETHContract.transferOracleRole(portal.address);
//   });

//   const setupWPTest = deployments.createFixture(async (hre) => {
//     // set WP as middleware
//     const wp = await WithdrawalPackage.new(gETHContract.address, portal.address);
//     await portal.propose(wp.address, 10011, strToBytes("name"), DAY, { from: deployer });
//     await portal.approveProposal(await generateId(strToBytes("name"), 10011), {
//       from: deployer,
//     });

//     // initiate pool
//     await portal.initiatePool(0, 0, poolOwner, strToBytes("name"), "0x", [false, false, false], {
//       from: poolOwner,
//       value: new BN(String(1e18)).muln(32),
//     });

//     // upgrade the WP with proposal on portal
//     await deployments.fixture(["WithdrawalPackage"]);
//     await upgradePackage(hre, portal, "V2_0_Mock");

//     // pull the upgrade
//     const WPAddress = await portal.readAddress(tokenId, strToBytes32("withdrawalPackage"));
//     const poolWP = await ethers.getContractAt("WithdrawalPackage", WPAddress);
//     await poolWP.connect(poolOwnerSigner).pullUpgrade();

//     // set upgraded WP and initialize
//     upgradedPoolWP = await ethers.getContractAt("WithdrawalPackageV2_0_Mock", WPAddress);
//     await upgradedPoolWP.connect(poolOwnerSigner).initializeV2_0_Mock(8);
//   });

//   const setupLPTest = deployments.createFixture(async (hre) => {
//     // set WP as middleware
//     const wp = await WithdrawalPackage.new(gETHContract.address, portal.address);
//     await portal.propose(wp.address, 10011, strToBytes("name"), DAY, { from: deployer });
//     await portal.approveProposal(await generateId(strToBytes("name"), 10011), {
//       from: deployer,
//     });

//     // set LP as middleware
//     const lpImp = await LPToken.new();
//     const lp = await LiquidityPackage.new(gETHContract.address, portal.address, lpImp.address);
//     await portal.propose(lp.address, 10021, strToBytes("name"), DAY, {
//       from: deployer,
//     });
//     await portal.approveProposal(await generateId(strToBytes("name"), 10021), {
//       from: deployer,
//     });

//     // initiate pool
//     await portal.initiatePool(0, 0, poolOwner, strToBytes("name"), "0x", [false, false, false], {
//       from: poolOwner,
//       value: new BN(String(1e18)).muln(32),
//     });

//     // deploy LP for pool
//     await portal.deployLiquidityPackage(tokenId, { from: poolOwner });

//     // upgrade the LP with proposal on portal
//     await deployments.fixture(["LiquidityPackage"]);
//     await upgradeLiquidityPackage(hre, portal, "V2_0_Mock");

//     // pull the upgrade
//     const LPAddress = await portal.readAddress(tokenId, strToBytes32("liquidityPackage"));
//     const poolLP = await ethers.getContractAt("LiquidityPackage", LPAddress);
//     await poolLP.connect(poolOwnerSigner).pullUpgrade();

//     // set upgraded WP and initialize
//     upgradedPoolLP = await ethers.getContractAt("LiquidityPackageV2_0_Mock", LPAddress);
//     await upgradedPoolLP.connect(poolOwnerSigner).initializeV2_0_Mock(8);
//   });

//   before(async function () {
//     this.SML = await StakeModuleLib.new();
//     // this should be before --> await InitiatorExtensionLib.new();
//     await InitiatorExtensionLib.link(this.SML);
//     this.IEL = await InitiatorExtensionLib.new();
//     this.OEL = await OracleExtensionLib.new();
//     this.LML = await LiquidityModuleLib.new();
//     this.GML = await GeodeModuleLib.new();
//     this.WML = await WithdrawalModuleLib.new();

//     await Portal.link(this.GML);
//     await Portal.link(this.SML);
//     await Portal.link(this.OEL);
//     await Portal.link(this.IEL);

//     await LiquidityPackage.link(this.GML);
//     await LiquidityPackage.link(this.LML);

//     await WithdrawalPackage.link(this.GML);
//     await WithdrawalPackage.link(this.WML);

//     tokenId = await generateId(strToBytes("name"), 5);
//   });

//   beforeEach(async function () {
//     await setupTest();
//   });

//   describe("Upgrade WP Package", async function () {
//     beforeEach(async function () {
//       await setupWPTest();
//     });
//     it("can use reinitializer: freshSlot = 8", async function () {
//       expect((await upgradedPoolWP.getFreshSlot()).toString()).to.be.equal(String(8));
//     });

//     it("Upgrade works correctly: WP version = V2_0_Mock", async function () {
//       const version = await upgradedPoolWP.getContractVersion();
//       expect(version.toString()).to.equal(
//         (await generateId(strToBytes("V2_0_Mock"), 10011)).toString()
//       );
//     });

//     it("can add new function with parameter: setFreshSlot, freshSlot", async function () {
//       await upgradedPoolWP.setFreshSlot(3);
//       expect((await upgradedPoolWP.getFreshSlot()).toString()).to.be.equal(String(3));
//     });
//   });

//   describe("Upgrade LP Package", async function () {
//     beforeEach(async function () {
//       await setupLPTest();
//     });
//     it("can use reinitializer: freshSlot = 8", async function () {
//       expect((await upgradedPoolLP.getFreshSlot()).toString()).to.be.equal(String(8));
//     });

//     it("Upgrade works correctly: LP version = V2_0_Mock", async function () {
//       const version = await upgradedPoolLP.getContractVersion();
//       expect(version.toString()).to.equal(
//         (await generateId(strToBytes("V2_0_Mock"), 10021)).toString()
//       );
//     });

//     it("can add new function with parameter: setFreshSlot, freshSlot", async function () {
//       await upgradedPoolLP.setFreshSlot(3);
//       expect((await upgradedPoolLP.getFreshSlot()).toString()).to.be.equal(String(3));
//     });
//   });
// });
