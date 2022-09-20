const { upgrades } = require("hardhat");
const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { get, save } = deployments;
  const { deployer } = await getNamedAccounts();

  const gETH = (await get("gETH")).address;
  const Swap = (await get("Swap")).address;
  const ERC20InterfacePermitUpgradable = (
    await get("ERC20InterfacePermitUpgradable")
  ).address;
  const LPToken = (await get("LPToken")).address;
  const MiniGovernance = (await get("MiniGovernance")).address;

  // PARAMS
  const _GOVERNANCE_TAX = (1 * 10 ** 10) / 100; // 1%
  const _COMET_TAX = (3 * 10 ** 10) / 100; // 3%
  const _MAX_MAINTAINER_FEE = (15 * 10 ** 10) / 100; // 15%
  const _BOOSTRAP_PERIOD = 6 * 30 * 24 * 3600; // 6 Months

  const Portal = await ethers.getContractFactory("Portal", {
    libraries: {
      GeodeUtils: (await get("GeodeUtils")).address,
      StakeUtils: (await get("StakeUtils")).address,
      OracleUtils: (await get("OracleUtils")).address,
      MaintainerUtils: (await get("MaintainerUtils")).address,
    },
  });

  const proxy = await upgrades.deployProxy(
    Portal,
    [
      deployer,
      gETH,
      deployer,
      ERC20InterfacePermitUpgradable,
      Swap,
      LPToken,
      MiniGovernance,
      _GOVERNANCE_TAX,
      _COMET_TAX,
      _MAX_MAINTAINER_FEE,
      _BOOSTRAP_PERIOD,
    ],
    {
      kind: "uups",
      unsafeAllow: ["external-library-linking"],
    }
  );

  const artifact = await deployments.getExtendedArtifact("Portal");

  await save("Portal", {
    address: proxy.address,
    ...artifact,
  });
};

module.exports = func;
module.exports.tags = ["Portal"];
