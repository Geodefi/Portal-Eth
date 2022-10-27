const func = async (taskArgs, hre) => {
  const { ELECTOR } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute, read } = deployments;
  try {
    console.log("Tx sent...");
    await execute(
      "Portal",
      { from: ELECTOR, log: true },
      "approveSenate",
      taskArgs.sid,
      taskArgs.pid
    );
    stt = await read("Portal", "getProposal", taskArgs.sid);
    console.log(stt);
    console.log(`sucessfully voted for: ${taskArgs.sid}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
