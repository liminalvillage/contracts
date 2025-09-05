#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [NETWORK]"
    echo ""
    echo "NETWORKS:"
    echo "  localhost    Update for localhost deployment"
    echo "  sepolia      Update for Sepolia testnet"
    echo "  homestead    Update for Ethereum mainnet"
    echo "  gnosis       Update for Gnosis chain"
    echo "  virtualtestnet Update for virtual testnet"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 localhost"
    echo "  $0 sepolia"
    echo "  $0 homestead"
}

# Check arguments
if [ $# -ne 1 ]; then
    print_error "Invalid number of arguments"
    show_usage
    exit 1
fi

NETWORK=$1

# Validate network
case $NETWORK in
    localhost|sepolia|homestead|gnosis|virtualtestnet)
        ;;
    *)
        print_error "Invalid network: $NETWORK"
        show_usage
        exit 1
        ;;
esac

# Check if we're in the right directory
if [ ! -f "foundry.toml" ]; then
    print_error "Please run this script from the contracts directory"
    exit 1
fi

# Check if deployment.json exists
DEPLOYMENT_FILE="../HolonsBot/contracts/deployment.json"
if [ ! -f "$DEPLOYMENT_FILE" ]; then
    print_error "Deployment file not found: $DEPLOYMENT_FILE"
    exit 1
fi

print_status "Updating subgraph configuration for $NETWORK..."

# Extract contract addresses from deployment.json
HOLONS_ADDRESS=$(jq -r ".$NETWORK.Holons" "$DEPLOYMENT_FILE")

if [ "$HOLONS_ADDRESS" = "null" ] || [ -z "$HOLONS_ADDRESS" ]; then
    print_error "Holons contract address not found for network: $NETWORK"
    print_status "Available networks in deployment.json:"
    jq -r 'keys[]' "$DEPLOYMENT_FILE"
    exit 1
fi

print_success "Found Holons address: $HOLONS_ADDRESS"

# Determine subgraph network value
case $NETWORK in
    localhost)
        SUBGRAPH_NETWORK="mainnet"  # Use mainnet for localhost testing
        ;;
    sepolia)
        SUBGRAPH_NETWORK="sepolia"
        ;;
    homestead)
        SUBGRAPH_NETWORK="mainnet"
        ;;
    gnosis)
        SUBGRAPH_NETWORK="gnosis"
        ;;
    virtualtestnet)
        SUBGRAPH_NETWORK="mainnet"  # Use mainnet for virtual testnet
        ;;
esac

print_status "Using subgraph network: $SUBGRAPH_NETWORK"

# Update subgraph.yaml
cd subgraph

# Create backup
cp subgraph.yaml subgraph.yaml.backup

# Update the configuration using sed
sed -i "s/network: [a-zA-Z]*/network: $SUBGRAPH_NETWORK/g" subgraph.yaml
sed -i "s/address: \"[^\"]*\"/address: \"$HOLONS_ADDRESS\"/g" subgraph.yaml

# Update all template networks
sed -i "s/network: [a-zA-Z]*/network: $SUBGRAPH_NETWORK/g" subgraph.yaml

print_success "Updated subgraph.yaml:"
echo "  Network: $SUBGRAPH_NETWORK"
echo "  Contract Address: $HOLONS_ADDRESS"

# Show the changes
print_status "Changes made:"
diff subgraph.yaml.backup subgraph.yaml || true

print_success "Subgraph configuration updated successfully!"
print_status "Next steps:"
echo "  1. Run: npm run codegen"
echo "  2. Run: npm run build"
echo "  3. Run: npm run deploy-local (for localhost)"
echo "  4. Or run: npm run deploy (for hosted service)"
