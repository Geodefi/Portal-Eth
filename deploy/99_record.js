const fs = require("fs");
const keccak256 = require("keccak256");
const { table } = require("table");

const func = async function (hre) {
  try {
    const { deployments } = hre;
    const { all } = deployments;

    const allContracts = await all();

    const data = Object.keys(allContracts).map((k) => ({
      Contract: k,
      Address: allContracts[k].address,
      Proof: keccak256(allContracts[k].deployedBytecode).toString("hex"),
    }));

    console.table(data);

    const chainId = await web3.eth.getChainId();
    const releaseData = data.map(({ Contract, Address, Proof }) => [Contract, Address, Proof]);
    const releaseId = keccak256(data.map(({ Proof }) => [Proof]).join()).toString("hex");

    fs.writeFileSync(
      `./releases/${chainId}/${releaseId}.txt`,
      table([["Contract", "Address", "Proof"]].concat(releaseData)),
      "utf8"
    );
    console.log("Recorded the new release");
  } catch (error) {
    console.log(error);
    console.log("Could not record the release.");
  }
};

module.exports = func;
module.exports.tags = ["saveDeployment"];
