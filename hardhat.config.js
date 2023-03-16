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
            runs: 200,
            enabled: true,
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
            url: process.env.GOERLI,
          }
        : undefined,
    },
    goerli: {
      url: process.env.GOERLI,
      deploy: ["./deploy"],
      chainId: 5,
      gasPrice: ethers.utils.parseUnits("100", "gwei").toNumber(),
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
    coinmarketcap: process.env.COINMARKETCAP,
  },
  etherscan: {
    apiKey: {
      goerli: process.env.ETHERSCAN_API_KEY,
    },
  },
};
if (process.env.ACCOUNT_PRIVATE_KEYS) {
  config.networks = {
    ...config.networks,
    goerli: {
      ...config.networks?.goerli,
      accounts: process.env.ACCOUNT_PRIVATE_KEYS.split(","),
    },
  };
}
module.exports = config;
