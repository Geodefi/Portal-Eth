const { BN, expectRevert } = require("@openzeppelin/test-helpers");

const LPToken = artifacts.require("$LPToken");
const { shouldBehaveLikeERC20 } = require("../utils/ERC20.behavior");

contract("LPToken", function (accounts) {
  const [deployer, recipient, anotherAccount] = accounts;
  const name = "Test Token";
  const symbol = "TEST";
  const initialSupply = new BN(String(1e18)).muln(100);

  let factory;

  const deployWithProxy = async function () {
    const contract = await upgrades.deployProxy(factory, [name, symbol], {
      unsafeAllow: ["state-variable-assignment"],
    });
    await contract.deployed();
    return await LPToken.at(contract.address);
  };

  before(async function () {
    factory = await ethers.getContractFactory("$LPToken");
    this.deployWithProxy = deployWithProxy;
  });

  beforeEach(async function () {
    this.token = await this.deployWithProxy();
    await this.token.mint(deployer, initialSupply);
  });

  shouldBehaveLikeERC20("ERC20", initialSupply, deployer, recipient, anotherAccount);

  describe("mint", function () {
    it("cannot mint 0", async function () {
      await expectRevert(
        this.token.mint(deployer, 0, { from: deployer }),
        "LPToken: cannot mint 0"
      );
    });
  });

  describe("_beforeTokenTransfer", function () {
    it("cannot send to itself", async function () {
      await expectRevert(
        this.token.$_beforeTokenTransfer(deployer, this.token.address, 1),
        "LPToken: cannot send to itself"
      );
    });
  });
});
