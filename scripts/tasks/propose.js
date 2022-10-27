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
    if (!types[taskArgs.type]) throw Error("type should be one of defined");
    console.log("Tx sent...");
    id = await read(
      "Portal",
      "getIdFromName",
      taskArgs.name,
      types[taskArgs.type]
    );
    await execute(
      "Portal",
      { from: deployer, log: true },
      "newProposal",
      taskArgs.controller,
      types[taskArgs.type],
      web3.utils.asciiToHex(taskArgs.name),
      7 * 24 * 60 * 60 - 1
    );
    console.log(`new ${taskArgs.type} proposal: ${id}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
