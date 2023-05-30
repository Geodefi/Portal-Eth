const { strToBytes, generateId } = require("../test/utils");

const func = async (hre) => {
  const { deployments, getNamedAccounts } = hre;
  const { execute, get, read } = deployments;
  const { deployer } = await getNamedAccounts();

  DAY = 24 * 60 * 60;

  console.log("\nSetting up the Portal:\n");

  try {
    const PAUSER = web3.utils.soliditySha3("PAUSER_ROLE");
    const MINTER = web3.utils.soliditySha3("MINTER_ROLE");
    const MIDDLEWARE_MANAGER = web3.utils.soliditySha3("MIDDLEWARE_MANAGER_ROLE");
    const ORACLE = web3.utils.soliditySha3("ORACLE_ROLE");

    const pAddress = (await get("Portal")).address;

    if (!(await read("gETH", "hasRole", PAUSER, pAddress))) {
      await execute("gETH", { from: deployer, log: true }, "transferPauserRole", pAddress);
    }
    if (!(await read("gETH", "hasRole", MINTER, pAddress))) {
      await execute("gETH", { from: deployer, log: true }, "transferMinterRole", pAddress);
    }
    if (!(await read("gETH", "hasRole", ORACLE, pAddress))) {
      await execute("gETH", { from: deployer, log: true }, "transferOracleRole", pAddress);
    }
    if (!(await read("gETH", "hasRole", MIDDLEWARE_MANAGER, pAddress))) {
      await execute(
        "gETH",
        { from: deployer, log: true },
        "transferMiddlewareManagerRole",
        pAddress
      );
    }
    console.log("Portal is now gETH minter\n");

    const wcAddress = (await get("WithdrawalContract")).address;
    const wcType = 10011;
    const expectedWCPVersion = (await generateId(strToBytes("v1"), wcType)).toString();
    if ((await read("Portal", "getPackageVersion", wcType)).toString() === expectedWCPVersion) {
      console.log("Withdrawal Contract Package is ALREADY released\n");
    } else {
      await execute(
        "Portal",
        { from: deployer, log: true },
        "propose",
        wcAddress,
        wcType,
        strToBytes("v1"),
        DAY
      );
      await execute("Portal", { from: deployer, log: true }, "approveProposal", expectedWCPVersion);
      console.log("Withdrawal Contract Package is released\n");
    }

    const lpAddress = (await get("LiquidityPool")).address;
    const lpType = 10021;
    const expectedLPPVersion = (await generateId(strToBytes("v1"), lpType)).toString();
    if ((await read("Portal", "getPackageVersion", lpType)).toString() === expectedLPPVersion) {
      console.log("Liquidity Pool Package is ALREADY released\n");
    } else {
      await execute(
        "Portal",
        { from: deployer, log: true },
        "propose",
        lpAddress,
        lpType,
        strToBytes("v1"),
        DAY
      );
      await execute("Portal", { from: deployer, log: true }, "approveProposal", expectedLPPVersion);
      console.log("Liquidity Pool Package is released\n");
    }

    const middlewareType = 20011;
    const erc20Address = (await get("ERC20Middleware")).address;
    const erc20Version = (await generateId(strToBytes("ERC20"), middlewareType)).toString();
    if (await read("Portal", "isMiddleware", middlewareType, erc20Version)) {
      console.log("ERC20 Middleware is ALREADY released\n");
    } else {
      await execute(
        "Portal",
        { from: deployer, log: true },
        "propose",
        erc20Address,
        middlewareType,
        strToBytes("ERC20"),
        DAY
      );
      await execute("Portal", { from: deployer, log: true }, "approveProposal", erc20Version);
      console.log("ERC20 Middleware is released\n");
    }

    const erc20PermitAddress = (await get("ERC20PermitMiddleware")).address;
    const erc20PermitVersion = (
      await generateId(strToBytes("ERC20Permit"), middlewareType)
    ).toString();
    if (await read("Portal", "isMiddleware", middlewareType, erc20PermitVersion)) {
      console.log("ERC20Permit Middleware is ALREADY released\n");
    } else {
      await execute(
        "Portal",
        { from: deployer, log: true },
        "propose",
        erc20PermitAddress,
        middlewareType,
        strToBytes("ERC20Permit"),
        DAY
      );
      await execute("Portal", { from: deployer, log: true }, "approveProposal", erc20PermitVersion);
      console.log("ERC20Permit Middleware is released\n");
    }
  } catch (error) {
    console.log(error);
    console.log("Setup is not completed, run the script again.");
  }
};

module.exports = func;
module.exports.tags = ["setupPortal"];