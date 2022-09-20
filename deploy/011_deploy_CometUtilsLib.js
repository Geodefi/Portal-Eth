const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("CometUtils", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    libraries: {
      OracleUtils: (await get("OracleUtils")).address,
      MaintainerUtils: (await get("MaintainerUtils")).address,
      StakeUtils: (await get("StakeUtils")).address,
    },
  });
};
module.exports = func;
module.exports.tags = ["CometUtils"];
module.exports.dependencies = ["OracleUtils", "MaintainerUtils", "StakeUtils"];
