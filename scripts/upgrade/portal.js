// const { ethers, upgrades } = require("hardhat");
const { delay } = require("../../utils");

const TYPE_PACKAGE_PORTAL = 10001;
const MAX_PROPOSAL_DURATION = 2419200;
const DELAY_SECONDS = 100;

/**
 * @dev Use this script: When ONLY the Portal.sol contract is mutated.
 */
module.exports.upgradePortal = async function (hre, version = "V1_0") {
  try {
    const { ethers, upgrades, deployments } = hre;
    const { get, read } = deployments;
    const prevContractVersion = await read("Portal", "getContractVersion");

    // deploy implementation
    const oldPortalFactory = await ethers.getContractFactory("Portal", {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        StakeModuleLib: (await get("StakeModuleLib")).address,
        InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
        OracleExtensionLib: (await get("OracleExtensionLib")).address,
      },
    });
    const PortalFactory = await ethers.getContractFactory("Portal" + version, {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        StakeModuleLib: (await get("StakeModuleLib")).address,
        InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
        OracleExtensionLib: (await get("OracleExtensionLib")).address,
      },
    });

    // const currentPortal = await ethers.getContractAt("Portal", (await get("Portal")).address);

    const currentPortal = await upgrades.forceImport(
      (
        await get("Portal")
      ).address,
      oldPortalFactory,
      { kind: "uups" }
    );

    const newImplementationAddress = await upgrades.prepareUpgrade(currentPortal, PortalFactory, {
      redeployImplementation: "onchange",
      kind: "uups",
      unsafeAllow: ["external-library-linking"],
    });

    console.log("deployed the implementation", newImplementationAddress);
    await delay(DELAY_SECONDS);

    const _name = web3.utils.asciiToHex(version);
    const _id = await currentPortal.generateId(version, TYPE_PACKAGE_PORTAL);

    await currentPortal.propose(
      newImplementationAddress,
      TYPE_PACKAGE_PORTAL,
      _name,
      MAX_PROPOSAL_DURATION
    );
    await delay(DELAY_SECONDS);

    await currentPortal.approveProposal(_id);
    await delay(DELAY_SECONDS);

    console.log("approved the upgrade to " + version);

    const upgradedPortal = await ethers.getContractAt("Portal" + version, currentPortal.target);
    const curContractVersion = (await upgradedPortal.getContractVersion()).toString();

    console.log(
      "Portal upgraded to: " + newImplementationAddress,
      "\nold version: " + prevContractVersion,
      "\nnew version: " + curContractVersion
    );
    return upgradedPortal;
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful upgrade...");
    console.log("try --network");
  }
};
