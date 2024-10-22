const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("WithdrawalPackage", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    libraries: {
      GeodeModuleLib: (await get("GeodeModuleLib")).address,
      WithdrawalModuleLib: (await get("WithdrawalModuleLib")).address,
    },
    args: [(await get("gETH")).address, (await get("Portal")).address],
  });
};

module.exports = func;
module.exports.tags = ["WithdrawalPackage"];
module.exports.dependencies = ["GeodeModuleLib", "WithdrawalModuleLib", "gETH", "Portal"];
