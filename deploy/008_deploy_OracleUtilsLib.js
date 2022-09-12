const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("OracleUtils", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
  });
};
module.exports = func;
module.exports.tags = ["OracleUtils"];
module.exports.dependencies = ["DataStore", "DepositContractUtils"];
