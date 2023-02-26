const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute } = deployments;
  try {
    console.log("Tx sent...");

    const opIds = taskArgs.oids.split(",");
    const allowances = taskArgs.as.split(",");

    if (opIds.length === 0) {
      console.log(`no operators here...`);
      return;
    }
    if (opIds.length !== allowances.length) {
      console.log(`operatorIds and amounts doesn't match`);
      return;
    }

    await execute(
      "Portal",
      { from: deployer, log: true },
      "approveOperators",
      taskArgs.pid,
      opIds,
      allowances
    );
    for (let i = 0; i < opIds.length; i++) {
      console.log(
        `${taskArgs.pid} approved: ${opIds[i]} for ${allowances[i]} validators.`
      );
    }
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

// done

module.exports = func;
