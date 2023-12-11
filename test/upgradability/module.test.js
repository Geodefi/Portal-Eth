// const { expect } = require("chai");

// const { expectRevert, BN } = require("@openzeppelin/test-helpers");
// const { strToBytes, generateId } = require("../../utils");
// const { upgradePortal } = require("../../scripts/upgrade/portal");
// const { deployments } = require("hardhat");

// contract("UpgradePortal", function (accounts) {
//   const [deployer] = accounts;
//   let upgradedPortal;

//   const setupTestUpdateModule = deployments.createFixture(async (hre) => {
//     const { get } = deployments;

//     const version = "V3_0_Mock";

//     await deployments.fixture(["Portal", "GeodeModuleLibV3_0_Mock"]);

//     const oldPortalFactory = await ethers.getContractFactory("Portal", {
//       libraries: {
//         GeodeModuleLib: (await get("GeodeModuleLib")).address,
//         StakeModuleLib: (await get("StakeModuleLib")).address,
//         InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
//         OracleExtensionLib: (await get("OracleExtensionLib")).address,
//       },
//     });

//     const PortalFactory = await ethers.getContractFactory("Portal" + version, {
//       libraries: {
//         GeodeModuleLibV3_0_Mock: (await get("GeodeModuleLibV3_0_Mock")).address,
//         StakeModuleLib: (await get("StakeModuleLib")).address,
//         InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
//         OracleExtensionLib: (await get("OracleExtensionLib")).address,
//       },
//     });

//     upgradedPortal = await upgradePortal(hre, oldPortalFactory, PortalFactory, version);
//     await upgradedPortal.initializeV3_0_Mock(8);
//   });

//   const setupTestNewModule = deployments.createFixture(async (hre) => {
//     const { get } = deployments;

//     const version = "V4_0_Mock";

//     await deployments.fixture(["Portal", "FreshSlotModuleLib"]);

//     const oldPortalFactory = await ethers.getContractFactory("Portal", {
//       libraries: {
//         GeodeModuleLib: (await get("GeodeModuleLib")).address,
//         StakeModuleLib: (await get("StakeModuleLib")).address,
//         InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
//         OracleExtensionLib: (await get("OracleExtensionLib")).address,
//       },
//     });

//     const PortalFactory = await ethers.getContractFactory("Portal" + version, {
//       libraries: {
//         GeodeModuleLib: (await get("GeodeModuleLib")).address,
//         StakeModuleLib: (await get("StakeModuleLib")).address,
//         FreshSlotModuleLib: (await get("FreshSlotModuleLib")).address,
//         InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
//         OracleExtensionLib: (await get("OracleExtensionLib")).address,
//       },
//     });

//     upgradedPortal = await upgradePortal(hre, oldPortalFactory, PortalFactory, version);
//     await upgradedPortal.initializeV4_0_Mock(8);
//   });

//   describe("Upgrade Portal with Upgraded Module (GeodeModule)", async function () {
//     beforeEach(async function () {
//       await setupTestUpdateModule();
//     });

//     it("can use reinitializer: freshSlot = 8", async function () {
//       expect((await upgradedPortal.getFreshSlot()).toString()).to.be.equal(String(8));
//     });

//     it("_handleUpgrades works correctly: portal version = V3_0_Mock", async function () {
//       const version = await upgradedPortal.getContractVersion();
//       expect(version.toString()).to.equal(
//         (await generateId(strToBytes("V3_0_Mock"), 10001)).toString()
//       );
//     });

//     it("can add new function: setFreshSlot", async function () {
//       await upgradedPortal.setFreshSlot(3);
//       expect((await upgradedPortal.getFreshSlot()).toString()).to.be.equal(String(3));
//     });
//   });

//   describe("Upgrade Portal with New Module (FreshSlotModule)", async function () {
//     beforeEach(async function () {
//       await setupTestNewModule();
//     });

//     it("can use reinitializer: freshSlot = 8", async function () {
//       expect((await upgradedPortal.getFreshSlot()).toString()).to.be.equal(String(8));
//     });

//     it("_handleUpgrades works correctly: portal version = V4_0_Mock", async function () {
//       const version = await upgradedPortal.getContractVersion();
//       expect(version.toString()).to.equal(
//         (await generateId(strToBytes("V4_0_Mock"), 10001)).toString()
//       );
//     });

//     it("can add new function: setFreshSlot", async function () {
//       await upgradedPortal.setFreshSlot(3);
//       expect((await upgradedPortal.getFreshSlot()).toString()).to.be.equal(String(3));
//     });
//   });
// });
