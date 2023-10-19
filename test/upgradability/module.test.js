// context(LP),
// context(WP)
// 1. adding a new library to a module
//    - adding a new function and a parameter (struct)
// 2. changing an existing library
//    - changing the function,
// 3. removing the module library
//    - removing the added library and observing the storage struct (_DEPRECATED_SLOT on reinitalize)
// 4. adding a new module
//    - adding a new module with a storage struct and a function in the inheritance order
// 5. removing a module
//    - removing the added module and observing the storage struct (_DEPRECATED_SLOT on reinitalize)
// 6. Updating a package.
//    - update lp or wp.
const { expect } = require("chai");

const { expectRevert, BN } = require("@openzeppelin/test-helpers");
const { strToBytes, generateId } = require("../../utils");
const { upgradePortal } = require("../../scripts/upgrade/portal");
const { deployments } = require("hardhat");

contract("UpgradePortal", function (accounts) {
  const [deployer] = accounts;
  let upgradedPortal;

  const setupTest = deployments.createFixture(async (hre) => {
    const { get } = deployments;

    const version = "V3_0_Mock";

    await deployments.fixture(["Portal", "GeodeModuleLibV3_0_Mock"]);

    const oldPortalFactory = await ethers.getContractFactory("Portal", {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        StakeModuleLib: (await get("StakeModuleLib")).address,
        InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
        OracleExtensionLib: (await get("OracleExtensionLib")).address,
      },
    });

    const PortalFactory = await ethers.getContractFactory("Portal" + version, {
      libraries: {
        GeodeModuleLibV3_0_Mock: (await get("GeodeModuleLibV3_0_Mock")).address,
        StakeModuleLib: (await get("StakeModuleLib")).address,
        InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
        OracleExtensionLib: (await get("OracleExtensionLib")).address,
      },
    });

    upgradedPortal = await upgradePortal(hre, oldPortalFactory, PortalFactory, version);
    console.log("upgradedPortal", upgradedPortal);
    await upgradedPortal.initializeV3_0_Mock(8);
  });

  beforeEach(async function () {
    await setupTest();
  });

  describe("Upgrade Portal with Upgraded Module (GeodeModule)", async function () {
    it("can use reinitializer: freshSlot = 8", async function () {
      expect((await upgradedPortal.getFreshSlot()).toString()).to.be.equal(String(8));
    });

    it("_handleUpgrades works correctly: portal version = V3_0_Mock", async function () {
      const version = await upgradedPortal.getContractVersion();
      expect(version.toString()).to.equal(
        (await generateId(strToBytes("V3_0_Mock"), 10001)).toString()
      );
    });

    it("can add new function: setFreshSlot", async function () {
      await upgradedPortal.setFreshSlot(3);
      expect((await upgradedPortal.getFreshSlot()).toString()).to.be.equal(String(3));
    });
  });
});
