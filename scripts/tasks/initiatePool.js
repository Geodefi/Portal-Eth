const BN = require("bignumber.js");
const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments, ethers, Web3 } = hre;
  const { execute, read } = deployments;

  const getBytes = (key) => {
    return Web3.utils.toHex(key);
  };
  const intToBytes32 = (x) => {
    return ethers.utils.hexZeroPad(ethers.utils.hexlify(x), 32);
  };

  const interfaces = ["ERC20", "ERC20Permit"];
  const visibilities = { public: true, private: false };

  let deployInterface = false;
  let interfaceVersion = 0;
  let interfaceData = "0x";

  if (taskArgs.i) {
    if (!interfaces.includes(taskArgs.i)) {
      console.log("Unknown interface: ", interfaces);
      return;
    }
    if (!(taskArgs.tn && taskArgs.ts)) {
      console.log("no name or symbol given for the interface:", taskArgs.i);
      return;
    }
    const nameBytes = getBytes(taskArgs.tn).substr(2);
    const symbolBytes = getBytes(taskArgs.ts).substr(2);

    interfaceData =
      intToBytes32(nameBytes.length / 2) + nameBytes + symbolBytes;

    interfaceVersion = await read("Portal", "generateId", taskArgs.i, 31);

    deployInterface = true;
  } else if (taskArgs.tn || taskArgs.ts) {
    console.log(
      "name or symbol for interface is provided but no version:",
      interfaces
    );
    return;
  }

  let visibility = false;

  if (visibility) {
    if (!visibilities.some((e) => e.Name === taskArgs.v)) {
      console.log("Unknown visibility: 'public' (default) or 'private'.");
      return;
    }

    visibility = visibilities[taskArgs.v];
  }

  try {
    console.log("Tx sent...");
    await execute(
      "Portal",
      {
        from: deployer,
        log: true,
        value: String(32e18),
      },
      "initiatePool",
      BN(Math.floor((taskArgs.f * 10 ** 10) / 100)).toString(),
      interfaceVersion,
      taskArgs.m,
      getBytes(taskArgs.n),
      interfaceData,
      [visibility, deployInterface, taskArgs.lp]
    );
    console.log(`created pool: ${taskArgs.n}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

// done
module.exports = func;