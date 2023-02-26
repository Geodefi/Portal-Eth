const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, getOrNull, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const lpToken = await getOrNull("LPToken");
  if (lpToken) {
    log(`reusing "LPToken" at ${lpToken.address}`);
  } else {
    await deploy("LPToken", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    });
  }
};

module.exports = func;
module.exports.tags = ["LPToken"];
