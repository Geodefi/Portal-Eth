const { BN, expectRevert } = require("@openzeppelin/test-helpers");

const LPToken = artifacts.require("$LPToken");
const { shouldBehaveLikeERC20 } = require("../../utils/ERC20.behavior");

contract("LPToken", function (accounts) {
  const [deployer, recipient, anotherAccount] = accounts;
  const name = "Test Token";
  const symbol = "TEST";
  const initialSupply = new BN(100);

  beforeEach(async function () {
    this.token = await LPToken.new({ from: deployer });
    this.token.initialize(name, symbol);
    await this.token.mint(deployer, initialSupply);
  });

  shouldBehaveLikeERC20("ERC20", initialSupply, deployer, recipient, anotherAccount);

  describe("mint", function () {
    it("cannot mint 0", async function () {
      expectRevert(
        await this.token.mint(recipient, initialSupply, { from: deployer }),
        "LPToken: cannot mint 0"
      );
    });
  });

  describe("_beforeTokenTransfer", function () {
    it("cannot send to itself", async function () {
      expectRevert(
        await this.token.$_beforeTokenTransfer(recipient, anotherAccount, initialSupply),
        "LPToken: cannot send to itself"
      );
    });
  });
});
