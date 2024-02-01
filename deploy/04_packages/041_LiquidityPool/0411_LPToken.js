const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("LPToken WILL NOT BE DEPLOYED");
  // await deploy("LPToken", {
  //   from: deployer,
  //   log: true,
  //   skipIfAlreadyDeployed: true,
  // });
};

module.exports = func;
module.exports.tags = ["LPToken"];
