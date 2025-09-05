#!/bin/bash

# Local Subgraph Setup Script
# This script automates the complete process of setting up and deploying a subgraph locally

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
DEPLOYMENT_FILE="$CONTRACTS_DIR/deployment/deployment.json"

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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command_exists docker; then
        error "Docker is not installed"
        exit 1
    fi
    
    if ! command_exists docker-compose; then
        error "Docker Compose is not installed"
        exit 1
    fi
    
    if ! command_exists jq; then
        error "jq is not installed"
        exit 1
    fi
    
    if ! command_exists npm; then
        error "npm is not installed"
        exit 1
    fi
    
    success "All prerequisites are installed"
}

# Function to start Graph Node infrastructure
start_graph_node() {
    log "Starting Graph Node infrastructure..."
    
    cd "$SUBGRAPH_DIR"
    
    # Kill any processes using port 8545
    if lsof -ti:8545 >/dev/null 2>&1; then
        log "Killing processes on port 8545..."
        lsof -ti:8545 | xargs kill -9
    fi
    
    # Start Graph Node
    docker-compose up -d
    
    # Wait for services to be ready
    log "Waiting for Graph Node to start up..."
    sleep 60
    
    # Check if services are running
    if ! docker ps | grep -q "subgraph-graph-node"; then
        error "Graph Node failed to start"
        exit 1
    fi
    
    success "Graph Node infrastructure is running"
}

# Function to deploy contracts
deploy_contracts() {
    log "Deploying contracts to localhost..."
    
    cd "$CONTRACTS_DIR"
    
    if [ ! -f "./ops_scripts/deploy-contracts.sh" ]; then
        error "Deploy contracts script not found"
        exit 1
    fi
    
    ./ops_scripts/deploy-contracts.sh localhost
    
    success "Contracts deployed successfully"
}

# Function to update subgraph configuration
update_subgraph_config() {
    log "Updating subgraph configuration..."
    
    cd "$CONTRACTS_DIR"
    
    if [ ! -f "./ops_scripts/update-subgraph-from-deployment.sh" ]; then
        error "Update subgraph script not found"
        exit 1
    fi
    
    ./ops_scripts/update-subgraph-from-deployment.sh localhost
    
    success "Subgraph configuration updated"
}

# Function to build subgraph
build_subgraph() {
    log "Building subgraph..."
    
    cd "$SUBGRAPH_DIR"
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        log "Installing npm dependencies..."
        npm install
    fi
    
    # Generate code
    log "Generating GraphQL code..."
    npm run codegen
    
    # Build subgraph
    log "Building subgraph..."
    npm run build
    
    success "Subgraph built successfully"
}

# Function to deploy subgraph
deploy_subgraph() {
    log "Deploying subgraph..."
    
    cd "$SUBGRAPH_DIR"
    
    # Remove existing subgraph if it exists
    if graph list --node http://localhost:8020/ | grep -q "holons-local"; then
        log "Removing existing subgraph..."
        npm run remove-local || true
    fi
    
    # Create new subgraph
    log "Creating new subgraph..."
    npm run create-local
    
    # Deploy subgraph
    log "Deploying subgraph..."
    graph deploy --node http://localhost:8020/ --ipfs http://localhost:5001 holons-local --version-label v0.0.1
    
    success "Subgraph deployed successfully"
}

# Function to wait for indexing
wait_for_indexing() {
    log "Waiting for subgraph to start indexing..."
    
    # Wait for indexing to begin
    sleep 30
    
    # Check if subgraph is indexing
    log "Checking indexing status..."
    
    # Try a simple query to see if it's working
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Attempt $attempt/$max_attempts: Testing subgraph query..."
        
        response=$(curl -s -X POST http://localhost:8000/subgraphs/name/holons-local \
            -H "Content-Type: application/json" \
            -d '{"query": "{ _meta { block { number } } }"}' 2>/dev/null || echo "error")
        
        if echo "$response" | grep -q "data"; then
            success "Subgraph is responding to queries!"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log "Subgraph not ready yet, waiting 30 seconds..."
            sleep 30
        fi
        
        attempt=$((attempt + 1))
    done
    
    warning "Subgraph may still be indexing. You can check manually with:"
    echo "  curl -X POST http://localhost:8000/subgraphs/name/holons-local \\"
    echo "    -H \"Content-Type: application/json\" \\"
    echo "    -d '{\"query\": \"{ newHolons { id name addr creator } }\"}'"
}

# Function to test the subgraph
test_subgraph() {
    log "Testing subgraph queries..."
    
    echo ""
    echo "=== Testing NewHolon Events ==="
    curl -X POST http://localhost:8000/subgraphs/name/holons-local \
        -H "Content-Type: application/json" \
        -d '{"query": "{ newHolons { id name addr creator } }"}' | jq .
    
    echo ""
    echo "=== Testing NewFlavor Events ==="
    curl -X POST http://localhost:8000/subgraphs/name/holons-local \
        -H "Content-Type: application/json" \
        -d '{"query": "{ newFlavors { id flavor name } }"}' | jq .
    
    echo ""
    echo "=== Testing HolonContract Entities ==="
    curl -X POST http://localhost:8000/subgraphs/name/holons-local \
        -H "Content-Type: application/json" \
        -d '{"query": "{ holonContracts { id name addr creator } }"}' | jq .
    
    success "Subgraph testing completed"
}

# Function to show status
show_status() {
    log "Current status:"
    echo ""
    echo "=== Graph Node Infrastructure ==="
    docker ps | grep subgraph || echo "No subgraph containers running"
    
    echo ""
    echo "=== Subgraph Endpoints ==="
    echo "GraphQL: http://localhost:8000/subgraphs/name/holons-local"
    echo "Status:  http://localhost:8000/subgraphs/name/holons-local"
    
    echo ""
    echo "=== Useful Commands ==="
    echo "View logs: docker logs subgraph-graph-node-1 -f"
    echo "Stop:     docker-compose down"
    echo "Restart:  docker-compose restart"
}

# Main execution
main() {
    echo "🚀 Local Subgraph Setup Script"
    echo "================================"
    echo ""
    
    # Check if we're in the right directory
    if [ ! -f "$CONTRACTS_DIR/ops_scripts/deploy-contracts.sh" ]; then
        error "Please run this script from the contracts directory"
        exit 1
    fi
    
    # Parse command line arguments
    case "${1:-all}" in
        "prerequisites")
            check_prerequisites
            ;;
        "start-infra")
            start_graph_node
            ;;
        "deploy-contracts")
            deploy_contracts
            ;;
        "update-config")
            update_subgraph_config
            ;;
        "build")
            build_subgraph
            ;;
        "deploy")
            deploy_subgraph
            ;;
        "wait")
            wait_for_indexing
            ;;
        "test")
            test_subgraph
            ;;
        "status")
            show_status
            ;;
        "all")
            log "Running complete setup..."
            check_prerequisites
            start_graph_node
            deploy_contracts
            update_subgraph_config
            build_subgraph
            deploy_subgraph
            wait_for_indexing
            test_subgraph
            show_status
            ;;
        *)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  prerequisites  - Check if all required tools are installed"
            echo "  start-infra    - Start Graph Node infrastructure"
            echo "  deploy-contracts - Deploy contracts to localhost"
            echo "  update-config  - Update subgraph configuration"
            echo "  build          - Build the subgraph"
            echo "  deploy         - Deploy the subgraph"
            echo "  wait           - Wait for indexing to complete"
            echo "  test           - Test subgraph queries"
            echo "  status         - Show current status"
            echo "  all            - Run complete setup (default)"
            echo ""
            echo "Examples:"
            echo "  $0 all                    # Run complete setup"
            echo "  $0 deploy-contracts       # Deploy only contracts"
            echo "  $0 test                   # Test only queries"
            exit 1
            ;;
    esac
    
    success "Script completed successfully!"
}

# Run main function
main "$@"

