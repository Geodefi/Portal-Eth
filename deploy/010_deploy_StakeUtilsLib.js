const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("StakeUtils", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    libraries: {
      OracleUtils: (await get("OracleUtils")).address,
      MaintainerUtils: (await get("MaintainerUtils")).address,
    },
  });
};
module.exports = func;
module.exports.tags = ["StakeUtils"];
