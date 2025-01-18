require('dotenv').config();

module.exports = {
  networks: {
    development: {
      // For trontools/quickstart docker image
      privateKey: process.env.PRIVATE_KEY,
      userFeePercentage: 100,
      feeLimit: 1e8,
      fullHost: 'http://127.0.0.1:9090',
      network_id: '9'
    },
    shasta: {
      // Shasta testnet
      privateKey: process.env.PRIVATE_KEY,
      userFeePercentage: 50,
      feeLimit: 1e8,
      fullHost: process.env.TESTNET_URL || 'https://api.shasta.trongrid.io',
      network_id: '2',
      headers: process.env.TRONGRID_API_KEY ? {
        "TRON-PRO-API-KEY": process.env.TRONGRID_API_KEY
      } : {}
    },
    mainnet: {
      // TRON mainnet
      privateKey: process.env.PRIVATE_KEY,
      userFeePercentage: 50,
      feeLimit: 1e8,
      fullHost: process.env.MAINNET_URL || 'https://api.trongrid.io',
      network_id: '1',
      headers: process.env.TRONGRID_API_KEY ? {
        "TRON-PRO-API-KEY": process.env.TRONGRID_API_KEY
      } : {}
    }
  },
  compilers: {
    solc: {
      version: '0.8.0',
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}; 