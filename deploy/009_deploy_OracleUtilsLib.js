const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("OracleUtils", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    libraries: {
      StakeUtils: (await get("StakeUtils")).address,
    },
  });
};
module.exports = func;
module.exports.tags = ["OracleUtils"];
module.exports.dependencies = ["StakeUtils"];
