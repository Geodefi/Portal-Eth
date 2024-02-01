chai = require("chai");
const { expect } = chai;

ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
ZERO_BYTES32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

/** always working require detector  */
async function expectRevert(tx, error = null) {
  if (error) await expect(tx).to.be.revertedWith(error);
  else await expect(tx).to.be.reverted;
}

/** always working custom error detector  */
async function expectCustomError(tx, contract, error, args = null) {
  // supports old style contracts
  if (contract.constructor._hArtifact) {
    if (args)
      expect(tx.tx)
        .to.be.revertedWithCustomError(
          await ethers.getContractAt(
            contract.constructor._hArtifact.contractName,
            contract.address
          ),
          error
        )
        .withArgs(...args);
    else
      expect(tx.tx).to.be.revertedWithCustomError(
        await ethers.getContractAt(contract.constructor._hArtifact.contractName, contract.address),
        error
      );
  } else {
    if (args)
      expect(tx)
        .to.be.revertedWithCustomError(contract, error)
        .withArgs(...args);
    else expect(tx).to.be.revertedWithCustomError(contract, error);
  }
}

function isDict(v) {
  return typeof v === "object" && v !== null && !(v instanceof Array) && !(v instanceof Date);
}

/** always working event detector  */
async function expectEvent(tx, contract, event, args = null) {
  if (contract.constructor._hArtifact) {
    // supports (old style) contracts from artifact
    if (args) {
      // supports args given as a dict for now, although all that matters is the order of the values...
      if (isDict(args))
        args = Object.keys(args).map(function (key) {
          // supports (old openzeppelin/test-helpers), many of BN libs use words.
          if (args[key].words) return args[key].toString();
          else return args[key];
        });
      await expect(tx.tx)
        .to.emit(
          await ethers.getContractAt(
            contract.constructor._hArtifact.contractName,
            contract.address
          ),
          event
        )
        .withArgs(...args);
    } else {
      await expect(tx.tx).to.emit(
        await ethers.getContractAt(contract._hArtifact.contractName, contract.address),
        event
      );
    }
  } else if (args) {
    await expect(tx)
      .to.emit(contract, event)
      .withArgs(...args);
  } else {
    await expect(tx).to.emit(contract, event);
  }
}

/** deploy a contract as a proxt  */
const deployWithProxy = async function (name, params) {
  const contract = await upgrades.deployProxy(await ethers.getContractFactory(name), [...params], {
    unsafeAllow: ["state-variable-assignment"],
  });
  return await contract.waitForDeployment();
};

module.exports = {
  ZERO_ADDRESS,
  ZERO_BYTES32,
  expectRevert,
  expectCustomError,
  expectEvent,
  deployWithProxy,
};
