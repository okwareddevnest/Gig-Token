#!/bin/bash

# Check if network parameter is provided
if [ -z "$1" ]; then
    echo "Please specify network (shasta or mainnet)"
    exit 1
fi

NETWORK=$1

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Creating .env file from template..."
    cp .env.example .env
    echo "Please fill in your configuration in .env file"
    exit 1
fi

# Check if private key is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "Please set your PRIVATE_KEY in the .env file"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm init -y
    npm install dotenv @truffle/hdwallet-provider tronweb
fi

# Compile contracts
echo "Compiling contracts..."
tronbox compile

# Deploy to specified network
echo "Deploying to $NETWORK..."
tronbox migrate --network $NETWORK --reset

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo "Deployment successful!"
    echo "Deployment information has been saved to deployment-$NETWORK.json"
    echo "Please save this information for future reference."
    
    if [ "$NETWORK" = "mainnet" ]; then
        echo "⚠️  IMPORTANT: This is a mainnet deployment!"
        echo "Make sure to save the contract address and verify all functionality on testnet first."
    fi
else
    echo "Deployment failed!"
    exit 1
fi 