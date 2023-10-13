const { ethers, deployments, upgrades } = require("hardhat");
const { delay } = require("../../utils");

module.exports.upgradePackage = async function (version = "V1_0") {
  try {
    const { get, read } = deployments;
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful upgrade...");
    console.log("try --network");
  }
};
