const { strToBytes } = require("../../test/utils");

const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("Portal", {
    from: deployer,
    log: true,
    libraries: {
      GeodeModuleLib: (await get("GeodeModuleLib")).address,
      StakeModuleLib: (await get("StakeModuleLib")).address,
      OracleExtensionLib: (await get("OracleExtensionLib")).address,
    },
    proxy: {
      proxyContract: "UUPS",
    },
  });

  await execute(
    "Portal",
    { from: deployer, log: true },
    "initialize",
    deployer,
    deployer,
    (
      await get("gETH")
    ).address,
    deployer,
    strToBytes("v1.0")
  );
};

module.exports = func;
module.exports.tags = ["Portal"];
module.exports.dependencies = ["GeodeModuleLib", "StakeModuleLib", "OracleExtensionLib", "gETH"];
