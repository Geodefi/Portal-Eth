const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("gETH", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    args: ["Geode Staked Ether", "gETH", "https://api.geode.fi/geth"],
  });
};

module.exports = func;
module.exports.tags = ["gETH"];
