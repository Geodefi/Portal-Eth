const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("InitiatorExtensionLib", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    libraries: {
      StakeModuleLib: (await get("StakeModuleLib")).address,
    },
  });
};

module.exports = func;
module.exports.tags = ["InitiatorExtensionLib"];
module.exports.dependencies = ["StakeModuleLib"];
