const fs = require("fs");
const keccak256 = require("keccak256");
const { table } = require("table");

const func = async function (hre) {
  try {
    const { deployments } = hre;
    const { all } = deployments;

    const allContracts = await all();

    const data = Object.keys(allContracts).map((k) => [
      k,
      allContracts[k].address,
      keccak256(allContracts[k].deployedBytecode).toString("hex"),
    ]);

    console.table(data);

    const chainId = await web3.eth.getChainId();
    const releaseId = Object.keys(allContracts).reduce(
      (h, k) => keccak256(h, allContracts[k].deployedBytecode).toString("hex"),
      ""
    );

    const columns = [["Contract", "Address", "Proof"]];
    fs.writeFileSync(`./releases/${chainId}/${releaseId}.txt`, table(columns.concat(data)), "utf8");
  } catch (error) {
    console.log(error);
    console.log("Could not record the release.");
  }
};

module.exports = func;
module.exports.tags = ["saveDeployment"];
