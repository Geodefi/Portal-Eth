const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("Swap", {
    from: deployer,
    log: true,
    libraries: {
      SwapUtils: (await get("SwapUtils")).address,
      AmplificationUtils: (await get("AmplificationUtils")).address,
    },
    skipIfAlreadyDeployed: true,
  });
};
module.exports = func;
module.exports.tags = ["Swap"];
module.exports.dependencies = ["AmplificationUtils", "SwapUtils"];
