const BN = require("bignumber.js");
const Web3 = require("web3");
const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute, read } = deployments;
  try {
    const id = (
      await read("Portal", "generateId", taskArgs.name, 5)
    ).toString();

    console.log("Tx sent...");
    await execute(
      "Portal",
      { from: deployer, log: true },
      "initiatePlanet",
      id,
      BN(Math.floor((taskArgs.f * 10 ** 10) / 100)).toString(),
      taskArgs.m,
      Web3.utils.fromAscii(taskArgs.name),
      taskArgs.n,
      taskArgs.s
    );
    console.log(`initiated: ${id}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
