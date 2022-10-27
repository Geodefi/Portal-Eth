const web3 = require("web3");
const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute } = deployments;
  try {
    console.log("Tx sent...");
    await execute(
      "Portal",
      { from: deployer, log: true },
      "changePoolMaintainer",
      taskArgs.id,
      web3.utils.asciiToHex(""),
      web3.utils.padRight(web3.utils.asciiToHex(""), 64),
      taskArgs.m
    );
    console.log(`changed Maintainer for: ${taskArgs.id}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
