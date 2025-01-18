require('dotenv').config();
const GIGToken = artifacts.require("GIGToken");
const SafeMath = artifacts.require("SafeMath");
const Ownable = artifacts.require("Ownable");

module.exports = async function(deployer, network, accounts) {
  // USDT contract addresses from environment variables
  const USDT_ADDRESSES = {
    mainnet: process.env.MAINNET_USDT_ADDRESS || "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
    shasta: process.env.TESTNET_USDT_ADDRESS || "TG3XXyExBkPp9nzdajDZsozEu4BkaSJozs",
    development: process.env.LOCAL_USDT_ADDRESS || "your_local_usdt_address"
  };

  const usdtAddress = USDT_ADDRESSES[network];
  if (!usdtAddress) {
    throw new Error(`No USDT address configured for network: ${network}`);
  }

  // Deploy libraries first
  await deployer.deploy(SafeMath);
  await deployer.link(SafeMath, GIGToken);

  // Use environment variable for initial holder if provided, otherwise use first account
  const initialHolder = process.env.INITIAL_HOLDER_ADDRESS || accounts[0];
  await deployer.deploy(GIGToken, initialHolder, usdtAddress);
  
  const gigToken = await GIGToken.deployed();
  
  console.log("\nDeployment completed successfully!");
  console.log("================================");
  console.log("Network:", network);
  console.log("GIG Token address:", gigToken.address);
  console.log("Initial holder:", initialHolder);
  console.log("USDT address:", usdtAddress);
  console.log("================================\n");

  // Save deployment info to a file
  const fs = require('fs');
  const deploymentInfo = {
    network,
    gigTokenAddress: gigToken.address,
    initialHolder,
    usdtAddress,
    deploymentTime: new Date().toISOString()
  };

  fs.writeFileSync(
    `deployment-${network}.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );
}; 