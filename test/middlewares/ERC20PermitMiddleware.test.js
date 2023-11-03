const { expect } = require("chai");
const { constants, expectRevert, time, BN } = require("@openzeppelin/test-helpers");
const { MAX_UINT256 } = constants;
const { silenceWarnings } = require("@openzeppelin/upgrades-core");

const { strToBytes, intToBytes32 } = require("../../utils");

const ERC20PermitMiddleware = artifacts.require("$ERC20PermitMiddleware");
const gETH = artifacts.require("gETH");

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

function bufferToHexString(buffer) {
  return "0x" + buffer.toString("hex");
}

async function domainSeparator({ name, version, chainId, verifyingContract }) {
  return bufferToHexString(
    ethSigUtil.TypedDataUtils.hashStruct(
      "EIP712Domain",
      { name, version, chainId, verifyingContract },
      { EIP712Domain }
    )
  );
}
contract("ERC20PermitMiddleware", function (accounts) {
  const [initialHolder, spender] = accounts;

  const name = "eth";
  const symbol = "tsETH";
  const version = "1";

  const tokenId = new BN(420);
  const initialSupply = new BN(String(1e18)).muln(100);

  let factory;
  let middlewareData;

  const deployErc20PermitWithProxy = async function () {
    const contract = await upgrades.deployProxy(
      factory,
      [tokenId.toString(), this.gETH.address, middlewareData],
      {
        unsafeAllow: ["state-variable-assignment"],
      }
    );
    await contract.waitForDeployment();
    return await ERC20PermitMiddleware.at(contract.target);
  };

  before(async function () {
    await silenceWarnings();

    factory = await ethers.getContractFactory("$ERC20PermitMiddleware");

    const nameBytes = strToBytes(name).substr(2);
    const symbolBytes = strToBytes(symbol).substr(2);
    middlewareData = intToBytes32(nameBytes.length / 2) + nameBytes + symbolBytes;

    this.deployErc20PermitWithProxy = deployErc20PermitWithProxy;
    this.chainId = await web3.eth.getChainId();
  });

  beforeEach(async function () {
    this.gETH = await gETH.new("name", "symbol", "uri", { from: initialHolder });
    await this.gETH.mint(initialHolder, tokenId, initialSupply, "0x", { from: initialHolder });

    this.token = await this.deployErc20PermitWithProxy();
    await this.gETH.setMiddleware(this.token.address, tokenId, true);
  });

  describe("initialize", function () {
    it("correct gETH address", async function () {
      expect(await this.token.ERC1155()).to.be.equal(this.gETH.address);
    });
    it("correct token id", async function () {
      expect(await this.token.ERC1155_ID()).to.be.bignumber.equal(tokenId);
    });
    it("correct name", async function () {
      expect(await this.token.name()).to.be.equal(name);
    });
    it("correct symbol", async function () {
      expect(await this.token.symbol()).to.be.equal(symbol);
    });
  });

  it("initial nonce is 0", async function () {
    expect(await this.token.nonces(initialHolder)).to.be.bignumber.equal("0");
  });

  it("domain separator", async function () {
    expect(await this.token.DOMAIN_SEPARATOR()).to.equal(
      await domainSeparator({
        name,
        version,
        chainId: this.chainId,
        verifyingContract: this.token.address,
      })
    );
  });

  describe("permit", function () {
    const wallet = Wallet.generate();

    const owner = wallet.getAddressString();
    const value = new BN(42);
    const nonce = 0;
    const maxDeadline = MAX_UINT256;

    const buildData = (chainId, verifyingContract, deadline = maxDeadline) => ({
      primaryType: "Permit",
      types: { EIP712Domain, Permit },
      domain: { name, version, chainId, verifyingContract },
      message: { owner, spender, value, nonce, deadline },
    });

    it("accepts owner signature", async function () {
      const data = buildData(this.chainId, this.token.address);
      const signature = ethSigUtil.signTypedMessage(wallet.getPrivateKey(), { data });
      const { v, r, s } = fromRpcSig(signature);

      await this.token.permit(owner, spender, value, maxDeadline, v, r, s);

      expect(await this.token.nonces(owner)).to.be.bignumber.equal("1");
      expect(await this.token.allowance(owner, spender)).to.be.bignumber.equal(value);
    });

    it("rejects reused signature", async function () {
      const data = buildData(this.chainId, this.token.address);
      const signature = ethSigUtil.signTypedMessage(wallet.getPrivateKey(), { data });
      const { v, r, s } = fromRpcSig(signature);

      await this.token.permit(owner, spender, value, maxDeadline, v, r, s);

      await expectRevert(
        this.token.permit(owner, spender, value, maxDeadline, v, r, s),
        "ERC20Permit: invalid signature"
      );
    });

    it("rejects other signature", async function () {
      const otherWallet = Wallet.generate();
      const data = buildData(this.chainId, this.token.address);
      const signature = ethSigUtil.signTypedMessage(otherWallet.getPrivateKey(), { data });
      const { v, r, s } = fromRpcSig(signature);

      await expectRevert(
        this.token.permit(owner, spender, value, maxDeadline, v, r, s),
        "ERC20Permit: invalid signature"
      );
    });

    it("rejects expired permit", async function () {
      const deadline = (await time.latest()) - time.duration.weeks(1);

      const data = buildData(this.chainId, this.token.address, deadline);
      const signature = ethSigUtil.signTypedMessage(wallet.getPrivateKey(), { data });
      const { v, r, s } = fromRpcSig(signature);

      await expectRevert(
        this.token.permit(owner, spender, value, deadline, v, r, s),
        "ERC20Permit: expired deadline"
      );
    });
  });
});
