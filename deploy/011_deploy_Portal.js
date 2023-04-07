const { upgrades } = require("hardhat");

const func = async function (hre) {
  const { deployments, getNamedAccounts, Web3 } = hre;
  const { get, save } = deployments;
  const { deployer } = await getNamedAccounts();

  const getBytes = (key) => {
    return Web3.utils.toHex(key);
  };

  const gETH = (await get("gETH")).address;
  const Swap = (await get("Swap")).address;
  const ERC20InterfaceUpgradable = (await get("ERC20InterfaceUpgradable")).address;

  const ERC20InterfacePermitUpgradable = (await get("ERC20InterfacePermitUpgradable")).address;
  const LPToken = (await get("LPToken")).address;
  const WithdrawalContract = (await get("WithdrawalContract")).address;

  // PARAMS
  const _GOVERNANCE_FEE = (25 * 10 ** 10) / 1000; // 2.5%

  const Portal = await ethers.getContractFactory("Portal", {
    libraries: {
      GeodeUtils: (await get("GeodeUtils")).address,
      StakeUtils: (await get("StakeUtils")).address,
      OracleUtils: (await get("OracleUtils")).address,
    },
  });

  const proxy = await upgrades.deployProxy(
    Portal,
    [
      deployer,
      deployer,
      gETH,
      deployer,
      WithdrawalContract,
      Swap,
      LPToken,
      [ERC20InterfaceUpgradable, ERC20InterfacePermitUpgradable],
      [getBytes("ERC20"), getBytes("ERC20Permit")],
      _GOVERNANCE_FEE,
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
