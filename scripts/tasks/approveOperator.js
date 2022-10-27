const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute } = deployments;
  try {
    console.log("Tx sent...");

    await execute(
      "Portal",
      { from: deployer, log: true },
      "approveOperator",
      taskArgs.pid,
      taskArgs.oid,
      taskArgs.allowance
    );
    console.log(`approved: ${taskArgs.pid} for  ${taskArgs.allowance}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
