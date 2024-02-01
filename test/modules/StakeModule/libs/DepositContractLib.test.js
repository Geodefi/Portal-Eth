const { expect } = require("chai");
const { expectRevert, BN } = require("@openzeppelin/test-helpers");
const { generateAddress } = require("../../../../utils");

const DepositContractLib = artifacts.require("$DepositContractLib");

contract("DepositContractLib", function () {
  beforeEach(async function () {
    this.contract = await DepositContractLib.new();
  });

  it("correct DEPOSIT_CONTRACT by chain", async function () {
    const response = await this.contract.$DEPOSIT_CONTRACT();
    const chainId = await web3.eth.getChainId();

    const depositContract =
      chainId === 31337
        ? "0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b"
        : chainId === 1
        ? "0x00000000219ab540356cBB839Cbe05303d7705Fa"
        : chainId === 17000
        ? "0x4242424242424242424242424242424242424242"
        : 0;

    expect(response).to.be.equal(depositContract);
  });

  it("addressToWC to get 0x01 instead of 0x00 prefix", async function () {
    const WCAddress = generateAddress();
    const response = await this.contract.$addressToWC(WCAddress);
    const withdrawalCredential = "0x01" + "0000000000000000000000" + WCAddress.substring(2);
    expect(response).to.be.equal(withdrawalCredential.toLowerCase());
  });

  describe("getDepositDataRoot from pubkey, withdrawalCredentials, signature and stakeAmount", async function () {
    const pubkey =
      "0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a";
    const withdrawalCredentials =
      "0x004f58172d06b6d54c015d688511ad5656450933aff85dac123cd09410a0825c";
    const signature =
      "0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181";
    const depositDataRoot = "0xcf73f30d1a20e2af0446c2630acc4392f888dc0532a09592e00faf90b2976ab8";

    it("reverts when stakeAmount less than 1 ether", async function () {
      const stakeAmount = String(99e16);
      await expectRevert(
        this.contract.$_getDepositDataRoot(pubkey, withdrawalCredentials, signature, stakeAmount),
        "DepositContract: deposit value too low"
      );
    });

    it("reverts when stakeAmount is not multiple of gwei", async function () {
      const stakeAmount = new BN(String(1e18)).addn(1);
      await expectRevert(
        this.contract.$_getDepositDataRoot(pubkey, withdrawalCredentials, signature, stakeAmount),
        "DepositContract: deposit value not multiple of gwei"
      );
    });

    it("calculates depositDataRoot correctly with stakeAmount 32 ether", async function () {
      const stakeAmount = String(32e18);
      const response = await this.contract.$_getDepositDataRoot(
        pubkey,
        withdrawalCredentials,
        signature,
        stakeAmount
      );
      expect(response).to.be.equal(depositDataRoot);
    });
  });
});
