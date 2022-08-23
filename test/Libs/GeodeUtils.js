const {
  ZERO_ADDRESS,
  DEAD_ADDRESS,
  getCurrentBlockTimestamp,
  setTimestamp,
} = require("../testUtils");
// const { Bytes } = require("ethers");
const { solidity } = require("ethereum-waffle");
const { deployments } = require("hardhat");

const chai = require("chai");

chai.use(solidity);
const { expect } = chai;

describe("GeodeUtils", async () => {
  let testContract;
  let GOVERNANCE;
  let SENATE;
  let userType4;
  let userType5;
  let creationTime;
  const _OPERATION_FEE = 10;
  const _MAX_OPERATION_FEE = 100;
  const AWEEK = 7 * 24 * 60 * 60;

  const setupTest = deployments.createFixture(async (hre) => {
    ({ ethers, Web3, Web3 } = hre);
    const { get } = deployments;
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
        address = web3.eth.accounts.create();
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

  describe("getId", () => {
    describe("returns keccak(abi.encodePacked())", async () => {
      it("empty", async () => {
        id = await testContract.getId("", 0);
        await expect(
          "18569430475105882587588266137607568536673111973893317399460219858819262702947"
        ).to.eq(id);
      });
      it("RANDOM", async () => {
        id = await testContract.getId("122ty", 4);
        await expect(
          "17317086281719416521524852924703645666897020696006237693650814844753480104575"
        ).to.eq(id);
      });
    });
    it("matches with getProposal", async () => {
      _name = "MyPlanetName";
      id = await testContract.getId(_name, 1);

      nameHex = Web3.utils.asciiToHex(_name);
      await testContract.newProposal(ZERO_ADDRESS, 1, nameHex, 100000);
      const proposal = await testContract.getProposal(id);

      await expect(Web3.utils.toAscii(proposal.NAME)).to.eq(_name);
    });
  });

  describe("getCONTROLLERFromId", async () => {
    it("returns 0 when id not proposed", async () => {
      id = await testContract.getId("doesn't exist", 5);
      const controller = await testContract.getCONTROLLERFromId(id);
      await expect(controller).to.eq(ZERO_ADDRESS);
    });
    it("returns 0 when id not approved", async () => {
      nameHex = Web3.utils.asciiToHex("999");
      const controllerAddress = web3.eth.accounts.create().address;
      await testContract.newProposal(controllerAddress, 4, nameHex, 100000);
      id = await testContract.getId(nameHex, 4);
      const controller = await testContract.getCONTROLLERFromId(id);
      await expect(controller).to.eq(ZERO_ADDRESS);
    });
    it("returns correct Address", async () => {
      nameHex = Web3.utils.asciiToHex("999");
      const controllerAddress = web3.eth.accounts.create().address;
      await testContract.newProposal(controllerAddress, 4, nameHex, 100000);
      id = await testContract.getId("999", 4);
      await testContract.connect(SENATE).approveProposal(id);
      const controller = await testContract.getCONTROLLERFromId(id);
      await expect(controller).to.eq(controllerAddress);
    });
  });

  describe("CONTROLLER", () => {
    let id, newcontrollerAddress;

    beforeEach(async () => {
      nameHex = Web3.utils.asciiToHex("999");
      controllerAddress = web3.eth.accounts.create().address;
      await testContract.newProposal(userType4.address, 4412, nameHex, 100000);
      id = await testContract.getId("999", 4412);
      await testContract.connect(SENATE).approveProposal(id);
      newcontrollerAddress = web3.eth.accounts.create().address;
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

  describe("newProposal", () => {
    describe("any type", async () => {
      it("new proposal reverts when proposal duration is more then max duration", async () => {
        const controller = web3.eth.accounts.create();
        await expect(
          testContract.newProposal(
            controller.address,
            5,
            Web3.utils.asciiToHex("myLovelyPlanet"),
            AWEEK + 1 // 1 weeks
          )
        ).to.be.revertedWith("GeodeUtils: duration exceeds");
      });
      it("new proposal reverts when proposal has the same name with a currently active proposal", async () => {
        const controller = web3.eth.accounts.create();
        await testContract.newProposal(
          controller.address,
          5,
          Web3.utils.asciiToHex("myLovelyPlanet"),
          AWEEK - 1 // 1 weeks - 1 seconds
        );
        await expect(
          testContract.newProposal(
            controller.address,
            5,
            Web3.utils.asciiToHex("myLovelyPlanet"),
            AWEEK - 1 // 1 weeks - 1 seconds
          )
        ).to.be.revertedWith("GeodeUtils: NAME already proposed");
      });
      it("new proposal reverts when proposal has the same name with a Approved proposal", async () => {
        const controller = web3.eth.accounts.create();
        await testContract.newProposal(
          controller.address,
          5,
          Web3.utils.asciiToHex("myLovelyPlanet"),
          AWEEK - 1 // 1 weeks - 1 seconds
        );
        const id = await testContract.getId("myLovelyPlanet", 5);
        await testContract.connect(SENATE).approveProposal(id);
        await expect(
          testContract.newProposal(
            controller.address,
            5,
            Web3.utils.asciiToHex("myLovelyPlanet"),
            AWEEK - 1 // 1 weeks - 1 seconds
          )
        ).to.be.revertedWith("GeodeUtils: NAME already claimed");
      });
      it("controller, type, deadline and name should be set correctly in new proposal", async () => {
        const controller = web3.eth.accounts.create();
        await testContract.newProposal(
          controller.address,
          5,
          Web3.utils.asciiToHex("myLovelyPlanet"),
          AWEEK - 1 // 1 weeks - 1 seconds
        );
        const blockTimestamp = await getCurrentBlockTimestamp();
        const id = await testContract.getId("myLovelyPlanet", 5);
        const proposal = await testContract.getProposal(id);
        expect(proposal.CONTROLLER).to.eq(controller.address);
        expect(proposal.TYPE).to.eq(5);
        expect(proposal.NAME).to.eq(Web3.utils.asciiToHex("myLovelyPlanet"));
        expect(proposal.deadline).to.eq(AWEEK - 1 + blockTimestamp);
      });
    });
  });

  describe("Upgradability Changes according to type", async () => {
    let name, id, Upgrade;
    beforeEach(async () => {
      name = Web3.utils.asciiToHex("RANDOM");
      id = await testContract.getId("RANDOM", 2);
      wrongId = await testContract.getId("RANDOM", 420);
      Upgrade = web3.eth.accounts.create();
    });
    describe("type 2 : Upgrade ", async () => {
      it("isUpgradeAllowed", async () => {
        await testContract.newProposal(Upgrade.address, 2, name, 100000);
        await testContract.connect(SENATE).approveProposal(id);
        const response = await testContract.isUpgradeAllowed(Upgrade.address);
        await expect(response).to.eq(true);
      });
    });
    describe("type NOT 2", async () => {
      it("NOT isUpgradeAllowed", async () => {
        await testContract.newProposal(Upgrade.address, 420, name, 100000);
        await testContract.connect(SENATE).approveProposal(wrongId);
        const response = await testContract.isUpgradeAllowed(Upgrade.address);
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
    // eslint-disable-next-line prefer-const
    let controllers = [];
    const types = [5, 5, 5, 5, 4, 1];
    const ids = [];
    beforeEach(async () => {
      let i;
      for (i = 0; i < 5; i++) {
        const controller = signers[i + 3];
        controllers.push(controller);
        await testContract.newProposal(
          controller.address,
          types[i],
          Web3.utils.asciiToHex(names[i]),
          AWEEK - 1 // 1 weeks - 1 seconds
        );
        const id = await testContract.getId(names[i], types[i]);
        ids.push(id);
        await testContract.connect(SENATE).approveProposal(id);
      }
      const controller = signers[i + 3];
      controllers.push(controller);
      await testContract.newProposal(
        controller.address,
        types[i],
        Web3.utils.asciiToHex(names[i]),
        AWEEK - 1 // 1 weeks - 1 seconds
      );
      const id = await testContract.getId(names[i], types[i]);
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
        Web3.utils.asciiToHex("myOtherLovelyPlanet"),
        AWEEK - 1 // 1 weeks - 1 seconds
      );
      const id = await testContract.getId("myOtherLovelyPlanet", 5);
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
    it("votes are successfull & senate changes more than 2/3 votes", async () => {
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

  describe("Set Senate", () => {
    it("Sets senate without checking anything, for micro governance in withdrawal credentials contract use", async () => {
      const beforeTimestamp = await getCurrentBlockTimestamp();
      await testContract.setSenate(userType4.address, 6969);
      const afterTimestamp = await getCurrentBlockTimestamp();
      afterSenate = await testContract.getSenate();
      expect(afterSenate).to.eq(userType4.address);
      afterSenateExpireTimestamp =
        await testContract.getSenateExpireTimestamp();
      expect(afterSenateExpireTimestamp).to.gte(beforeTimestamp + 6969);
      expect(afterSenateExpireTimestamp).to.lte(afterTimestamp + 6969);
    });
  });
});
