const { expect } = require("chai");
const { expectRevert, BN } = require("@openzeppelin/test-helpers");
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { strToBytes, generateId, DAY, setTimestamp, getBlockTimestamp } = require("../../utils");

const ERC1967Proxy = artifacts.require("ERC1967Proxy");

const Portal = artifacts.require("Portal");
const gETH = artifacts.require("gETH");
const LPToken = artifacts.require("LPToken");

const LiquidityModuleLib = artifacts.require("LiquidityModuleLib");
const GeodeModuleLib = artifacts.require("GeodeModuleLib");
const OracleExtensionLib = artifacts.require("OracleExtensionLib");
const StakeModuleLib = artifacts.require("StakeModuleLib");
const InitiatorExtensionLib = artifacts.require("InitiatorExtensionLib");

const WithdrawalModuleLib = artifacts.require("WithdrawalModuleLib");
const WithdrawalPackage = artifacts.require("WithdrawalPackage");
const LiquidityPackage = artifacts.require("LiquidityPackage");

contract("LiquidityPackage", function (accounts) {
  const [deployer, owner] = accounts;
  let tokenId;

  before(async function () {
    this.SML = await StakeModuleLib.new();
    // this should be before --> await InitiatorExtensionLib.new();
    await InitiatorExtensionLib.link(this.SML);
    this.IEL = await InitiatorExtensionLib.new();
    this.OEL = await OracleExtensionLib.new();
    this.LML = await LiquidityModuleLib.new();
    this.GML = await GeodeModuleLib.new();
    this.WML = await WithdrawalModuleLib.new();

    await Portal.link(this.GML);
    await Portal.link(this.SML);
    await Portal.link(this.OEL);
    await Portal.link(this.IEL);

    await LiquidityPackage.link(this.GML);
    await LiquidityPackage.link(this.LML);

    await WithdrawalPackage.link(this.GML);
    await WithdrawalPackage.link(this.WML);

    tokenId = await generateId(strToBytes("name"), 5);
  });

  beforeEach(async function () {
    this.gETH = await gETH.new("name", "symbol", "uri", { from: deployer });
    const portalImp = await Portal.new();
    const { address } = await ERC1967Proxy.new(portalImp.address, "0x");
    this.portal = await Portal.at(address);
    await this.portal.initialize(deployer, deployer, this.gETH.address, deployer, strToBytes("v1"));
    this.lpImp = await LPToken.new();

    // set up the portal
    await this.gETH.transferMinterRole(this.portal.address);
    await this.gETH.transferMiddlewareManagerRole(this.portal.address);
    await this.gETH.transferOracleRole(this.portal.address);

    const WP = await WithdrawalPackage.new(this.gETH.address, this.portal.address);

    await this.portal.propose(WP.address, 10011, strToBytes("name"), DAY, { from: deployer });
    await this.portal.approveProposal(await generateId(strToBytes("name"), 10011), {
      from: deployer,
    });
    this.implementation = await LiquidityPackage.new(
      this.gETH.address,
      this.portal.address,
      this.lpImp.address
    );

    await this.portal.propose(this.implementation.address, 10021, strToBytes("name"), DAY, {
      from: deployer,
    });

    await this.portal.approveProposal(await generateId(strToBytes("name"), 10021), {
      from: deployer,
    });
    await this.portal.initiatePool(0, 0, owner, strToBytes("name"), "0x", [false, false, false], {
      from: owner,
      value: new BN(String(1e18)).muln(32),
    });

    await this.portal.deployLiquidityPackage(tokenId, { from: owner });

    this.contract = await LiquidityPackage.at(
      await this.portal.readAddress(tokenId, strToBytes("liquidityPackage"))
    );
  });

  describe("Constructor", function () {
    it("reverts if _gETHPos is zero", async function () {
      await expectRevert(
        LiquidityPackage.new(ZERO_ADDRESS, this.portal.address, this.lpImp.address, {
          from: deployer,
        }),
        "LP:_gETHPos cannot be zero"
      );
    });
    it("reverts if _portalPos is zero", async function () {
      await expectRevert(
        LiquidityPackage.new(this.gETH.address, ZERO_ADDRESS, this.lpImp.address, {
          from: deployer,
        }),
        "LP:_portalPos cannot be zero"
      );
    });
    it("reverts if _LPTokenRef is zero", async function () {
      await expectRevert(
        LiquidityPackage.new(this.gETH.address, this.portal.address, ZERO_ADDRESS, {
          from: deployer,
        }),
        "LP:_LPTokenRef cannot be zero"
      );
    });
  });

  describe("getters", function () {
    it("getPoolId", async function () {
      expect(await this.contract.getPoolId()).to.be.bignumber.equal(tokenId);
    });
    it("getPortal", async function () {
      expect(await this.contract.getPortal()).to.be.equal(this.portal.address);
    });
    it("getProposedVersion", async function () {
      expect(await this.contract.getProposedVersion()).to.be.bignumber.equal(
        await generateId(strToBytes("name"), 10021)
      );
    });
  });

  describe("reverts for onlyOwner", function () {
    it("pause", async function () {
      await expectRevert(this.contract.pause(), "LP:sender not owner");
      await this.contract.pause({ from: owner });
    });
    it("unpause", async function () {
      await this.contract.pause({ from: owner });
      await expectRevert(this.contract.unpause(), "LP:sender not owner");
      await this.contract.unpause({ from: owner });
    });
    it("setSwapFee", async function () {
      await expectRevert(this.contract.setSwapFee(0), "LP:sender not owner");
      await this.contract.setSwapFee(1, { from: owner });
    });
    it("setAdminFee", async function () {
      await expectRevert(this.contract.setAdminFee(0), "LP:sender not owner");
      await this.contract.setAdminFee(1, { from: owner });
    });
    it("withdrawAdminFees", async function () {
      await expectRevert(this.contract.withdrawAdminFees(ZERO_ADDRESS), "LP:sender not owner");
      await this.contract.withdrawAdminFees(owner, { from: owner });
    });
    it("rampA", async function () {
      await expectRevert(this.contract.rampA(0, 0), "LP:sender not owner");
      await this.contract.rampA(100, (await getBlockTimestamp()).add(DAY.muln(14).addn(1)), {
        from: owner,
      });
    });
    it("stopRampA", async function () {
      await this.contract.rampA(100, (await getBlockTimestamp()).add(DAY.muln(14).addn(1)), {
        from: owner,
      });
      await expectRevert(this.contract.stopRampA(), "LP:sender not owner");
      await this.contract.stopRampA({ from: owner });
    });
  });

  describe("isolationMode", function () {
    it("false to begin with", async function () {
      expect(await this.contract.isolationMode()).to.be.equal(false);
    });
    it("returns true if paused", async function () {
      await this.contract.pause({ from: owner });
      expect(await this.contract.isolationMode()).to.be.equal(true);
    });
    it("returns true if there is a new version", async function () {
      await this.portal.propose(this.implementation.address, 10021, strToBytes("othername"), DAY, {
        from: deployer,
      });

      await this.portal.approveProposal(await generateId(strToBytes("othername"), 10021), {
        from: deployer,
      });
      expect(await this.contract.isolationMode()).to.be.equal(true);
    });
    it("returns true if pool controller has changed", async function () {
      await this.portal.changeIdCONTROLLER(tokenId, deployer, { from: owner });
      expect(await this.contract.isolationMode()).to.be.equal(true);
    });
  });

  describe("pullUpgrade", function () {
    it("reverts if not owner", async function () {
      await expectRevert(this.contract.pullUpgrade(), "LP:sender not owner");
    });
    it("reverts if portal is in isolation", async function () {
      await setTimestamp((await getBlockTimestamp()).add(DAY.muln(366)).toNumber());
      await expectRevert(this.contract.pullUpgrade({ from: owner }), "LP:Portal is isolated");
    });
    it("reverts if there is no new version", async function () {
      await expectRevert(this.contract.pullUpgrade({ from: owner }), "LP:no upgrades");
    });

    context("success", function () {
      let newimplementation;
      beforeEach(async function () {
        newimplementation = await LiquidityPackage.new(
          this.gETH.address,
          this.portal.address,
          this.lpImp.address
        );

        await this.portal.propose(newimplementation.address, 10021, strToBytes("othername"), DAY, {
          from: deployer,
        });

        await this.portal.approveProposal(await generateId(strToBytes("othername"), 10021), {
          from: deployer,
        });
        await this.contract.pullUpgrade({ from: owner });
      });

      it("upgraded!", async function () {
        expect(await this.contract.getContractVersion()).to.be.bignumber.equal(
          await generateId(strToBytes("othername"), 10021)
        );
      });
      it("cannot pull again", async function () {
        await expectRevert(this.contract.pullUpgrade({ from: owner }), "LP:no upgrades");
      });
    });
  });
});
