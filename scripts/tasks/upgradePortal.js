const web3 = require("web3");
const { strToBytes, generateId } = require("../../test/utils");

function delay(time) {
  return new Promise((resolve) => setTimeout(resolve, time));
}

const func = async (taskArgs, hre) => {
  /**
   * First do:
   * npx hardhat clean
   * npx hardhat compile
   * npx hardhat upgradePortal  --network """"""
   */
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { get, read, deploy } = deployments;
  DAY = 24 * 60 * 60;
  PORTAL_PACKAGE_TYPE = 10001;
  try {
    testPortal = await ethers.getContractAt("Portal", (await get("Portal")).address);
    prevContractVersion = await read("Portal", "getContractVersion");
    console.log(prevContractVersion);
    // ensure you start from a fresh deployment for library deployments
    // put them here if needed
    console.log("GeodeModuleLib:", (await get("GeodeModuleLib")).address);
    console.log("StakeModuleLib:", (await get("StakeModuleLib")).address);
    console.log("OracleExtensionLib:", (await get("OracleExtensionLib")).address);
    // await deploy("StakeUtils", {
    //   from: deployer,
    //   log: true,
    //   libraries: {
    //     DataStoreUtils: (await get("DataStoreUtils")).address,
    //   },
    // });
    // await deploy("GeodeUtils", {
    //   from: deployer,
    //   log: true,
    //   libraries: {
    //     DataStoreUtils: (await get("DataStoreUtils")).address,
    //   },
    // });
    // console.log("deployed the needed libraries:");
    // console.log("DataStoreUtils:", (await get("DataStoreUtils")).address);
    // console.log("GeodeUtils:", (await get("GeodeUtils")).address);
    // console.log("StakeUtils:", (await get("StakeUtils")).address);

    const PortalFactory = await ethers.getContractFactory("Portal", {
      libraries: {
        GeodeModuleLib: (await get("GeodeModuleLib")).address,
        StakeModuleLib: (await get("StakeModuleLib")).address,
        OracleExtensionLib: (await get("OracleExtensionLib")).address,
      },
    });
    const testPortalV2 = await PortalFactory.deploy();
    await delay(5000);

    console.log("deployed the implementation", testPortalV2.address);
    _name = strToBytes("v1.2");
    _id = (await generateId(_name, PORTAL_PACKAGE_TYPE)).toString();
    console.log(_name, _id);
    await testPortal.propose(testPortalV2.address, PORTAL_PACKAGE_TYPE, _name, DAY);
    await delay(6000);
    await testPortal.approveProposal(_id);
    await delay(6000);
    console.log("UPGRADED.");

    // testPortal = await ethers.getContractAt("Portal", testPortal.address);
    // console.log(
    //   "Portal upgraded to: ",
    //   testPortalV2.address,
    //   "version: ",
    //   (await testPortal.getContractVersion()).toString()
    // );
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful deployment...");
    console.log("try --network");
  }
};

module.exports = func;
