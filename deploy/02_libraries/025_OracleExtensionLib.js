const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("OracleExtensionLib", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    libraries: {
      StakeModuleLib: (await get("StakeModuleLib")).address,
    },
  });
};

module.exports = func;
module.exports.tags = ["OracleExtensionLib"];
module.exports.dependencies = ["StakeModuleLib"];
