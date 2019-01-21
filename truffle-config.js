require("dotenv").config();
const HDWalletProvider = require("truffle-hdwallet-provider");
const { toWei, toHex } = require("web3-utils");

// You must specify MNEMONIC and INFURA_API_KEY in your .env file
function createProvider (network) {
  if (!process.env.MNEMONIC) {
    console.log("Please set your MNEMONIC");
    process.exit(1);
  }
  if (!process.env.INFURA_API_KEY) {
    console.log("Please set your INFURA_API_KEY");
    process.exit(1);
  }
  return () => {
    return new HDWalletProvider(
      process.env.MNEMONIC,
      `https://${network}.infura.io/` + process.env.INFURA_API_KEY
    );
  };
}

const rinkebyProvider = process.env.SOLIDITY_COVERAGE
  ? undefined
  : createProvider("rinkeby");

module.exports = {
  compilers: {
    solc: {
      version: "0.4.25",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
  networks: {
    development: {
      host: "localhost",
      gas: 4700000,
      gasPrice: toHex(toWei("1", "gwei")),
      network_id: 1234, // eslint-disable-line camelcase
      port: 8545,
    },
    rinkeby: {
      provider: rinkebyProvider,
      gas: 4700000,
      gasPrice: toHex(toWei("10", "gwei")),
      network_id: "4", // eslint-disable-line camelcase,
    },
  },
};
