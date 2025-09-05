# Holons Subgraph Query Documentation

## Quick Start

**Subgraph Endpoint:** `http://localhost:8000/subgraphs/name/holons-local`

**GraphiQL Interface:** `http://localhost:8000/graphql`

---

## Basic Queries

### 1. Check Subgraph Health
```graphql
{
  _meta {
    block {
      number
    }
  }
}
```

### 2. Schema Introspection
```graphql
{
  __schema {
    types {
      name
    }
  }
}
```

---

## Holon Queries

### 3. Get All Holon Contracts
```graphql
{
  holonContracts {
    id
    name
    creator
    flavor
    createdAt
  }
}
```

### 4. Get Holon Creation Events
```graphql
{
  newHolons {
    id
    name
    addr
    flavor
    creator
    blockNumber
    blockTimestamp
  }
}
```

### 5. Get Holon with Child Contracts
```graphql
{
  holonContracts {
    id
    name
    creator
    flavor
    createdAt
    childContracts {
      id
      name
      address
      contractType
    }
  }
}
```

---

## Child Contract Queries

### 6. Get All Child Contracts
```graphql
{
  childContracts {
    id
    name
    address
    contractType
    parent {
      id
      name
    }
  }
}
```

### 7. Get Child Contracts by Type
```graphql
{
  childContracts(where: { contractType: "managed" }) {
    id
    name
    address
    parent {
      id
      name
    }
  }
}
```

---

## Flavor Queries

### 8. Get All Flavors
```graphql
{
  newFlavors {
    id
    flavor
    name
    blockNumber
    blockTimestamp
  }
}
```

---

## Reward Queries

### 9. Get Reward Distributions
```graphql
{
  rewardDistributions {
    id
    contractAddress
    amount
    totalMembers
    rewardType
    blockNumber
    holon {
      id
      name
    }
  }
}
```

### 10. Get Member Rewards
```graphql
{
  memberRewards {
    id
    from
    to
    amount
    isContract
    rewardType
    blockNumber
    holon {
      id
      name
    }
  }
}
```

---

## Event Queries

### 11. Get Funds Forwarded Events
```graphql
{
  fundsForwardeds {
    id
    from
    to
    token
    amount
    blockNumber
  }
}
```

### 12. Get Child Reward Triggered Events
```graphql
{
  childRewardTriggereds {
    id
    parent
    child
    token
    amount
    blockNumber
  }
}
```

---

## Advanced Queries

### 13. Get Holon with All Related Data
```graphql
{
  holonContracts {
    id
    name
    creator
    flavor
    createdAt
    childContracts {
      id
      name
      address
      contractType
    }
    rewardDistributions {
      id
      amount
      rewardType
    }
  }
}
```

### 14. Get Recent Events (Last 10)
```graphql
{
  newHolons(first: 10, orderBy: blockTimestamp, orderDirection: desc) {
    id
    name
    addr
    creator
    blockTimestamp
  }
}
```

### 15. Get Events by Block Range
```graphql
{
  newHolons(where: { blockNumber_gte: "100", blockNumber_lte: "200" }) {
    id
    name
    addr
    blockNumber
  }
}
```

---

## Filtering and Pagination

### 16. Filter by Creator Address
```graphql
{
  holonContracts(where: { creator: "0x90f79bf6eb2c4f870365e785982e1f101e93b906" }) {
    id
    name
    creator
  }
}
```

### 17. Paginated Results
```graphql
{
  holonContracts(first: 5, skip: 10, orderBy: createdAt, orderDirection: desc) {
    id
    name
    createdAt
  }
}
```

---

## Analytics Queries

### 18. Count Total Holons
```graphql
{
  holonContracts {
    id
  }
}
```
*Count the results in your application*

### 19. Get Holon Statistics
```graphql
{
  holonContracts {
    id
    name
    childContracts {
      id
    }
    rewardDistributions {
      id
      amount
    }
  }
}
```

---

## Troubleshooting Queries

### 20. Check for Errors
```graphql
{
  _meta {
    hasIndexingErrors
    block {
      number
    }
  }
}
```

### 21. Get Latest Block
```graphql
{
  _meta {
    block {
      number
      hash
    }
  }
}
```

---

## Usage Examples

### cURL Example
```bash
curl -X POST http://localhost:8000/subgraphs/name/holons-local \
  -H "Content-Type: application/json" \
  -d '{"query": "{ holonContracts { id name creator } }"}'
```

### JavaScript Example
```javascript
const response = await fetch('http://localhost:8000/subgraphs/name/holons-local', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    query: `{
      holonContracts {
        id
        name
        creator
      }
    }`
  })
});
const data = await response.json();
```

---

## Common Use Cases

1. **List all holons** → Query #3
2. **Find holon by name** → Query #16 with name filter
3. **Get holon's child contracts** → Query #5
4. **Check recent activity** → Query #14
5. **Monitor rewards** → Query #9
6. **Track member activity** → Query #10

---

## Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `id` | Bytes | Contract address |
| `name` | String | Human-readable name |
| `creator` | Bytes | Creator's address |
| `flavor` | String | Contract flavor type |
| `createdAt` | BigInt | Creation timestamp |
| `contractType` | String | "managed" or "zoned" |
| `amount` | BigInt | Reward amount |
| `rewardType` | String | Type of reward |

---

## Quick Reference Commands

### Check Subgraph Status
```bash
cd contracts
./ops_scripts/quick-status.sh
```

### Run Full Test Suite
```bash
cd contracts
./ops_scripts/test-subgraph-queries.sh
```

### Monitor Sync Progress
```bash
docker logs subgraph-graph-node-1 -f
```

---

## Network-Specific Endpoints

### Local Development
- **Subgraph:** `http://localhost:8000/subgraphs/name/holons-local`
- **GraphiQL:** `http://localhost:8000/graphql`

### Production (when deployed)
- **Subgraph:** `https://api.thegraph.com/subgraphs/name/holons/holons`
- **GraphiQL:** `https://api.thegraph.com/subgraphs/name/holons/holons`

---

## Troubleshooting

### Common Issues

1. **Subgraph not syncing**
   - Check if Graph Node is running: `docker-compose ps`
   - Monitor logs: `docker logs subgraph-graph-node-1 -f`

2. **No data returned**
   - Verify subgraph is deployed: Check endpoint accessibility
   - Check if contracts are deployed on the target network
   - Ensure subgraph is synced to latest blocks

3. **Query errors**
   - Verify field names match schema
   - Check GraphiQL interface for schema documentation
   - Use schema introspection query (#2) to explore available fields

### Performance Tips

1. **Use pagination** for large datasets (Query #17)
2. **Filter results** to reduce data transfer (Query #16)
3. **Select only needed fields** to minimize response size
4. **Use block ranges** for historical queries (Query #15)

---

*Last updated: August 29, 2025*
