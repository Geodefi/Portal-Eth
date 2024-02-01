const func = async (taskArgs, { ethers }) => {
  const erc1967slot = (label) => ethers.toBeHex(ethers.toBigInt(ethers.id(label)) - 1n);
  const erc7201slot = (label) =>
    ethers.toBeHex(ethers.toBigInt(ethers.keccak256(erc1967slot(label))) & ~0xffn);
  try {
    console.log(erc7201slot(taskArgs.label));
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
  }
};
// done
module.exports = func;
