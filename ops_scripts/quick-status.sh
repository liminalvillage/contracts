#!/bin/bash

# Quick Subgraph Status Script
# Fast overview of subgraph health and data

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SUBGRAPH_URL="http://localhost:8000/subgraphs/name/holons-local"

# Logging functions
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to get count
get_count() {
    local query="$1"
    local response=$(curl -s -X POST "$SUBGRAPH_URL" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$query\"}")
    echo "$response" | jq -r '.data | length // 0' 2>/dev/null || echo "0"
}

# Function to get block number
get_block() {
    local response=$(curl -s -X POST "$SUBGRAPH_URL" \
        -H "Content-Type: application/json" \
        -d '{"query": "{ _meta { block { number } } }"}')
    echo "$response" | jq -r '.data._meta.block.number // 0' 2>/dev/null || echo "0"
}

# Main execution
main() {
    echo "🚀 Subgraph Quick Status"
    echo "========================"
    echo ""
    
    # Check accessibility
    if ! curl -s "$SUBGRAPH_URL" >/dev/null 2>&1; then
        error "Subgraph not accessible"
        exit 1
    fi
    
    success "Subgraph is running"
    echo ""
    
    # Get current block
    current_block=$(get_block)
    info "Current Block: $current_block"
    echo ""
    
    # Get counts
    holon_count=$(get_count "{ holonContracts { id } }")
    new_holon_count=$(get_count "{ newHolons { id } }")
    flavor_count=$(get_count "{ newFlavors { id } }")
    child_count=$(get_count "{ childContracts { id } }")
    reward_count=$(get_count "{ rewardDistributions { id } }")
    member_reward_count=$(get_count "{ memberRewards { id } }")
    
    # Display summary
    echo "📊 Data Summary:"
    echo "  Holon Contracts: $holon_count"
    echo "  New Holon Events: $new_holon_count"
    echo "  Flavors: $flavor_count"
    echo "  Child Contracts: $child_count"
    echo "  Reward Distributions: $reward_count"
    echo "  Member Rewards: $member_reward_count"
    echo ""
    
    # Health check
    if [ "$current_block" -gt 0 ]; then
        success "Subgraph is syncing (Block $current_block)"
    else
        warning "Subgraph may not be syncing properly"
    fi
    
    if [ "$holon_count" -gt 0 ]; then
        success "Holon data is being indexed"
    else
        warning "No holon data found"
    fi
    
    echo ""
    echo "💡 Quick Commands:"
    echo "  Full test: ./ops_scripts/test-subgraph-queries.sh"
    echo "  Monitor logs: docker logs subgraph-graph-node-1 -f"
    echo "  GraphiQL: http://localhost:8000/graphql"
}

# Run main function
main "$@"
