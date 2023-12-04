require("dotenv").config();

require("@openzeppelin/hardhat-upgrades");

require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("hardhat-exposed");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("solidity-coverage");

require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-truffle5");
require("@nomicfoundation/hardhat-verify");
require("@nomicfoundation/hardhat-ethers");
require("ethers");

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
        version: "0.8.20",
        evmVersion: "shanghai", // if the blockchain is not supporting PUSH0: paris.
        settings: {
          // viaIR: false,
          optimizer: {
            enabled: true,
            runs: 200,
            // details: {
            //   yulDetails: {
            //     optimizerSteps: "u",
            //   },
            // },
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
            url: process.env.GOERLI_URL,
          }
        : undefined,
      accounts: {
        accountsBalance: "1000000000000000000000000",
      },
      allowUnlimitedContractSize: true,
    },
    goerli: {
      url: process.env.GOERLI_URL,
      deploy: ["./deploy"],
      chainId: 5,
      gasPrice: 1e10, // 10 gwei
    },
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer.
    },
    oracle: {
      default: 1,
      0: 1,
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
