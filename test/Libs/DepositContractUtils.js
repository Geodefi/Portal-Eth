const { deployments } = require("hardhat");
const { solidity } = require("ethereum-waffle");

const chai = require("chai");
chai.use(solidity);
const { expect } = chai;

describe("DepositContractUtils", async () => {
  let testContract;

  const setupTest = deployments.createFixture(async (hre) => {
    ({ ethers, web3, Web3 } = hre);

    await deployments.fixture(); // ensure you start from a fresh deployments
    const TestDepositContractUtils = await ethers.getContractFactory(
      "DepositContractUtilsTest"
    );
    testContract = await TestDepositContractUtils.deploy();
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("DepositContractUtils", () => {
    it("getDepositContract to get the address", async () => {
      const response = await testContract.getDepositContract();
      expect(response).to.eq("0x00000000219ab540356cBB839Cbe05303d7705Fa");
    });

    it("addressToWC to get 0x01 instead of 0x00 as beginning", async () => {
      const WCAddress = ethers.Wallet.createRandom().address;
      const response = await testContract.addressToWC(WCAddress);
      const withdrawalCredential =
        "0x01" + "0000000000000000000000" + WCAddress.substring(2);
      expect(response).to.eq(withdrawalCredential.toLowerCase());
    });

    describe("getDepositDataRoot from pubkey, withdrawalCredentials, signature and stakeAmount", async () => {
      const pubkey =
        "0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a";
      const withdrawalCredentials =
        "0x004f58172d06b6d54c015d688511ad5656450933aff85dac123cd09410a0825c";
      const signature =
        "0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181";
      const depositDataRoot =
        "0xcf73f30d1a20e2af0446c2630acc4392f888dc0532a09592e00faf90b2976ab8";

      it("reverts when stakeAmount less than 1 ether", async () => {
        const stakeAmount = 2e9;
        await expect(
          testContract.getDepositDataRoot(
            pubkey,
            withdrawalCredentials,
            signature,
            stakeAmount
          )
        ).to.be.revertedWith("DepositContract: deposit value too low");
      });

      it("reverts when stakeAmount is not multiple of gwei", async () => {
        const stakeAmount = ethers.BigNumber.from(String(1e18)).add(
          ethers.BigNumber.from(String(1))
        );
        await expect(
          testContract.getDepositDataRoot(
            pubkey,
            withdrawalCredentials,
            signature,
            stakeAmount
          )
        ).to.be.revertedWith(
          "DepositContract: deposit value not multiple of gwei"
        );
      });

      it("calculates depositDataRoot correctly with stakeAmount 32 ether", async () => {
        const stakeAmount = ethers.BigNumber.from(String(32e18));
        const response = await testContract.getDepositDataRoot(
          pubkey,
          withdrawalCredentials,
          signature,
          stakeAmount
        );
        expect(response).to.eq(depositDataRoot);
      });
    });

    it("to show it is possible to get any const internal variable with example of PUBKEY_LENGTH", async () => {
      const response = await testContract.getPubkeyLength();
      expect(response).to.eq(48);
    });
  });
});
