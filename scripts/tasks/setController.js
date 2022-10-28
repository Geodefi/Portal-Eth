const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute } = deployments;
  try {
    console.log("Tx sent...");
    await execute(
      "Portal",
      { from: deployer, log: true },
      "changeIdCONTROLLER",
      taskArgs.id,
      taskArgs.c
    );
    console.log(`sucessfully changed CONTROLLER for: ${taskArgs.id}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
