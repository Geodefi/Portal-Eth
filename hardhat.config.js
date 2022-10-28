require("dotenv").config();

require("hardhat-contract-sizer");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("hardhat-deploy");

require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
const ethers = require("ethers");
require("./scripts");

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const FORK_MAINNET = process.env.FORK_MAINNET === "true";

const config = {
  solidity: {
    compilers: [
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      deploy: ["./deploy"],
      forking: FORK_MAINNET
        ? {
            url: process.env.FORK_URL,
          }
        : undefined,
      // allowUnlimitedContractSize: true,
    },
    prater: {
      url: process.env.PRATER,
      deploy: ["./deploy"],
      chainId: 5,
      gasPrice: ethers.utils.parseUnits("90", "gwei").toNumber(),
    },
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer.
    },
    senate: {
      default: 1,
      0: 1,
    },
    ELECTOR: {
      default: 2,
      0: 2,
    },
  },
  paths: {
    sources: "./contracts",
    artifacts: "./build/artifacts",
    cache: "./build/cache",
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 30,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
if (process.env.ACCOUNT_PRIVATE_KEYS) {
  config.networks = {
    ...config.networks,
    prater: {
      ...config.networks?.prater,
      accounts: process.env.ACCOUNT_PRIVATE_KEYS.split(" "),
    },
  };
}
module.exports = config;
