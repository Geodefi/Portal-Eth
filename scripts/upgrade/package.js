// const { ethers, deployments, upgrades } = require("hardhat");
const { delay } = require("../../utils");

const TYPE_PACKAGE_WITHDRAWAL_CONTRACT = 10011;
const TYPE_LIQUIDITY_POOL_CONTRACT = 10021;
const MAX_PROPOSAL_DURATION = 2419200;
const DELAY_SECONDS = 100;

module.exports.upgradePackage = async function (hre, portal, version = "V1_0") {
  try {
    const { ethers, upgrades, deployments } = hre;
    const { get } = deployments;

    const oldWCFactory = await ethers.getContractFactory("WithdrawalContract", {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        WithdrawalModuleLib: (await get("WithdrawalModuleLib")).address,
      },
    });

    const WCFactory = await ethers.getContractFactory("WithdrawalContract" + version, {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        WithdrawalModuleLib: (await get("WithdrawalModuleLib")).address,
      },
    });

    const currentWC = await upgrades.forceImport(
      (
        await get("WithdrawalContract")
      ).address,
      oldWCFactory,
      {
        kind: "uups",
        constructorArgs: [(await get("gETH")).address, portal.address],
      }
    );

    const newImplementationAddress = await upgrades.prepareUpgrade(currentWC, WCFactory, {
      redeployImplementation: "onchange",
      kind: "uups",
      unsafeAllow: ["external-library-linking", "state-variable-immutable"],
      constructorArgs: [(await get("gETH")).address, portal.address],
    });

    await delay(DELAY_SECONDS);

    const _name = web3.utils.asciiToHex(version);
    const _id = await portal.generateId(version, TYPE_PACKAGE_WITHDRAWAL_CONTRACT);

    await portal.propose(
      newImplementationAddress,
      TYPE_PACKAGE_WITHDRAWAL_CONTRACT,
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

module.exports.upgradeLPPackage = async function (hre, portal, version = "V1_0") {
  try {
    const { ethers, upgrades, deployments } = hre;
    const { get } = deployments;

    const oldLPFactory = await ethers.getContractFactory("LiquidityPool", {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        LiquidityModuleLib: (await get("LiquidityModuleLib")).address,
      },
    });

    const LPFactory = await ethers.getContractFactory("LiquidityPool" + version, {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        LiquidityModuleLib: (await get("LiquidityModuleLib")).address,
      },
    });

    const currentLP = await upgrades.forceImport(
      (
        await get("LiquidityPool")
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
    const _id = await portal.generateId(version, TYPE_LIQUIDITY_POOL_CONTRACT);

    await portal.propose(
      newImplementationAddress,
      TYPE_LIQUIDITY_POOL_CONTRACT,
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
