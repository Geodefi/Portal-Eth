const web3 = require("web3");
const func = async (taskArgs, hre) => {
  types = {
    senate: 1,
    upgrade: 2,
    operator: 4,
    planet: 5,
  };
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute, read } = deployments;
  try {
    if (!types[taskArgs.t]) throw Error("type should be one of defined");
    console.log("Tx sent...");
    id = await read("Portal", "generateId", taskArgs.n, types[taskArgs.t]);
    await execute(
      "Portal",
      { from: deployer, log: true },
      "newProposal",
      taskArgs.c,
      types[taskArgs.t],
      web3.utils.asciiToHex(taskArgs.n),
      7 * 24 * 60 * 60 - 1
    );
    console.log(`new ${taskArgs.t} proposal: ${id}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
