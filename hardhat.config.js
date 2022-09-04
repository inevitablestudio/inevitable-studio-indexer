/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require('hardhat-deploy');
require("hardhat-gas-reporter");
require("hardhat-abi-exporter");
require("dotenv").config();

const alchemyKey = process.env.ALCHEMY_KEY || "";

function nodeUrl(network) {
  return `https://${network}.g.alchemy.com/v2/${alchemyKey}`;
}

let privateKey = process.env.PK || "";
const accounts = privateKey ? [privateKey] : undefined;

module.exports = {
  solidity: "0.8.9",
  defaultNetwork: "ganache",
  networks: {
    local: {
      url: 'http://localhost:8545',
    },
    ganache: {
      url: "HTTP://127.0.0.1:7545", // Localhost (default: none)
      accounts: accounts,
    },
    mainnet: {
      url: nodeUrl("polygon-mainnet"),
      gasPrice: 40000000000,
      timeout: 50000,
      accounts: accounts,
    },
    mumbai: {
      url: nodeUrl("polygon-mumbai"),
      gasPrice: 40000000000,
      timeout: 50000,
      accounts: accounts,
      chainId: 80001
    },
  },
  gasReporter: {
    showTimeSpent: true,
    currency: "USD",
  },
  namedAccounts: {
    deployer: {
      default: 0,
      address: process.env.GANACHE_DEPLOYER_ADDRESS,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
