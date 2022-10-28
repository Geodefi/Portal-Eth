const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute } = deployments;
  try {
    id = taskArgs.id;
    console.log("Tx sent...");

    await execute(
      "Portal",
      { from: deployer, log: true },
      "approveProposal",
      id
    );
    console.log(`created: ${id}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
