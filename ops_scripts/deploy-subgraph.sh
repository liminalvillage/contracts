#!/bin/bash

# Subgraph Deployment Script
# This script handles the complete subgraph deployment process per network

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$(dirname "$SCRIPT_DIR")"
SUBGRAPH_DIR="$CONTRACTS_DIR/subgraph"

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [NETWORK] [OPTIONS]"
    echo ""
    echo "NETWORKS:"
    echo "  localhost    Deploy to local Graph Node"
    echo "  sepolia      Deploy to Subgraph Studio (Sepolia)"
    echo "  mainnet      Deploy to Subgraph Studio (Mainnet)"
    echo ""
    echo "OPTIONS:"
    echo "  --start-infra    Start Graph Node infrastructure first"
    echo "  --force          Force recreate subgraph (remove existing)"
    echo "  --help           Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 localhost --start-infra"
    echo "  $0 sepolia"
    echo "  $0 localhost --force"
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v npm >/dev/null 2>&1; then
        error "npm is not installed"
        exit 1
    fi
    
    if ! command -v graph >/dev/null 2>&1; then
        error "Graph CLI is not installed. Install with: npm install -g @graphprotocol/graph-cli"
        exit 1
    fi
    
    success "All prerequisites are installed"
}

# Function to start Graph Node infrastructure
start_infrastructure() {
    log "Starting Graph Node infrastructure..."
    
    cd "$SUBGRAPH_DIR"
    
    # Check if infrastructure is already running
    if docker ps | grep -q "subgraph-graph-node"; then
        success "Graph Node infrastructure is already running"
        return 0
    fi
    
    # Start infrastructure
    docker-compose up -d
    
    # Wait for services to be ready
    log "Waiting for Graph Node to start up..."
    sleep 30
    
    # Check if services are running
    if ! docker ps | grep -q "subgraph-graph-node"; then
        error "Graph Node failed to start"
        exit 1
    fi
    
    success "Graph Node infrastructure is running"
}

# Function to prepare subgraph configuration
prepare_subgraph_config() {
    local network=$1
    
    log "Preparing subgraph configuration for $network..."
    
    cd "$SUBGRAPH_DIR"
    
    # Copy the correct config file
    case $network in
        localhost)
            CONFIG_FILE="config/subgraph.local.yaml"
            SUBGRAPH_NAME="holons-local"
            ;;
        sepolia)
            CONFIG_FILE="config/subgraph.sepolia.yaml"
            SUBGRAPH_NAME="holons-sepolia"
            ;;
        mainnet)
            CONFIG_FILE="config/subgraph.mainnet.yaml"
            SUBGRAPH_NAME="holons-mainnet"
            ;;
        *)
            error "Unknown network: $network"
            exit 1
            ;;
    esac
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Copy config to main subgraph.yaml
    cp "$CONFIG_FILE" "subgraph.yaml"
    success "Using configuration from $CONFIG_FILE"
    
    echo "$SUBGRAPH_NAME"
}

# Function to install dependencies
install_dependencies() {
    log "Installing npm dependencies..."
    
    cd "$SUBGRAPH_DIR"
    
    if [ ! -d "node_modules" ]; then
        npm install
        success "Dependencies installed"
    else
        success "Dependencies already installed"
    fi
}

# Function to build subgraph
build_subgraph() {
    log "Building subgraph..."
    
    cd "$SUBGRAPH_DIR"
    
    # Generate code from schema
    log "Generating GraphQL code..."
    npm run codegen
    
    # Build subgraph
    log "Building subgraph..."
    npm run build
    
    success "Subgraph built successfully"
}

# Function to deploy subgraph
deploy_subgraph() {
    local network=$1
    local subgraph_name=$2
    local force=$3
    
    log "Deploying subgraph to $network..."
    
    cd "$SUBGRAPH_DIR"
    
    case $network in
        localhost)
            # Remove existing subgraph if force flag is set
            if [ "$force" = "true" ]; then
                log "Removing existing subgraph..."
                npm run remove-local 2>/dev/null || true
                sleep 5
            fi
            
            # Create subgraph if it doesn't exist
            if ! graph list --node http://localhost:8020/ | grep -q "$subgraph_name"; then
                log "Creating subgraph..."
                npm run create-local
                sleep 5
            fi
            
            # Deploy subgraph
            log "Deploying to local Graph Node..."
            npm run deploy-local -- --version-label v0.0.1
            ;;
        sepolia|mainnet)
            # Deploy to Subgraph Studio
            log "Deploying to Subgraph Studio..."
            graph deploy "$subgraph_name" --version-label v0.0.1
            ;;
        *)
            error "Unknown network: $network"
            exit 1
            ;;
    esac
    
    success "Subgraph deployed successfully"
}

# Function to wait for indexing
wait_for_indexing() {
    local network=$1
    local subgraph_name=$2
    
    log "Waiting for subgraph to start indexing..."
    
    case $network in
        localhost)
            # Wait for indexing to begin
            sleep 30
            
            # Check if subgraph is indexing
            log "Checking indexing status..."
            
            # Try a simple query to see if it's working
            local max_attempts=10
            local attempt=1
            
            while [ $attempt -le $max_attempts ]; do
                log "Attempt $attempt/$max_attempts: Testing subgraph query..."
                
                response=$(curl -s -X POST http://localhost:8000/subgraphs/name/$subgraph_name \
                    -H "Content-Type: application/json" \
                    -d '{"query": "{ _meta { block { number } } }"}' 2>/dev/null || echo "error")
                
                if echo "$response" | grep -q "data"; then
                    success "Subgraph is responding to queries!"
                    return 0
                fi
                
                log "Subgraph not ready yet, waiting..."
                sleep 30
                attempt=$((attempt + 1))
            done
            
            warning "Subgraph may not be fully indexed yet"
            ;;
        sepolia|mainnet)
            log "For Subgraph Studio, check indexing status at: https://thegraph.com/studio/subgraph/$subgraph_name"
            ;;
    esac
}

# Function to show deployment info
show_deployment_info() {
    local network=$1
    local subgraph_name=$2
    
    echo ""
    echo "🎉 Subgraph Deployment Complete!"
    echo "================================"
    echo "Network: $network"
    echo "Subgraph Name: $subgraph_name"
    
    case $network in
        localhost)
            echo "Graph Node: http://localhost:8000"
            echo "Query URL: http://localhost:8000/subgraphs/name/$subgraph_name"
            echo ""
            echo "To test queries:"
            echo "  curl -X POST http://localhost:8000/subgraphs/name/$subgraph_name \\"
            echo "    -H 'Content-Type: application/json' \\"
            echo "    -d '{\"query\": \"{ _meta { block { number } } }\"}'"
            ;;
        sepolia|mainnet)
            echo "Subgraph Studio: https://thegraph.com/studio/subgraph/$subgraph_name"
            echo ""
            echo "To test queries, use the Graph Studio playground"
            ;;
    esac
    
    echo ""
    echo "Next steps:"
    echo "1. Wait for indexing to complete"
    echo "2. Test queries using the test scripts"
    echo "3. Trigger some contract events to verify indexing"
}

# Main execution
main() {
    # Parse arguments
    NETWORK=""
    START_INFRA="false"
    FORCE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            localhost|sepolia|mainnet)
                NETWORK="$1"
                shift
                ;;
            --start-infra)
                START_INFRA="true"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check if network is specified
    if [ -z "$NETWORK" ]; then
        error "No network specified"
        show_usage
        exit 1
    fi
    
    echo "🚀 Subgraph Deployment Script"
    echo "============================="
    echo "Network: $NETWORK"
    echo "Start Infrastructure: $START_INFRA"
    echo "Force Recreate: $FORCE"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Start infrastructure if requested
    if [ "$START_INFRA" = "true" ]; then
        start_infrastructure
    fi
    
    # Prepare subgraph configuration
    SUBGRAPH_NAME=$(prepare_subgraph_config "$NETWORK")
    
    # Install dependencies
    install_dependencies
    
    # Build subgraph
    build_subgraph
    
    # Deploy subgraph
    deploy_subgraph "$NETWORK" "$SUBGRAPH_NAME" "$FORCE"
    
    # Wait for indexing
    wait_for_indexing "$NETWORK" "$SUBGRAPH_NAME"
    
    # Show deployment info
    show_deployment_info "$NETWORK" "$SUBGRAPH_NAME"
}

# Run main function
main "$@"
