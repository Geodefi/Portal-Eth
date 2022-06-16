const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("gETH", {
    from: deployer,
    log: true,
    args: ["https://api.geode.fi/geth"],
    skipIfAlreadyDeployed: true,
  });
};

module.exports = func;
module.exports.tags = ["gETH"];
