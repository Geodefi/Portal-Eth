const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("GeodeUtils", {
    from: deployer,
    log: true,
    libraries: {
      DataStoreUtils: (await get("DataStoreUtils")).address,
    },
    skipIfAlreadyDeployed: true,
  });
};
module.exports = func;
module.exports.tags = ["GeodeUtils"];
