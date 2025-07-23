#!/bin/bash

# Check if network argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: ./deploy.sh <network>"
    echo "Available networks: local, sepolia, mainnet"
    exit 1
fi

NETWORK=$1
SUBGRAPH_NAME="holons-sepolia"  # Change this to your actual subgraph name
VERSION="0.0.1"

# Validate network argument
if [ "$NETWORK" != "local" ] && [ "$NETWORK" != "sepolia" ] && [ "$NETWORK" != "mainnet" ]; then
    echo "Invalid network: $NETWORK"
    echo "Available networks: local, sepolia, mainnet"
    exit 1
fi

echo "Deploying to $NETWORK network..."

# Copy the correct config file
cp config/subgraph.$NETWORK.yaml ./subgraph.yaml
echo "Using configuration from config/subgraph.$NETWORK.yaml"

# Generate code from the schema
echo "Generating code..."
graph codegen

# Build the subgraph
echo "Building subgraph..."
graph build

# Deploy the subgraph
if [ "$NETWORK" = "local" ]; then
    LOCAL_SUBGRAPH_NAME="holons-local"  # Update this to your preferred local subgraph name
    
    echo "Creating subgraph in local Graph node..."
    curl -s -H "Content-Type: application/json" \
         --data "{\"jsonrpc\":\"2.0\",\"method\":\"subgraph_create\",\"params\":{\"name\":\"$LOCAL_SUBGRAPH_NAME\"},\"id\":\"1\"}" \
         http://127.0.0.1:8020/
    
    echo -e "\nDeploying to local Graph node with version $VERSION..."
    graph deploy --node http://localhost:8020/ $LOCAL_SUBGRAPH_NAME --version-label $VERSION
else
    echo "Deploying to Subgraph Studio with version $VERSION..."
    graph deploy $SUBGRAPH_NAME --version-label $VERSION
fi

echo "Deployment completed!"