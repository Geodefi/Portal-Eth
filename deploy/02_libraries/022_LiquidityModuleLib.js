const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("LiquidityModuleLib WILL NOT BE DEPLOYED");
  // await deploy("LiquidityModuleLib", {
  //   from: deployer,
  //   log: true,
  //   skipIfAlreadyDeployed: true,
  // });
};

module.exports = func;
module.exports.tags = ["LiquidityModuleLib"];
