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

# Check if we're in the right directory
if [ ! -f "foundry.toml" ]; then
    print_error "Please run this script from the contracts directory"
    exit 1
fi

print_status "Testing complete workflow..."

# Test 1: Check if deployment.json exists and has expected structure
print_status "Test 1: Checking deployment.json structure..."
DEPLOYMENT_FILE="../HolonsBot/contracts/deployment.json"
if [ ! -f "$DEPLOYMENT_FILE" ]; then
    print_error "deployment.json not found"
    exit 1
fi

# Check if it has the expected networks
EXPECTED_NETWORKS=("localhost" "sepolia" "homestead" "gnosis" "virtualtestnet")
for network in "${EXPECTED_NETWORKS[@]}"; do
    if jq -e ".$network" "$DEPLOYMENT_FILE" > /dev/null 2>&1; then
        print_success "✓ Network '$network' found in deployment.json"
    else
        print_warning "⚠ Network '$network' not found in deployment.json"
    fi
done

# Test 2: Check if subgraph directory exists
print_status "Test 2: Checking subgraph directory..."
if [ ! -d "subgraph" ]; then
    print_error "subgraph directory not found"
    exit 1
fi

if [ ! -f "subgraph/subgraph.yaml" ]; then
    print_error "subgraph.yaml not found"
    exit 1
fi

print_success "✓ Subgraph directory and files exist"

# Test 3: Test the update-subgraph-from-deployment script
print_status "Test 3: Testing subgraph update script..."
if [ -f "ops_scripts/update-subgraph-from-deployment.sh" ]; then
    print_success "✓ update-subgraph-from-deployment.sh exists"
    
    # Test with localhost (should work)
    if ./ops_scripts/update-subgraph-from-deployment.sh localhost > /dev/null 2>&1; then
        print_success "✓ update-subgraph-from-deployment.sh works for localhost"
    else
        print_error "✗ update-subgraph-from-deployment.sh failed for localhost"
    fi
else
    print_error "✗ update-subgraph-from-deployment.sh not found"
fi

# Test 4: Check if required tools are available
print_status "Test 4: Checking required tools..."
TOOLS=("jq" "sed" "diff" "forge" "anvil")
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" > /dev/null 2>&1; then
        print_success "✓ $tool is available"
    else
        print_error "✗ $tool is not available"
    fi
done

# Test 5: Show current deployment.json structure
print_status "Test 5: Current deployment.json structure..."
echo ""
echo "Available networks and contracts:"
jq -r 'to_entries[] | "\(.key): \(.value | keys | join(", "))"' "$DEPLOYMENT_FILE"
echo ""

print_success "Workflow test completed!"
print_status "To test the complete workflow:"
echo "  1. Deploy contracts: ./ops_scripts/deploy-contracts.sh localhost --update-subgraph"
echo "  2. Check deployment.json was updated"
echo "  3. Check subgraph.yaml was updated"
echo "  4. Run subgraph: cd subgraph && npm run codegen && npm run build"
