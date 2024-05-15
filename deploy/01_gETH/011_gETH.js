const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("gETH", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    args: ["Geodefi Staked Ether", "gETH", "https://api.geode.fi/geth"],
  });
};

// TODO : on mainnet DEFAULT_ADMIN_ROLE should be either revoked or transferred to a multisig etc.

module.exports = func;
module.exports.tags = ["gETH"];
