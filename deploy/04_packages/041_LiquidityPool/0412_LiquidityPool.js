const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("LiquidityPackage Package WILL NOT BE DEPLOYED");
  // await deploy("LiquidityPackage", {
  //   from: deployer,
  //   log: true,
  //   skipIfAlreadyDeployed: true,
  //   libraries: {
  //     GeodeModuleLib: (await get("GeodeModuleLib")).address,
  //     LiquidityModuleLib: (await get("LiquidityModuleLib")).address,
  //   },
  //   args: [
  //     (await get("gETH")).address,
  //     (await get("Portal")).address,
  //     (await get("LPToken")).address,
  //   ],
  // });
};

module.exports = func;
module.exports.tags = ["LiquidityPackage"];
module.exports.dependencies = ["GeodeModuleLib", "LiquidityModuleLib", "gETH", "Portal", "LPToken"];
