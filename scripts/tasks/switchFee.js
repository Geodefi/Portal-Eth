const BN = require("bignumber.js");
const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute } = deployments;
  try {
    console.log("Tx sent...");
    await execute(
      "Portal",
      { from: deployer, log: true },
      "switchMaintainerFee",
      taskArgs.id,
      BN(Math.floor((taskArgs.f * 10 ** 10) / 100)).toString()
    );
    console.log(`sucessfully set fee for: ${taskArgs.id}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
