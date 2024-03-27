// const { ethers, deployments, upgrades } = require("hardhat");
const { delay } = require("../../utils");

const TYPE_PACKAGE_WITHDRAWAL = 10011;
const TYPE_PACKAGE_LIQUIDITY = 10021;
const MAX_PROPOSAL_DURATION = 2419200;
const DELAY_SECONDS = 100;

module.exports.upgradePackage = async function (hre, portal, version = "V1_0") {
  try {
    const { ethers, upgrades, deployments } = hre;
    const { get } = deployments;

    const oldWPFactory = await ethers.getContractFactory("WithdrawalPackage", {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        WithdrawalModuleLib: (await get("WithdrawalModuleLib")).address,
      },
    });

    const WPFactory = await ethers.getContractFactory("WithdrawalPackage" + version, {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        WithdrawalModuleLib: (await get("WithdrawalModuleLib")).address,
      },
    });

    const currentWP = await upgrades.forceImport(
      (
        await get("WithdrawalPackage")
      ).address,
      oldWPFactory,
      {
        kind: "uups",
        constructorArgs: [(await get("gETH")).address, portal.address],
      }
    );

    const newImplementationAddress = await upgrades.prepareUpgrade(currentWP, WPFactory, {
      redeployImplementation: "onchange",
      kind: "uups",
      unsafeAllow: ["external-library-linking", "state-variable-immutable"],
      constructorArgs: [(await get("gETH")).address, portal.address],
    });

    await delay(DELAY_SECONDS);

    const _name = web3.utils.asciiToHex(version);
    const _id = await portal.generateId(version, TYPE_PACKAGE_WITHDRAWAL);

    await portal.propose(
      newImplementationAddress,
      TYPE_PACKAGE_WITHDRAWAL,
      _name,
      MAX_PROPOSAL_DURATION
    );
    await delay(DELAY_SECONDS);

    await portal.approveProposal(_id);
    await delay(DELAY_SECONDS);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful upgrade...");
    console.log("try --network");
  }
};

module.exports.upgradeLiquidityPackage = async function (hre, portal, version = "V1_0") {
  try {
    const { ethers, upgrades, deployments } = hre;
    const { get } = deployments;

    const oldLPFactory = await ethers.getContractFactory("LiquidityPackage", {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        LiquidityModuleLib: (await get("LiquidityModuleLib")).address,
      },
    });

    const LPFactory = await ethers.getContractFactory("LiquidityPackage" + version, {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        LiquidityModuleLib: (await get("LiquidityModuleLib")).address,
      },
    });

    const currentLP = await upgrades.forceImport(
      (
        await get("LiquidityPackage")
      ).address,
      oldLPFactory,
      {
        kind: "uups",
        constructorArgs: [
          (await get("gETH")).address,
          portal.address,
          (await get("LPToken")).address,
        ],
      }
    );

    const newImplementationAddress = await upgrades.prepareUpgrade(currentLP, LPFactory, {
      redeployImplementation: "onchange",
      kind: "uups",
      unsafeAllow: ["external-library-linking", "state-variable-immutable"],
      constructorArgs: [
        (await get("gETH")).address,
        portal.address,
        (await get("LPToken")).address,
      ],
    });

    await delay(DELAY_SECONDS);

    const _name = web3.utils.asciiToHex(version);
    const _id = await portal.generateId(version, TYPE_PACKAGE_LIQUIDITY);

    await portal.propose(
      newImplementationAddress,
      TYPE_PACKAGE_LIQUIDITY,
      _name,
      MAX_PROPOSAL_DURATION
    );
    await delay(DELAY_SECONDS);

    await portal.approveProposal(_id);
    await delay(DELAY_SECONDS);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful upgrade...");
    console.log("try --network");
  }
};
