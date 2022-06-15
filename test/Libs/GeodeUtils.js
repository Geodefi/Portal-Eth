const { BigNumber, Signer, constants, Bytes } = require("ethers");

const {
  MAX_UINT256,
  ZERO_ADDRESS,
  DEAD_ADDRESS,
  getCurrentBlockTimestamp,
  setNextTimestamp,
  setTimestamp,
} = require("../testUtils");

const { solidity } = require("ethereum-waffle");
const { deployments } = require("hardhat");
const web3 = require("web3");
w3 = new web3(
  "https://eth-mainnet.alchemyapi.io/v2/RWIJcoIxj8EVIfhoDC-Vz5o5t_SmsbZP"
);

const chai = require("chai");

chai.use(solidity);
const { expect } = chai;

describe("GeodeUtils", async () => {
  var testContract;
  var GOVERNANCE;
  var SENATE;
  var userType4;
  var userType5;
  var creationTime;
  const _OPERATION_FEE = 10;
  const _MAX_OPERATION_FEE = 100;
  const AWEEK = 7 * 24 * 60 * 60;

  const setupTest = deployments.createFixture(async ({ ethers }) => {
    const { get, read } = deployments;
    signers = await ethers.getSigners();
    GOVERNANCE = signers[0];
    SENATE = signers[1];
    userType4 = signers[2]; // representative
    userType5 = signers[3]; // not representative

    await deployments.fixture(); // ensure you start from a fresh deployments
    creationTime = await getCurrentBlockTimestamp();
    const TestGeodeUtils = await ethers.getContractFactory("TestGeodeUtils", {
      libraries: {
        DataStoreUtils: (await get("DataStoreUtils")).address,
        GeodeUtils: (await get("GeodeUtils")).address,
      },
    });
    testContract = await TestGeodeUtils.deploy(
      GOVERNANCE.address,
      SENATE.address,
      _OPERATION_FEE,
      _MAX_OPERATION_FEE
    );
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("After Creation TX", () => {
    it("correct GOVERNANCE", async () => {
      response = await testContract.getGovernance();
      await expect(response).to.eq(GOVERNANCE.address);
    });
    it("correct SENATE", async () => {
      response = await testContract.getSenate();
      await expect(response).to.eq(SENATE.address);
    });
    it("correct SENATE_EXPIRE_TIMESTAMP", async () => {
      creationTime = await getCurrentBlockTimestamp();
      response = await testContract.getSenateExpireTimestamp();
      await expect(response).to.eq(creationTime + 24 * 3600);
    });
    it("correct OPERATION_FEE", async () => {
      response = await testContract.getOperationFee();
      await expect(response).to.eq(_OPERATION_FEE);
    });
    it("correct MAX_OPERATION_FEE", async () => {
      response = await testContract.getMaxOperationFee();
      await expect(response).to.eq(_MAX_OPERATION_FEE);
    });
    it("correct FEE_DENOMINATOR", async () => {
      response = await testContract.getFeeDenominator();
      await expect(response).to.eq(10 ** 10);
    });
    describe(" approvedUpgrade = false", async () => {
      it("with ZERO_ADDRESS", async () => {
        response = await testContract.isUpgradeAllowed(ZERO_ADDRESS);
        await expect(response).to.eq(false);
      });
      it("with any address", async () => {
        address = w3.eth.accounts.create();
        response = await testContract.isUpgradeAllowed(address.address);
        await expect(response).to.eq(false);
      });
    });
  });

  describe("Set Operation Fee", () => {
    it("reverts if > MAX", async () => {
      const futureOpFee = 101;
      response = await testContract.getOperationFee();
      await expect(
        testContract.connect(GOVERNANCE).setOperationFee(futureOpFee)
      ).to.be.revertedWith("GeodeUtils: fee more than MAX");
    });

    it("success if <= MAX", async () => {
      const futureOpFee = 9;
      await testContract.connect(GOVERNANCE).setOperationFee(futureOpFee);
      response = await testContract.getOperationFee();
      await expect(response).to.eq(futureOpFee);

      const futureMaxOpFee = 29;
      await testContract.connect(SENATE).setMaxOperationFee(futureMaxOpFee);
      await testContract.connect(GOVERNANCE).setOperationFee(futureMaxOpFee);
      response = await testContract.getOperationFee();
      await expect(response).to.eq(futureMaxOpFee);
    });
    it("returns MAX, if MAX is decreased", async () => {
      const futureOpFee = 20;
      const futureMaxOpFee = 15;
      await testContract.connect(GOVERNANCE).setOperationFee(futureOpFee);
      await testContract.connect(SENATE).setMaxOperationFee(futureMaxOpFee);
      response = await testContract.getOperationFee();
      await expect(response).to.eq(futureMaxOpFee);
    });
  });

  describe("getIdFromName", () => {
    describe("returns keccak(abi.encodePacked())", async () => {
      it("empty", async () => {
        id = await testContract.getIdFromName("");
        await expect(
          "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
        ).to.eq(id);
      });
      it("RANDOM", async () => {
        expected = web3.utils.keccak256("43725bvtgfsyudqv6tr23");
        id = await testContract.getIdFromName("43725bvtgfsyudqv6tr23");
        await expect(expected).to.eq(id);
      });
    });
    describe("matches with", async () => {
      it("getProposal", async () => {
        nameHex = web3.utils.asciiToHex("69");
        id = await testContract.getIdFromName("69");
        await testContract.newProposal(ZERO_ADDRESS, 1, 100000, nameHex);
        const proposal = await testContract.getProposal(id);
        await expect(web3.utils.keccak256(proposal.name)).to.eq(id);
      });
    });
  });

  describe("getCONTROLLERFromId", async () => {
    it("returns 0 when id not proposed", async () => {
      id = await testContract.getIdFromName("doesn't exist");
      const controller = await testContract.getCONTROLLERFromId(id);
      await expect(controller).to.eq(ZERO_ADDRESS);
    });
    it("returns 0 when id not approved", async () => {
      nameHex = web3.utils.asciiToHex("999");
      const controllerAddress = w3.eth.accounts.create().address;
      await testContract.newProposal(controllerAddress, 4, 100000, nameHex);
      id = await testContract.getIdFromName(nameHex);
      const controller = await testContract.getCONTROLLERFromId(id);
      await expect(controller).to.eq(ZERO_ADDRESS);
    });
    it("returns correct Address", async () => {
      nameHex = web3.utils.asciiToHex("999");
      const controllerAddress = w3.eth.accounts.create().address;
      await testContract.newProposal(controllerAddress, 4, 100000, nameHex);
      id = await testContract.getIdFromName("999");
      await testContract.connect(SENATE).approveProposal(id);
      const controller = await testContract.getCONTROLLERFromId(id);
      await expect(controller).to.eq(controllerAddress);
    });
  });

  describe("CONTROLLER", () => {
    let id, newcontrollerAddress;

    beforeEach(async () => {
      nameHex = web3.utils.asciiToHex("999");
      controllerAddress = w3.eth.accounts.create().address;
      await testContract.newProposal(userType4.address, 4412, 100000, nameHex);
      id = await testContract.getIdFromName("999");
      await testContract.connect(SENATE).approveProposal(id);
      newcontrollerAddress = w3.eth.accounts.create().address;
    });

    describe("reverts if caller is not CONTROLLER", async () => {
      it("by GOVERNANCE", async () => {
        await expect(
          testContract
            .connect(GOVERNANCE)
            .changeIdCONTROLLER(id, newcontrollerAddress)
        ).to.be.revertedWith("GeodeUtils: not CONTROLLER of given id");
      });
      it("by SENATE", async () => {
        await expect(
          testContract
            .connect(SENATE)
            .changeIdCONTROLLER(id, newcontrollerAddress)
        ).to.be.revertedWith("GeodeUtils: not CONTROLLER of given id");
      });
      it("by anyone with any address", async () => {
        await expect(
          testContract
            .connect(userType5)
            .changeIdCONTROLLER(id, newcontrollerAddress)
        ).to.be.revertedWith("GeodeUtils: not CONTROLLER of given id");
      });
      it("by anyone with ZERO_ADDRESS", async () => {
        await expect(
          testContract.connect(userType5).changeIdCONTROLLER(id, ZERO_ADDRESS)
        ).to.be.revertedWith("GeodeUtils: CONTROLLER can not be zero");
      });
    });
    describe("if caller is CONTROLLER", async () => {
      it("succeeds with newAddress", async () => {
        await testContract
          .connect(userType4)
          .changeIdCONTROLLER(id, newcontrollerAddress);
        controller = await testContract.getCONTROLLERFromId(id);
        await expect(controller).to.eq(newcontrollerAddress);
      });
      it("succeeds with DEAD_ADDRESS", async () => {
        await testContract
          .connect(userType4)
          .changeIdCONTROLLER(id, DEAD_ADDRESS);
        controller = await testContract.getCONTROLLERFromId(id);
        await expect(controller).to.eq(DEAD_ADDRESS);
      });
      it("reverts with ZERO_ADDRESS", async () => {
        await expect(
          testContract.connect(userType4).changeIdCONTROLLER(id, ZERO_ADDRESS)
        ).to.be.revertedWith("GeodeUtils: CONTROLLER can not be zero");
      });
    });
  });

  //TODO: MIN_DURATION CHECK

  describe("newProposal", () => {
    describe("any type", async () => {
      it("new proposal reverts when proposal duration is more then max duration", async () => {
        const controller = w3.eth.accounts.create();
        await expect(
          testContract.newProposal(
            controller.address,
            5,
            AWEEK + 1, // 1 weeks
            web3.utils.asciiToHex("myLovelyPlanet")
          )
        ).to.be.revertedWith("GeodeUtils: duration exceeds");
      });
      it("new proposal reverts when proposal has the same name with a currently active proposal", async () => {
        const controller = w3.eth.accounts.create();
        await testContract.newProposal(
          controller.address,
          5,
          AWEEK - 1, // 1 weeks - 1 seconds
          web3.utils.asciiToHex("myLovelyPlanet")
        );
        await expect(
          testContract.newProposal(
            controller.address,
            4,
            AWEEK - 1, // 1 weeks - 1 seconds
            web3.utils.asciiToHex("myLovelyPlanet")
          )
        ).to.be.revertedWith("GeodeUtils: name already proposed");
      });
      it("new proposal reverts when proposal has the same name with a Approved proposal", async () => {
        const controller = w3.eth.accounts.create();
        await testContract.newProposal(
          controller.address,
          5,
          AWEEK - 1, // 1 weeks - 1 seconds
          web3.utils.asciiToHex("myLovelyPlanet")
        );
        const id = await testContract.getIdFromName("myLovelyPlanet");
        await testContract.connect(SENATE).approveProposal(id);
        await expect(
          testContract.newProposal(
            controller.address,
            4,
            AWEEK - 1, // 1 weeks - 1 seconds
            web3.utils.asciiToHex("myLovelyPlanet")
          )
        ).to.be.revertedWith("GeodeUtils: name already claimed");
      });
      it("controller, type, deadline and name should be setted correctly in new proposal", async () => {
        const controller = w3.eth.accounts.create();
        await testContract.newProposal(
          controller.address,
          5,
          AWEEK - 1, // 1 weeks - 1 seconds
          web3.utils.asciiToHex("myLovelyPlanet")
        );
        const blockTimestamp = await getCurrentBlockTimestamp();
        const id = await testContract.getIdFromName("myLovelyPlanet");
        const proposal = await testContract.getProposal(id);
        expect(proposal.CONTROLLER).to.eq(controller.address);
        expect(proposal.TYPE).to.eq(5);
        expect(proposal.deadline).to.eq(AWEEK - 1 + blockTimestamp);
        expect(proposal.name).to.eq(web3.utils.asciiToHex("myLovelyPlanet"));
      });
    });
  });

  describe("Upgradability Changes according to type", async () => {
    let name, id, Upgrade;
    beforeEach(async () => {
      name = web3.utils.asciiToHex("RANDOM");
      id = await testContract.getIdFromName("RANDOM");
      Upgrade = w3.eth.accounts.create();
    });
    describe("type 2 : Upgrade ", async () => {
      it("isUpgradeAllowed", async () => {
        await testContract.newProposal(Upgrade.address, 2, 100000, name);
        await testContract.connect(SENATE).approveProposal(id);
        var response = await testContract.isUpgradeAllowed(Upgrade.address);
        await expect(response).to.eq(true);
      });
    });
    describe("type NOT 2", async () => {
      it("NOT isUpgradeAllowed", async () => {
        await testContract.newProposal(Upgrade.address, 4, 100000, name);
        await testContract.connect(SENATE).approveProposal(id);
        var response = await testContract.isUpgradeAllowed(Upgrade.address);
        await expect(response).to.eq(false);
      });
    });
  });

  describe("Senate Election", () => {
    const names = [
      "MyLovelyPlanet1",
      "MyLovelyPlanet2",
      "MyLovelyPlanet3",
      "MyLovelyPlanet4",
      "MyPoorOperator",
      "MyNewSenate",
    ];
    const types = [5, 5, 5, 5, 4, 1];
    const ids = [];
    let controllers = [];
    beforeEach(async () => {
      let i;
      for (i = 0; i < 5; i++) {
        const controller = signers[i + 3];
        controllers.push(controller);
        await testContract.newProposal(
          controller.address,
          types[i],
          AWEEK - 1, // 1 weeks - 1 seconds
          web3.utils.asciiToHex(names[i])
        );
        const id = await testContract.getIdFromName(names[i]);
        ids.push(id);
        await testContract.connect(SENATE).approveProposal(id);
      }
      const controller = signers[i + 3];
      controllers.push(controller);
      await testContract.newProposal(
        controller.address,
        types[i],
        AWEEK - 1, // 1 weeks - 1 seconds
        web3.utils.asciiToHex(names[i])
      );
      const id = await testContract.getIdFromName(names[i]);
      ids.push(id);
    });

    it("approveSenate reverts when proposal expired", async () => {
      await setTimestamp((await getCurrentBlockTimestamp()) + AWEEK);
      await expect(
        testContract
          .connect(controllers[0])
          .approveSenate(ids[ids.length - 1], ids[0])
      ).to.be.revertedWith("GeodeUtils: proposal expired");
    });

    it("approveSenate reverts when trying yo approve with another representative/random address", async () => {
      await expect(
        testContract
          .connect(controllers[1])
          .approveSenate(ids[ids.length - 1], ids[0])
      ).to.be.revertedWith(
        "GeodeUtils: msg.sender should be CONTROLLER of given electorId!"
      );
    });
    it("approveSenate reverts when NOT Senate Proposal", async () => {
      await testContract.newProposal(
        userType4.address,
        5,
        AWEEK - 1, // 1 weeks - 1 seconds
        web3.utils.asciiToHex("myOtherLovelyPlanet")
      );
      const id = await testContract.getIdFromName("myOtherLovelyPlanet");
      await expect(
        testContract.connect(controllers[2]).approveSenate(id, ids[2])
      ).to.be.revertedWith("GeodeUtils: NOT Senate Proposal");
    });

    it("approveSenate reverts when NOT an elector", async () => {
      await expect(
        testContract
          .connect(controllers[4])
          .approveSenate(ids[ids.length - 1], ids[4])
      ).to.be.revertedWith("GeodeUtils: NOT an elector");
    });
    it("approveSenate reverts when already approved", async () => {
      await testContract
        .connect(controllers[3])
        .approveSenate(ids[ids.length - 1], ids[3]);
      await expect(
        testContract
          .connect(controllers[3])
          .approveSenate(ids[ids.length - 1], ids[3])
      ).to.be.revertedWith("GeodeUtils: already approved");
    });
    it("votes are successfull but not enough to change the Senate", async () => {
      await testContract
        .connect(controllers[0])
        .approveSenate(ids[ids.length - 1], ids[0]);
      await testContract
        .connect(controllers[1])
        .approveSenate(ids[ids.length - 1], ids[1]);

      senateAfterVotes = await testContract.getSenate();
      expect(senateAfterVotes).to.eq(SENATE.address);
    });
    it("votes are successfull & senate changes with 3/4 votes", async () => {
      await testContract
        .connect(controllers[0])
        .approveSenate(ids[ids.length - 1], ids[0]);
      await testContract
        .connect(controllers[1])
        .approveSenate(ids[ids.length - 1], ids[1]);
      await testContract
        .connect(controllers[2])
        .approveSenate(ids[ids.length - 1], ids[2]);
      senateAfterVotes = await testContract.getSenate();
      expect(senateAfterVotes).to.eq(
        controllers[controllers.length - 1].address
      );
      await expect(
        testContract
          .connect(controllers[3])
          .approveSenate(ids[ids.length - 1], ids[3])
      ).to.be.revertedWith("GeodeUtils: proposal expired");
    });
  });
});
