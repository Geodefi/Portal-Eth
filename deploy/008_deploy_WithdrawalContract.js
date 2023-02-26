const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("WithdrawalContract", {
    from: deployer,
    log: true,
    libraries: {
      GeodeUtils: (await get("GeodeUtils")).address,
    },
    skipIfAlreadyDeployed: true,
  });
};
module.exports = func;
module.exports.tags = ["WithdrawalContract"];
