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
      "setSlippage",
      taskArgs.s
    );
    console.log(`sucessfully change the slippage`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
