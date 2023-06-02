const { expect } = require("chai");
const { upgrades } = require("hardhat");

const { BN, expectRevert, expectEvent, constants } = require("@openzeppelin/test-helpers");
const { ZERO_ADDRESS } = constants;

const {
  DAY,
  WEEK,
  getBlockTimestamp,
  strToBytes,
  generateId,
  getReceiptTimestamp,
  setTimestamp,
  strToBytes32,
} = require("../../utils");

const ERC1967Proxy = artifacts.require("ERC1967Proxy");

const GeodeModuleLib = artifacts.require("GeodeModuleLib");

const GeodeModuleMock = artifacts.require("GeodeModuleMock");
const GeodeUpgradedMock = artifacts.require("GeodeUpgradedMock");

contract("GeodeModule", function (accounts) {
  const [deployer, governance, senate, user] = accounts;

  const packageType = new BN(10001);
  const initVersionName = strToBytes("v1");
  const MIN_PROPOSAL_DURATION = DAY; // 1 day
  const MAX_PROPOSAL_DURATION = WEEK.muln(4); // 4 weeks
  const MAX_SENATE_PERIOD = DAY.muln(365); // 1 year

  let initTs;
  let initVersion;

  before(async function () {
    this.library = await GeodeModuleLib.new();
    await GeodeUpgradedMock.link(this.library);
    await GeodeModuleMock.link(this.library);

    this.implementation = await GeodeModuleMock.new();

    initVersion = await generateId(initVersionName, packageType);
  });

  beforeEach(async function () {
    const { address } = await ERC1967Proxy.new(this.implementation.address, "0x");

    initTs = await getBlockTimestamp();
    this.contract = await GeodeModuleMock.at(address);
  });

  context("module", function () {
    describe("__GeodeModule_init_unchained", function () {
      it("reverts if no governance", async function () {
        await expectRevert(
          this.contract.initialize(
            ZERO_ADDRESS,
            senate,
            initTs.add(MAX_SENATE_PERIOD),
            packageType,
            initVersionName
          ),
          "GM:governance can not be zero"
        );
      });
      it("reverts if no senate", async function () {
        await expectRevert(
          this.contract.initialize(
            governance,
            ZERO_ADDRESS,
            initTs.add(MAX_SENATE_PERIOD),
            packageType,
            initVersionName
          ),
          "GM:senate can not be zero"
        );
      });
      it("reverts if already expired", async function () {
        await expectRevert(
          this.contract.initialize(governance, senate, initTs, packageType, initVersionName),
          "GM:low senateExpiry"
        );
      });
      it("reverts if package type is 0", async function () {
        await expectRevert(
          this.contract.initialize(
            governance,
            senate,
            initTs.add(MAX_SENATE_PERIOD),
            0,
            initVersionName
          ),
          "GM:packageType can not be zero"
        );
      });
      it("reverts if no version name", async function () {
        await expectRevert(
          this.contract.initialize(
            governance,
            senate,
            initTs.add(MAX_SENATE_PERIOD),
            packageType,
            "0x"
          ),
          "GM:initVersionName can not be empty"
        );
      });
    });

    describe("successfully initialized", function () {
      let params;
      beforeEach(async function () {
        await this.contract.initialize(
          governance,
          senate,
          initTs.add(MAX_SENATE_PERIOD),
          packageType,
          initVersionName,
          { from: deployer }
        );
        params = await this.contract.GeodeParams();
      });

      it("correct governance", async function () {
        expect(params.governance).to.be.equal(governance);
      });
      it("correct senate", async function () {
        expect(params.senate).to.be.equal(senate);
      });
      it("correct approved Upgrade", async function () {
        expect(params.approvedUpgrade).to.be.equal(this.implementation.address);
      });
      it("correct senate expiration", async function () {
        expect(params.senateExpiry).to.be.bignumber.equal(initTs.add(MAX_SENATE_PERIOD));
      });
      it("correct package type", async function () {
        expect(params.packageType).to.be.bignumber.equal(packageType);
      });
      it("correct CONTRACT_VERSION", async function () {
        expect(await this.contract.getContractVersion()).to.be.bignumber.equal(initVersion);
      });

      it("isolationMode false", async function () {
        expect(await this.contract.isolationMode()).to.be.equal(false);
      });
      it("isUpgradeAllowed false", async function () {
        expect(await this.contract.isUpgradeAllowed(this.implementation.address)).to.be.equal(
          false
        );
      });
    });
  });

  context("library", function () {
    const _type = new BN("69");
    const _name = strToBytes("user");

    beforeEach(async function () {
      await this.contract.initialize(
        governance,
        senate,
        initTs.add(MAX_SENATE_PERIOD),
        packageType,
        initVersionName,
        { from: deployer }
      );
    });

    describe("propose", function () {
      it("reverts if not governance", async function () {
        await expectRevert(
          this.contract.propose(user, _type, _name, MIN_PROPOSAL_DURATION, {
            from: user,
          }),
          "GML:GOVERNANCE role needed"
        );
      });
      it("reverts if ID is already proposed", async function () {
        await this.contract.propose(user, _type, _name, MIN_PROPOSAL_DURATION, {
          from: governance,
        });
        await expectRevert(
          this.contract.propose(user, _type, _name, MIN_PROPOSAL_DURATION, {
            from: governance,
          }),
          "GML:already proposed"
        );
      });
      it("reverts if controller is zero", async function () {
        await expectRevert(
          this.contract.propose(ZERO_ADDRESS, _type, _name, MIN_PROPOSAL_DURATION, {
            from: governance,
          }),
          "GML:CONTROLLER can NOT be ZERO"
        );
      });
      it("reverts proposal duration is short or long", async function () {
        await expectRevert(
          this.contract.propose(user, _type, _name, MIN_PROPOSAL_DURATION.subn(1), {
            from: governance,
          }),
          "GML:invalid proposal duration"
        );
        await expectRevert(
          this.contract.propose(user, _type, _name, MAX_PROPOSAL_DURATION.addn(1), {
            from: governance,
          }),
          "GML:invalid proposal duration"
        );
      });
      it("reverts if type is 0, 3, 5", async function () {
        await expectRevert(
          this.contract.propose(user, 0, _name, MIN_PROPOSAL_DURATION, {
            from: governance,
          }),
          "GML:TYPE is NONE, GAP or POOL"
        );
        await expectRevert(
          this.contract.propose(user, 3, _name, MIN_PROPOSAL_DURATION, {
            from: governance,
          }),
          "GML:TYPE is NONE, GAP or POOL"
        );
        await expectRevert(
          this.contract.propose(user, 5, _name, MIN_PROPOSAL_DURATION, {
            from: governance,
          }),
          "GML:TYPE is NONE, GAP or POOL"
        );
      });
      context("success", function () {
        let _id;
        let tx;
        let ts;
        beforeEach(async function () {
          tx = await this.contract.propose(user, _type, _name, MIN_PROPOSAL_DURATION, {
            from: governance,
          });
          ts = await getReceiptTimestamp(tx);
          _id = await generateId(_name, _type);
        });
        it("proposal params", async function () {
          const proposal = await this.contract.getProposal(_id);
          expect(proposal.CONTROLLER).to.be.equal(user);
          expect(proposal.TYPE).to.be.bignumber.equal(_type);
          expect(proposal.NAME).to.be.equal(_name);
          expect(proposal.deadline).to.be.bignumber.equal(ts.add(MIN_PROPOSAL_DURATION));
        });
        it("emits Proposed", async function () {
          await expectEvent(tx, "Proposed", {
            TYPE: _type,
            ID: _id,
            CONTROLLER: user,
            deadline: ts.add(MIN_PROPOSAL_DURATION),
          });
        });
        it("correct return", async function () {
          await expectEvent(tx, "return$propose", { id: _id });
        });
      });
    });

    describe("approveProposal", function () {
      let ts;
      let _id;

      beforeEach(async function () {
        const tx = await this.contract.propose(user, _type, _name, MIN_PROPOSAL_DURATION, {
          from: governance,
        });
        ts = await getReceiptTimestamp(tx);
        _id = await generateId(_name, _type);
      });

      it("reverts if not senate", async function () {
        await expectRevert(
          this.contract.approveProposal(_id, {
            from: user,
          }),
          "GML:SENATE role needed"
        );
      });
      it("reverts if expired", async function () {
        await setTimestamp(ts.add(MIN_PROPOSAL_DURATION).addn(1).toNumber());

        await expectRevert(
          this.contract.approveProposal(_id, {
            from: senate,
          }),
          "GML:NOT an active proposal"
        );
      });

      context("success", function () {
        let tx;
        let ts;
        beforeEach(async function () {
          tx = await this.contract.approveProposal(_id, {
            from: senate,
          });
          ts = await getReceiptTimestamp(tx);
          _id = await generateId(_name, _type);
        });
        it("sets TYPE to datastore", async function () {
          expect(await this.contract.readUint(_id, strToBytes32("TYPE"))).to.be.bignumber.equal(
            _type
          );
        });
        it("sets CONTROLLER to datastore", async function () {
          expect(await this.contract.readAddress(_id, strToBytes32("CONTROLLER"))).to.be.equal(
            user
          );
        });
        it("sets NAME to datastore", async function () {
          expect(await this.contract.readBytes(_id, strToBytes32("NAME"))).to.be.equal(_name);
        });
        it("pushes to allIdsByType", async function () {
          expect(await this.contract.allIdsByType(_type, 0)).to.be.bignumber.equal(_id);
        });
        it("sets deadline to timestamp", async function () {
          expect((await this.contract.getProposal(_id)).deadline).to.be.bignumber.equal(ts);
        });
        it("emits Approved", async function () {
          await expectEvent(tx, "Approved", { ID: _id });
        });
        it("correct return", async function () {
          await expectEvent(tx, "return$approveProposal", {
            controller: user,
            _type: _type,
            name: _name,
          });
        });

        context("SENATE: TYPE 1", function () {
          beforeEach(async function () {
            _id = await generateId(_name, 1);
            await this.contract.propose(user, 1, _name, MIN_PROPOSAL_DURATION, {
              from: governance,
            });
            tx = await this.contract.approveProposal(_id, {
              from: senate,
            });
            ts = await getReceiptTimestamp(tx);
          });
          it("changes senate", async function () {
            expect((await this.contract.GeodeParams()).senate).to.be.equal(user);
          });
          it("changes senate expiry", async function () {
            expect((await this.contract.GeodeParams()).senateExpiry).to.be.bignumber.equal(
              ts.add(MAX_SENATE_PERIOD)
            );
          });
          it("emits NewSenate", async function () {
            await expectEvent(tx, "NewSenate", { senate: user, expiry: ts.add(MAX_SENATE_PERIOD) });
          });
        });
      });
    });

    describe("changeSenate", function () {
      it("reverts if not senate", async function () {
        await expectRevert(this.contract.changeSenate(user), "GML:SENATE role needed");
      });
      describe("success", function () {
        beforeEach(async function () {
          await this.contract.changeSenate(user, { from: senate });
        });
        it("changes senate", async function () {
          expect((await this.contract.GeodeParams()).senate).to.be.equal(user);
        });
        it("does not change expiry", async function () {
          expect((await this.contract.GeodeParams()).senateExpiry).to.be.bignumber.equal(
            initTs.add(MAX_SENATE_PERIOD)
          );
        });
      });
    });

    describe("rescueSenate", function () {
      it("reverts if not governance", async function () {
        await expectRevert(this.contract.rescueSenate(user), "GML:GOVERNANCE role needed");
      });

      it("reverts if no rescue is needed", async function () {
        await setTimestamp(initTs.add(MAX_SENATE_PERIOD).subn(10).toNumber());
        await expectRevert(
          this.contract.rescueSenate(user, { from: governance }),
          "GML:cannot rescue yet"
        );
      });

      describe("success", function () {
        let ts;
        beforeEach(async function () {
          await setTimestamp(initTs.add(MAX_SENATE_PERIOD).addn(10).toNumber());

          const tx = await this.contract.rescueSenate(user, { from: governance });
          ts = await getReceiptTimestamp(tx);
        });
        it("changes senate", async function () {
          expect((await this.contract.GeodeParams()).senate).to.be.equal(user);
        });
        it("changes expiry", async function () {
          expect((await this.contract.GeodeParams()).senateExpiry).to.be.bignumber.equal(
            ts.add(MAX_SENATE_PERIOD)
          );
        });
      });
    });

    describe("changeIdCONTROLLER", function () {
      let _id;

      beforeEach(async function () {
        _id = await generateId(_name, _type);
        await this.contract.propose(user, _type, _name, MIN_PROPOSAL_DURATION, {
          from: governance,
        });
        await this.contract.approveProposal(_id, {
          from: senate,
        });
      });

      it("reverts when NOT CONTROLLER", async function () {
        await expectRevert(
          this.contract.changeIdCONTROLLER(_id, user),
          "GML:CONTROLLER role needed"
        );
      });
      it("reverts when ZERO_ADDRESS", async function () {
        await expectRevert(
          this.contract.changeIdCONTROLLER(_id, ZERO_ADDRESS, { from: user }),
          "GML:CONTROLLER can not be zero"
        );
      });

      it("success: changes it", async function () {
        await this.contract.changeIdCONTROLLER(_id, deployer, { from: user });
        expect(await this.contract.readAddress(_id, strToBytes32("CONTROLLER"))).to.be.equal(
          deployer
        );
      });
    });

    context("Limited UUPS (TYPE 2 proposal)", function () {
      let newImplementation;

      before(async function () {
        // make sure it is not upgraded yet!
        const implementationAddress = await upgrades.erc1967.getImplementationAddress(
          this.contract.address
        );
        expect(implementationAddress).to.be.equal(this.implementation.address);

        newImplementation = await GeodeUpgradedMock.new();
        await this.contract.propose(
          newImplementation.address,
          packageType,
          _name,
          MIN_PROPOSAL_DURATION,
          {
            from: governance,
          }
        );

        await this.contract.approveProposal(await generateId(_name, packageType), {
          from: senate,
        });

        this.contract = await GeodeUpgradedMock.at(this.contract.address);
      });

      it("correct APPROVED_UPGRADE", async function () {
        expect((await this.contract.GeodeParams()).approvedUpgrade).to.be.equal(
          newImplementation.address
        );
      });
      it("correct CONTRACT_VERSION", async function () {
        expect(await this.contract.getContractVersion()).to.be.bignumber.equal(
          await generateId(_name, packageType)
        );
      });
      it("changes the implementation address", async function () {
        const implementationAddress = await upgrades.erc1967.getImplementationAddress(
          this.contract.address
        );
        expect(implementationAddress).to.be.equal(newImplementation.address);
      });
      it("isUpgradeAllowed returns false", async function () {
        expect(await this.contract.isUpgradeAllowed(newImplementation.address)).to.be.equal(false);
      });
      it("isolationMode returns false", async function () {
        expect(await this.contract.isolationMode()).to.be.equal(false);
      });
      context("new implementation is effective", function () {
        it("can use reinitializer", async function () {
          await this.contract.initialize2(69);
          expect(await this.contract.getDumb()).to.be.bignumber.equal("69");
        });
        it("can use the extra storage", async function () {
          await this.contract.setDumb(69);
          expect(await this.contract.getDumb()).to.be.bignumber.equal("69");
        });
        it("can override functions", async function () {
          await expectRevert(
            this.contract.propose(ZERO_ADDRESS, 0, "0x", 0),
            "This function is overriden!"
          );
        });
      });
    });
  });
});
