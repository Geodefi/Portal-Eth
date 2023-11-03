const { strToBytes } = require("../../utils");

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
      InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
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
    strToBytes("v1_0")
  );
};

module.exports = func;
module.exports.tags = ["Portal"];
module.exports.dependencies = [
  "GeodeModuleLib",
  "StakeModuleLib",
  "InitiatorExtensionLib",
  "OracleExtensionLib",
  "gETH",
];
