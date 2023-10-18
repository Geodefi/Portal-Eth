const { expect } = require("chai");

const { expectRevert, BN } = require("@openzeppelin/test-helpers");
const { strToBytes, generateId } = require("../../utils");
const { upgradePortal } = require("../../scripts/upgrade/portal");

contract("UpgradePortal", function (accounts) {
  const [deployer] = accounts;
  let upgradedPortal;

  const setupTest = deployments.createFixture(async (hre) => {
    const { get } = deployments;

    const version = "V3_0_Mock";

    await deployments.fixture(["Portal"]);

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
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        StakeModuleLib: (await get("StakeModuleLib")).address,
        InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
        OracleExtensionLib: (await get("OracleExtensionLib")).address,
      },
    });

    upgradedPortal = await upgradePortal(hre, oldPortalFactory, PortalFactory, version);
    await upgradedPortal.initializeV3_0_Mock(8);
  });

  beforeEach(async function () {
    await setupTest();
  });

  describe("Upgrade Portal", async function () {
    it("can use reinitializer: freshSlot = 8", async function () {
      expect((await upgradedPortal.getFreshSlot()).toString()).to.be.equal(String(8));
    });

    it("_handleUpgrades works correctly: portal version = V2_0_Mock", async function () {
      const version = await upgradedPortal.getContractVersion();
      expect(version.toString()).to.equal(
        (await generateId(strToBytes("V3_0_Mock"), 10001)).toString()
      );
    });

    it("can add new function: setFreshSlot", async function () {
      await upgradedPortal.setFreshSlot(3);
      expect((await upgradedPortal.getFreshSlot()).toString()).to.be.equal(String(3));
    });

    it("can mutate a function: setGovernanceFee", async function () {
      await upgradedPortal.setGovernanceFee(3, 2);
      const governanceFee = new BN((await upgradedPortal.StakeParams()).governanceFee);
      expect((await upgradedPortal.getFreshSlot()).toString()).to.be.equal(
        governanceFee.mul(new BN(String(2))).toString()
      );
    });

    it("can not call the old function: setGovernanceFee with only newFee parameter", async function () {
      expectRevert(upgradedPortal.setGovernanceFee(3));
    });
  });
});
