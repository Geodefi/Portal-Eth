const func = async (taskArgs, hre) => {
  signers = await ethers.getSigners();
  deployer = signers[0];
  const { deployments } = hre;
  const { read } = deployments;
  try {
    console.log("Tx sent...");
    WPadd = await read("Portal", "planetWithdrawalPool", taskArgs.id);
    if (WPadd == "0x0000000000000000000000000000000000000000")
      throw Error("Couldn't find the WP: ZERO_ADDRESS");
    WithPool = await ethers.getContractAt("Swap", WPadd);
    const block = await ethers.provider.getBlock("latest");
    await WithPool.connect(deployer).rampA(
      taskArgs.a,
      block.timestamp + 14 * 24 * 60 * 60 + 100
    );
    console.log(`sucessfully change the A`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
