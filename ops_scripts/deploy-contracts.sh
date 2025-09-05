#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to update deployment.json with new addresses
update_deployment_json() {
    local network=$1
    local deployment_file=$2
    
    print_status "Updating deployment.json for network: $network"
    
    # Check if deployment.json exists
    DEPLOYMENT_JSON="../HolonsBot/contracts/deployment.json"
    if [ ! -f "$DEPLOYMENT_JSON" ]; then
        print_error "Deployment.json not found: $DEPLOYMENT_JSON"
        return 1
    fi
    
    # Create backup
    cp "$DEPLOYMENT_JSON" "${DEPLOYMENT_JSON}.backup"
    
    # Extract contract addresses and update deployment.json
    if [ -f "$deployment_file" ]; then
        # Get all contract addresses from the deployment
        local temp_json=$(mktemp)
        
        # Start with existing deployment.json
        cp "$DEPLOYMENT_JSON" "$temp_json"
        
        # Extract and update each contract address
        jq -r '.transactions[] | select(.transactionType == "CREATE") | "\(.contractName):\(.contractAddress)"' "$deployment_file" | while IFS=':' read -r contract_name contract_address; do
            if [ -n "$contract_name" ] && [ -n "$contract_address" ]; then
                print_status "Updating $contract_name: $contract_address"
                
                # Update the deployment.json with new address
                jq ".$network.$contract_name = \"$contract_address\"" "$temp_json" > "${temp_json}.tmp" && mv "${temp_json}.tmp" "$temp_json"
            fi
        done
        
        # Replace original with updated version
        mv "$temp_json" "$DEPLOYMENT_JSON"
        
        print_success "Updated deployment.json for network: $network"
        
        # Show the changes
        print_status "Changes made to deployment.json:"
        diff "${DEPLOYMENT_JSON}.backup" "$DEPLOYMENT_JSON" || true
        
    else
        print_error "Deployment file not found: $deployment_file"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [NETWORK] [OPTIONS]"
    echo ""
    echo "NETWORKS:"
    echo "  localhost    Deploy to local Anvil instance"
    echo "  sepolia      Deploy to Sepolia testnet"
    echo "  mainnet      Deploy to Ethereum mainnet"
    echo ""
    echo "OPTIONS:"
    echo "  --verify     Verify contracts on Etherscan (for testnet/mainnet)"
    echo "  --dry-run    Simulate deployment without broadcasting"
    echo "  --update-subgraph  Automatically update subgraph.yaml after deployment"
    echo "  --help       Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 localhost"
    echo "  $0 sepolia --verify"
    echo "  $0 mainnet --dry-run"
    echo "  $0 localhost --update-subgraph"
}

# Function to deploy to localhost
deploy_localhost() {
    print_status "Checking if Anvil is running from docker-compose..."
    
    # Check if Anvil is already running (from docker-compose)
    if curl -s http://localhost:8545 > /dev/null 2>&1; then
        print_success "Anvil is already running on port 8545 (from docker-compose)"
    else
        print_error "Anvil is not running on port 8545"
        print_status "Please start the Graph Node infrastructure first:"
        print_status "cd contracts/subgraph && docker-compose up -d"
        exit 1
    fi
    
    print_status "Deploying contracts to localhost..."
    
    # Use localhost-specific deployment command
    NETWORK_NAME=localhost forge script script/v3/Deploy.s.sol:Deploy \
        --rpc-url http://0.0.0.0:8545 \
        --broadcast \
        --gas-limit 100000000 \
        -vvvv \
        --skip-simulation
    
    if [ $? -eq 0 ]; then
        print_success "Deployment to localhost completed!"
        
        # Extract contract addresses from deployment
        print_status "Extracting contract addresses..."
        DEPLOYMENT_FILE="broadcast/Deploy.s.sol/31337/run-latest.json"
        if [ -f "$DEPLOYMENT_FILE" ]; then
            echo ""
            echo "=== DEPLOYED CONTRACT ADDRESSES ==="
            jq -r '.transactions[] | select(.transactionType == "CREATE") | "\(.contractName): \(.contractAddress)"' "$DEPLOYMENT_FILE"
            echo "=================================="
            echo ""
            
            # Update deployment.json
            update_deployment_json "localhost" "$DEPLOYMENT_FILE"
            
            # Update subgraph if requested
            if [ "$UPDATE_SUBGRAPH" = "true" ]; then
                print_status "Updating subgraph configuration..."
                ./ops_scripts/update-subgraph-from-deployment.sh localhost
            fi
        fi
    else
        print_error "Deployment to localhost failed!"
        print_status "Trying alternative deployment method..."
        
        # Alternative: Try with --legacy flag
        NETWORK_NAME=localhost forge script script/v3/Deploy.s.sol:Deploy \
            --rpc-url http://0.0.0.0:8545 \
            --broadcast \
            --gas-limit 100000000 \
            -vvvv \
            --legacy \
            --skip-simulation
        
        if [ $? -eq 0 ]; then
            print_success "Deployment to localhost completed with legacy method!"
            
            # Update deployment.json
            update_deployment_json "localhost" "$DEPLOYMENT_FILE"
            
            # Update subgraph if requested
            if [ "$UPDATE_SUBGRAPH" = "true" ]; then
                print_status "Updating subgraph configuration..."
                ./ops_scripts/update-subgraph-from-deployment.sh localhost
            fi
        else
            print_error "First two deployment methods failed!"
            print_status "Trying final method without gas limit..."
            
            # Final attempt: Let Foundry estimate gas
            NETWORK_NAME=localhost forge script script/v3/Deploy.s.sol:Deploy \
                --rpc-url http://0.0.0.0:8545 \
                --broadcast \
                -vvvv \
                --skip-simulation
            
            if [ $? -eq 0 ]; then
                print_success "Deployment to localhost completed with gas estimation!"
                
                # Update deployment.json
                update_deployment_json "localhost" "$DEPLOYMENT_FILE"
                
                # Update subgraph if requested
                if [ "$UPDATE_SUBGRAPH" = "true" ]; then
                    print_status "Updating subgraph configuration..."
                    ./ops_scripts/update-subgraph-from-deployment.sh localhost
                fi
            else
                print_error "All deployment methods failed!"
                exit 1
            fi
        fi
    fi
}

# Function to deploy to Sepolia
deploy_sepolia() {
    print_status "Deploying contracts to Sepolia..."
    
    # Check if private key is set
    if [ -z "$PRIVATE_KEY" ]; then
        print_error "PRIVATE_KEY environment variable is not set"
        echo "Please set your private key: export PRIVATE_KEY=your_private_key_here"
        exit 1
    fi
    
    # Check if Etherscan API key is set for verification
    if [ "$VERIFY" = "true" ] && [ -z "$ETHERSCAN_API_KEY" ]; then
        print_warning "ETHERSCAN_API_KEY not set, skipping verification"
        VERIFY="false"
    fi
    
    local cmd="NETWORK_NAME=sepolia forge script script/v3/Deploy.s.sol:Deploy \
        --rpc-url https://sepolia.infura.io/v3/966b62ed84c84715bc5970a1afecad29 \
        --broadcast"
    
    if [ "$VERIFY" = "true" ]; then
        cmd="$cmd --verify"
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        cmd="$cmd --dry-run"
    fi
    
    eval $cmd
    
    if [ $? -eq 0 ]; then
        print_success "Deployment to Sepolia completed!"
        
        # Extract contract addresses from deployment
        print_status "Extracting contract addresses..."
        DEPLOYMENT_FILE="broadcast/Deploy.s.sol/11155111/run-latest.json"
        if [ -f "$DEPLOYMENT_FILE" ]; then
            echo ""
            echo "=== DEPLOYED CONTRACT ADDRESSES ==="
            jq -r '.transactions[] | select(.transactionType == "CREATE") | "\(.contractName): \(.contractAddress)"' "$DEPLOYMENT_FILE"
            echo "=================================="
            echo ""
            
            # Update deployment.json
            update_deployment_json "sepolia" "$DEPLOYMENT_FILE"
            
            # Update subgraph if requested
            if [ "$UPDATE_SUBGRAPH" = "true" ]; then
                print_status "Updating subgraph configuration..."
                ./ops_scripts/update-subgraph-from-deployment.sh sepolia
            fi
        fi
    else
        print_error "Deployment to Sepolia failed!"
        exit 1
    fi
}

# Function to deploy to mainnet
deploy_mainnet() {
    print_warning "You are about to deploy to MAINNET!"
    echo "This will cost real ETH. Are you sure? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled"
        exit 0
    fi
    
    print_status "Deploying contracts to mainnet..."
    
    # Check if private key is set
    if [ -z "$PRIVATE_KEY" ]; then
        print_error "PRIVATE_KEY environment variable is not set"
        echo "Please set your private key: export PRIVATE_KEY=your_private_key_here"
        exit 1
    fi
    
    local cmd="NETWORK_NAME=mainnet forge script script/v3/Deploy.s.sol:Deploy \
        --rpc-url https://mainnet.infura.io/v3/966b62ed84c84715bc5970a1afecad29 \
        --broadcast"
    
    if [ "$VERIFY" = "true" ]; then
        cmd="$cmd --verify"
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        cmd="$cmd --dry-run"
    fi
    
    eval $cmd
    
    if [ $? -eq 0 ]; then
        print_success "Deployment to mainnet completed!"
        
        # Extract contract addresses from deployment
        print_status "Extracting contract addresses..."
        DEPLOYMENT_FILE="broadcast/Deploy.s.sol/1/run-latest.json"
        if [ -f "$DEPLOYMENT_FILE" ]; then
            echo ""
            echo "=== DEPLOYED CONTRACT ADDRESSES ==="
            jq -r '.transactions[] | select(.transactionType == "CREATE") | "\(.contractName): \(.contractAddress)"' "$DEPLOYMENT_FILE"
            echo "=================================="
            echo ""
            
            # Update deployment.json
            update_deployment_json "homestead" "$DEPLOYMENT_FILE"
            
            # Update subgraph if requested
            if [ "$UPDATE_SUBGRAPH" = "true" ]; then
                print_status "Updating subgraph configuration..."
                ./ops_scripts/update-subgraph-from-deployment.sh homestead
            fi
        fi
    else
        print_error "Deployment to mainnet failed!"
        exit 1
    fi
}

# Parse command line arguments
NETWORK=""
VERIFY="false"
DRY_RUN="false"
UPDATE_SUBGRAPH="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        localhost|sepolia|mainnet)
            NETWORK="$1"
            shift
            ;;
        --verify)
            VERIFY="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --update-subgraph)
            UPDATE_SUBGRAPH="true"
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if network is specified
if [ -z "$NETWORK" ]; then
    print_error "No network specified"
    show_usage
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "foundry.toml" ]; then
    print_error "Please run this script from the contracts directory"
    exit 1
fi

print_status "Starting deployment to $NETWORK..."

# Deploy based on network
case $NETWORK in
    localhost)
        deploy_localhost
        ;;
    sepolia)
        deploy_sepolia
        ;;
    mainnet)
        deploy_mainnet
        ;;
    *)
        print_error "Unknown network: $NETWORK"
        show_usage
        exit 1
        ;;
esac

print_success "Deployment script completed!"
