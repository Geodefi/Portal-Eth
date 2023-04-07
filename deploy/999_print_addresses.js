const func = async function (hre) {
  const { deployments } = hre;
  const { all } = deployments;

  const allContracts = await all();

  console.table(Object.keys(allContracts).map((k) => [k, allContracts[k].address]));
};
// todo: save to a file.
module.exports = func;
module.exports.tags = ["PrintAdresses"];
