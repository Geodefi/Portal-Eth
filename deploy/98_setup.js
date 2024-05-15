const { strToBytes, generateId } = require("../utils");

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
      console.log("transferred Pauser Role");
    }
    if (!(await read("gETH", "hasRole", MINTER, pAddress))) {
      await execute("gETH", { from: deployer, log: true }, "transferMinterRole", pAddress);
      console.log("transferred Minter Role");
    }
    if (!(await read("gETH", "hasRole", ORACLE, pAddress))) {
      await execute("gETH", { from: deployer, log: true }, "transferOracleRole", pAddress);
      console.log("transferred Oracle Role");
    }
    if (!(await read("gETH", "hasRole", MIDDLEWARE_MANAGER, pAddress))) {
      await execute(
        "gETH",
        { from: deployer, log: true },
        "transferMiddlewareManagerRole",
        pAddress
      );
      console.log("transferred MiddlewareManager Role");
    }
    console.log("Portal is now gETH minter\n");

    // WITHDRAWAL PACKAGE
    const wpType = 10011;

    const wpAddress = (await get("WithdrawalPackage")).address;
    const expectedWPVersion = (await generateId(strToBytes("v1"), wpType)).toString();
    if ((await read("Portal", "getPackageVersion", wpType)).toString() === expectedWPVersion) {
      console.log("Withdrawal Package is ALREADY released\n");
    } else {
      await execute(
        "Portal",
        { from: deployer, log: true },
        "propose",
        wpAddress,
        wpType,
        strToBytes("v1"),
        DAY
      );
      await execute("Portal", { from: deployer, log: true }, "approveProposal", expectedWPVersion);
      console.log("Withdrawal Package is released\n");
    }

    // LIQUIDITY PACKAGE
    console.log("LiquidityPackage WILL NOT BE SETUP");
    // const lpType = 10021;

    // const lpAddress = (await get("LiquidityPackage")).address;
    // const expectedLPVersion = (await generateId(strToBytes("v1"), lpType)).toString();
    // if ((await read("Portal", "getPackageVersion", lpType)).toString() === expectedLPVersion) {
    //   console.log("Liquidity Package Package is ALREADY released\n");
    // } else {
    //   await execute(
    //     "Portal",
    //     { from: deployer, log: true },
    //     "propose",
    //     lpAddress,
    //     lpType,
    //     strToBytes("v1"),
    //     DAY
    //   );
    //   await execute("Portal", { from: deployer, log: true }, "approveProposal", expectedLPVersion);
    //   console.log("Liquidity Package Package is released\n");
    // }

    // MIDDLEWARES
    const middlewareType = 20011;

    // erc20
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

    // erc20-permit
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

    // erc20-rebase
    const erc20RebaseAddress = (await get("ERC20RebaseMiddleware")).address;
    const erc20RebaseVersion = (
      await generateId(strToBytes("ERC20Rebase"), middlewareType)
    ).toString();
    if (await read("Portal", "isMiddleware", middlewareType, erc20RebaseVersion)) {
      console.log("ERC20Rebase Middleware is ALREADY released\n");
    } else {
      await execute(
        "Portal",
        { from: deployer, log: true },
        "propose",
        erc20RebaseAddress,
        middlewareType,
        strToBytes("ERC20Rebase"),
        DAY
      );
      await execute("Portal", { from: deployer, log: true }, "approveProposal", erc20RebaseVersion);
      console.log("ERC20Rebase Middleware is released\n");
    }

    // erc20-rebase-permit
    const erc20RebasePermitAddress = (await get("ERC20RebasePermitMiddleware")).address;
    const erc20RebasePermitVersion = (
      await generateId(strToBytes("ERC20RebasePermit"), middlewareType)
    ).toString();
    if (await read("Portal", "isMiddleware", middlewareType, erc20RebasePermitVersion)) {
      console.log("ERC20RebasePermit Middleware is ALREADY released\n");
    } else {
      await execute(
        "Portal",
        { from: deployer, log: true },
        "propose",
        erc20RebasePermitAddress,
        middlewareType,
        strToBytes("ERC20RebasePermit"),
        DAY
      );
      await execute(
        "Portal",
        { from: deployer, log: true },
        "approveProposal",
        erc20RebasePermitVersion
      );
      console.log("ERC20RebasePermit Middleware is released\n");
    }
  } catch (error) {
    console.log(error);
    console.log("Setup is not completed, run the script again.");
  }
};

module.exports = func;
module.exports.tags = ["setupPortal"];
