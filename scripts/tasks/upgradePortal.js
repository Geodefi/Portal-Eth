const web3 = require("web3");
const TYPE_PACKAGE_PORTAL = 10001;
const MAX_PROPOSAL_DURATION = 2419200;
const DELAY_SECONDS = 10000;
const version = "V1.2";
function delay(time = DELAY_SECONDS) {
  return new Promise((resolve) => setTimeout(resolve, time));
}
// @DEV NOT GOOD ENOUGH FOR PROD!!!
const func = async (taskArgs, { ethers }) => {
  /**
   * First do:
   npx hardhat clean
   npx hardhat compile
   npx hardhat upgradePortal  --network """"""
   */
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { get, read, deploy } = deployments;
  try {
    testPortal = await ethers.getContractAt("Portal", (await get("Portal")).address);
    const prevContractVersion = await read("Portal", "getContractVersion");

    // ensure you start from a fresh deployment for library deployments
    // put them here if needed
    console.log("StakeModuleLib:", (await get("StakeModuleLib")).address);

    await deploy("StakeModuleLib", {
      from: deployer,
      log: true,
      //   libraries: {
      //     DataStoreUtils: (await get("DataStoreUtils")).address,
      //   },
    });
    console.log("deployed the needed libraries:");
    console.log("StakeModuleLib:", (await get("StakeModuleLib")).address);

    const PortalFactory = await ethers.getContractFactory("Portal", {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        InitiatorExtensionLib: (await get("InitiatorExtensionLib")).address,
        OracleExtensionLib: (await get("OracleExtensionLib")).address,
        StakeModuleLib: (await get("StakeModuleLib")).address,
      },
    });
    const testPortalV2 = await PortalFactory.deploy();
    await delay(5000);
    const newImplementationAddress = testPortalV2.target;
    console.log("deployed the implementation:", newImplementationAddress);
    const currentPortal = await ethers.getContractAt("Portal", (await get("Portal")).address);
    const _name = web3.utils.asciiToHex(version);
    const _id = await currentPortal.generateId(version, TYPE_PACKAGE_PORTAL);
    await currentPortal.propose(
      newImplementationAddress,
      TYPE_PACKAGE_PORTAL,
      _name,
      MAX_PROPOSAL_DURATION
    );

    await delay();
    await currentPortal.approveProposal(_id);
    await delay();

    console.log("approved the upgrade to " + version);

    const upgradedPortal = await ethers.getContractAt("Portal", currentPortal.target);
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

module.exports = func;
