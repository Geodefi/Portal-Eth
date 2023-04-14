/* eslint-disable */
const { solidity } = require("ethereum-waffle");
const { constants, expectRevert, time } = require("@openzeppelin/test-helpers");
const { MAX_UINT256 } = constants;

const chai = require("chai");
chai.use(solidity);
const { expect } = require("chai");

const { fromRpcSig } = require("ethereumjs-util");
const ethSigUtil = require("eth-sig-util");
const Wallet = require("ethereumjs-wallet").default;

const EIP712Domain = [
  { name: "name", type: "string" },
  { name: "version", type: "string" },
  { name: "chainId", type: "uint256" },
  { name: "verifyingContract", type: "address" },
];

const Permit = [
  { name: "owner", type: "address" },
  { name: "spender", type: "address" },
  { name: "value", type: "uint256" },
  { name: "nonce", type: "uint256" },
  { name: "deadline", type: "uint256" },
];

async function domainSeparator(name, version, chainId, verifyingContract) {
  return (
    "0x" +
    ethSigUtil.TypedDataUtils.hashStruct(
      "EIP712Domain",
      { name, version, chainId, verifyingContract },
      { EIP712Domain }
    ).toString("hex")
  );
}

describe("ERC20Permit", function (accounts) {
  let initialHolder;
  let spender;
  let token;
  let chainId;
  let tokenContract;

  const symbol = "gETH";
  const name = "Token Geode Staked Ether";
  const version = "1";
  const unknownTokenId = "6969";

  const setupTest = deployments.createFixture(async (hre) => {
    ({ ethers, web3, Web3 } = hre);

    const signers = await ethers.getSigners();
    initialHolder = minter = signers[0].address;
    spender = signers[1].address;

    const gETH = await ethers.getContractFactory("gETH");
    tokenContract = await gETH.deploy("initialURI");

    ERC20InterfaceFac = await ethers.getContractFactory(
      "ERC20InterfacePermitUpgradable"
    );

    const getBytes32 = (x) => {
      return ethers.utils.hexZeroPad(ethers.utils.hexlify(x), 32);
    };

    const getBytes = (key) => {
      return Web3.utils.toHex(key);
    };
    const nameBytes = getBytes(name).substr(2);
    const symbolBytes = getBytes(symbol).substr(2);
    const interfaceData =
      getBytes32(nameBytes.length / 2) + nameBytes + symbolBytes;

    ERC20Interface = await upgrades.deployProxy(ERC20InterfaceFac, [
      unknownTokenId,
      tokenContract.address,
      interfaceData,
    ]);
    await ERC20Interface.deployed();

    token = ERC20Interface;
    chainId = await web3.eth.getChainId();
  });

  beforeEach(async function () {
    await setupTest();
  });

  it("initial nonce is 0", async function () {
    expect(await token.nonces(initialHolder)).to.be.eq("0");
  });

  it("domain separator", async function () {
    expect(await token.DOMAIN_SEPARATOR()).to.equal(
      await domainSeparator(name, version, chainId, token.address)
    );
  });

  describe("permit", function () {
    const wallet = Wallet.generate();
    const owner = wallet.getAddressString();
    const value = 42;
    const nonce = 0;
    const maxDeadline = MAX_UINT256.toString();

    const buildData = (chainId, verifyingContract, deadline = maxDeadline) => ({
      primaryType: "Permit",
      types: { EIP712Domain, Permit },
      domain: { name, version, chainId, verifyingContract },
      message: { owner, spender, value, nonce, deadline },
    });

    it("accepts owner signature", async function () {
      const data = buildData(chainId, token.address);
      const signature = ethSigUtil.signTypedMessage(wallet.getPrivateKey(), {
        data,
      });
      const { v, r, s } = fromRpcSig(signature);
      const receipt = await token.permit(
        owner,
        spender,
        value,
        maxDeadline,
        v,
        r,
        s
      );

      expect(await token.nonces(owner)).to.be.eq(1);
      expect(await token.allowance(owner, spender)).to.be.eq(value);
    });

    it("rejects reused signature", async function () {
      const data = buildData(chainId, token.address);
      const signature = ethSigUtil.signTypedMessage(wallet.getPrivateKey(), {
        data,
      });
      const { v, r, s } = fromRpcSig(signature);
      await token.permit(owner, spender, value, maxDeadline, v, r, s);

      await expectRevert(
        token.permit(owner, spender, value, maxDeadline, v, r, s),
        "ERC20Permit: invalid signature"
      );
    });

    it("rejects other signature", async function () {
      const otherWallet = Wallet.generate();
      const data = buildData(chainId, token.address);
      const signature = ethSigUtil.signTypedMessage(
        otherWallet.getPrivateKey(),
        { data }
      );
      const { v, r, s } = fromRpcSig(signature);

      await expectRevert(
        token.permit(owner, spender, value, maxDeadline, v, r, s),
        "ERC20Permit: invalid signature"
      );
    });

    it("rejects expired permit", async function () {
      const deadline = (await time.latest()) - time.duration.weeks(1);
      const data = buildData(chainId, token.address, deadline);
      const signature = ethSigUtil.signTypedMessage(wallet.getPrivateKey(), {
        data,
      });
      const { v, r, s } = fromRpcSig(signature);

      await expectRevert(
        token.permit(owner, spender, value, deadline, v, r, s),
        "ERC20Permit: expired deadline"
      );
    });
  });
});
