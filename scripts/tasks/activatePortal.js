const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute, get } = deployments;
  try {
    console.log("Tx sent...");
    await execute(
      "gETH",
      { from: deployer, log: true },
      "updateMinterRole",
      (
        await get("Portal")
      ).address
    );
    await execute(
      "gETH",
      { from: deployer, log: true },
      "updatePauserRole",
      (
        await get("Portal")
      ).address
    );
    await execute(
      "gETH",
      { from: deployer, log: true },
      "updateOracleRole",
      (
        await get("Portal")
      ).address
    );
    console.log("Portal is now gETH minter");
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
