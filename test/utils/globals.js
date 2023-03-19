const { deployments } = require("hardhat");
const { solidity } = require("ethereum-waffle");

const chai = require("chai");
chai.use(solidity);
const { expect } = chai;

describe("geodeGlobals", async () => {
  let testContract;

  const setupTest = deployments.createFixture(async (hre) => {
    ({ ethers, web3, Web3 } = hre);
    const signers = await ethers.getSigners();
    user1 = signers[1];

    await deployments.fixture(); // ensure you start from a fresh deployments
    const TestGlobals = await ethers.getContractFactory("TestGlobals");
    testContract = await TestGlobals.deploy();
  });
  beforeEach(async () => {
    await setupTest();
  });

  it("PERCENTAGE_DENOMINATOR", async () => {
    const response = await testContract.getPERCENTAGE_DENOMINATOR();
    expect(response).to.eq(10 ** 10);
  });

  describe("geodeTypes", async () => {
    it("NONE", async () => {
      const response = await testContract.getTypeNONE();
      expect(response).to.eq(0);
    });
    it("SENATE", async () => {
      const response = await testContract.getTypeSENATE();
      expect(response).to.eq(1);
    });
    it("CONTRACT_UPGRADE", async () => {
      const response = await testContract.getTypeCONTRACT_UPGRADE();
      expect(response).to.eq(2);
    });
    it("__GAP__", async () => {
      const response = await testContract.getTypeGAP();
      expect(response).to.eq(3);
    });
    it("OPERATOR", async () => {
      const response = await testContract.getTypeOPERATOR();
      expect(response).to.eq(4);
    });
    it("POOL", async () => {
      const response = await testContract.getTypePOOL();
      expect(response).to.eq(5);
    });
    it("getTypeLIMIT_DEFAULT_MODULE_MIN", async () => {
      const response = await testContract.getTypeLIMIT_DEFAULT_MODULE_MIN();
      expect(response).to.eq(10000);
    });
    it("getTypeLIMIT_DEFAULT_MODULE_MAX", async () => {
      const response = await testContract.getTypeLIMIT_DEFAULT_MODULE_MAX();
      expect(response).to.eq(19999);
    });
    it("getTypeLIMIT_ALLOWED_MODULE_MIN", async () => {
      const response = await testContract.getTypeLIMIT_ALLOWED_MODULE_MIN();
      expect(response).to.eq(20000);
    });
    it("getTypeLIMIT_ALLOWED_MODULE_MAX", async () => {
      const response = await testContract.getTypeLIMIT_ALLOWED_MODULE_MAX();
      expect(response).to.eq(29999);
    });
    it("MODULE_WITHDRAWAL_CONTRACT", async () => {
      const response = await testContract.getTypeMODULE_WITHDRAWAL_CONTRACT();
      expect(response).to.eq(10011);
    });
    it("MODULE_GETH_INTERFACE", async () => {
      const response = await testContract.getTypeMODULE_GETH_INTERFACE();
      expect(response).to.eq(20031);
    });
    it("MODULE_LIQUDITY_POOL", async () => {
      const response = await testContract.getTypeMODULE_LIQUDITY_POOL();
      expect(response).to.eq(10021);
    });
    it("MODULE_LIQUDITY_POOL_TOKEN", async () => {
      const response = await testContract.getTypeMODULE_LIQUDITY_POOL_TOKEN();
      expect(response).to.eq(10022);
    });
  });
  describe("validatorStates", async () => {
    it("NONE", async () => {
      const response = await testContract.getStateNONE();
      expect(response).to.eq(0);
    });
    it("PROPOSED", async () => {
      const response = await testContract.getStatePROPOSED();
      expect(response).to.eq(1);
    });
    it("ACTIVE", async () => {
      const response = await testContract.getStateACTIVE();
      expect(response).to.eq(2);
    });
    it("EXITED", async () => {
      const response = await testContract.getStateEXITED();
      expect(response).to.eq(3);
    });
    it("ALIENATED", async () => {
      const response = await testContract.getStateALIENATED();
      expect(response).to.eq(69);
    });
  });
});
