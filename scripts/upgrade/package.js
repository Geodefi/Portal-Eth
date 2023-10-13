// const { ethers, deployments, upgrades } = require("hardhat");
const { delay } = require("../../utils");

const TYPE_PACKAGE_WITHDRAWAL_CONTRACT = 10011;
const MAX_PROPOSAL_DURATION = 2419200;
const DELAY_SECONDS = 100;

module.exports.upgradePackage = async function (hre, portal, poolWC, version = "V1_0") {
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
      unsafeAllow: ["external-library-linking", "state-variable-immutable"], // TODO: check/remove state-variable-immutable
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

    await delay(DELAY_SECONDS);

    const upgradedWithdrawalContract = await ethers.getContractAt(
      "WithdrawalContract" + version,
      currentWC.target
    );

    return upgradedWithdrawalContract;
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful upgrade...");
    console.log("try --network");
  }
};
