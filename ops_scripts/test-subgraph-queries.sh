#!/bin/bash

# Test Subgraph Queries Script
# This script tests various queries against the local subgraph

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SUBGRAPH_URL="http://localhost:8000/subgraphs/name/holons-local"

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

# Function to test a query
test_query() {
    local name="$1"
    local query="$2"
    
    log "Testing: $name"
    echo "Query: $query"
    echo "Response:"
    
    response=$(curl -s -X POST "$SUBGRAPH_URL" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$query\"}")
    
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo ""
    echo "----------------------------------------"
    echo ""
}

# Function to test a query and show count
test_query_with_count() {
    local name="$1"
    local query="$2"
    local count_query="$3"
    
    log "Testing: $name"
    echo "Query: $query"
    echo "Response:"
    
    response=$(curl -s -X POST "$SUBGRAPH_URL" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$query\"}")
    
    echo "$response" | jq . 2>/dev/null || echo "$response"
    
    # Show count if count query provided
    if [ -n "$count_query" ]; then
        count_response=$(curl -s -X POST "$SUBGRAPH_URL" \
            -H "Content-Type: application/json" \
            -d "{\"query\": \"$count_query\"}")
        count=$(echo "$count_response" | jq -r '.data[0].count // 0' 2>/dev/null || echo "0")
        echo ""
        echo "📊 Count: $count"
    fi
    
    echo ""
    echo "----------------------------------------"
    echo ""
}

# Main execution
main() {
    echo "🧪 Subgraph Query Testing"
    echo "========================="
    echo ""
    
    # Check if subgraph is accessible
    log "Checking if subgraph is accessible..."
    
    if ! curl -s "$SUBGRAPH_URL" >/dev/null 2>&1; then
        error "Subgraph is not accessible at $SUBGRAPH_URL"
        echo "Make sure the Graph Node is running and the subgraph is deployed."
        exit 1
    fi
    
    success "Subgraph is accessible"
    echo ""
    
    # System Status Queries
    test_query "Schema Introspection" "{ __schema { types { name } } }"
    
    test_query "Meta Information (Current Block)" "{ _meta { block { number } } }"
    
    # Event Queries
    test_query_with_count "NewHolon Events" "{ newHolons { id name addr flavor creator blockNumber blockTimestamp } }" "{ newHolons { id } }"
    
    test_query_with_count "NewFlavor Events" "{ newFlavors { id flavor name blockNumber } }" "{ newFlavors { id } }"
    
    # Entity Queries
    test_query_with_count "HolonContract Entities" "{ holonContracts { id name creator flavor createdAt } }" "{ holonContracts { id } }"
    
    test_query_with_count "ChildContract Entities" "{ childContracts { id name address contractType parent { id name } } }" "{ childContracts { id } }"
    
    # Reward Queries
    test_query_with_count "RewardDistribution Events" "{ rewardDistributions { id contractAddress amount totalMembers rewardType blockNumber } }" "{ rewardDistributions { id } }"
    
    test_query_with_count "MemberReward Events" "{ memberRewards { id from to amount isContract rewardType blockNumber } }" "{ memberRewards { id } }"
    
    # Other Event Queries
    test_query_with_count "FundsForwarded Events" "{ fundsForwardeds { id from to token amount blockNumber } }" "{ fundsForwardeds { id } }"
    
    test_query_with_count "ChildRewardTriggered Events" "{ childRewardTriggereds { id parent child token amount blockNumber } }" "{ childRewardTriggereds { id } }"
    
    # Summary
    echo ""
    success "All queries tested!"
    echo ""
    echo "💡 Quick Status Check:"
    echo "  - Run this script anytime to check subgraph health"
    echo "  - Check counts to see if new data is being indexed"
    echo "  - Monitor block numbers to ensure sync is up to date"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "  - If queries return empty results, the subgraph may still be indexing"
    echo "  - Check logs with: docker logs subgraph-graph-node-1 -f"
    echo "  - Create more events by interacting with your contracts"
    echo ""
    echo "📊 Quick Commands:"
    echo "  - Check sync: curl -X POST $SUBGRAPH_URL -H 'Content-Type: application/json' -d '{\"query\": \"{ _meta { block { number } } }\"}'"
    echo "  - Count holons: curl -X POST $SUBGRAPH_URL -H 'Content-Type: application/json' -d '{\"query\": \"{ holonContracts { id } }\"}' | jq '.data.holonContracts | length'"
}

# Run main function
main "$@"

