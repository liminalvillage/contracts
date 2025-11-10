# Upgradeable Contracts Guide

## Overview

This repository now supports **upgradeable smart contracts** using the **UUPS (Universal Upgradeable Proxy Standard)** pattern. This allows you to upgrade contract logic while preserving state data and contract addresses.

## Why Upgradeable Contracts?

**Benefits:**
- **Fix Bugs**: Deploy fixes without migrating data
- **Add Features**: Introduce new functionality to existing contracts
- **Optimize Gas**: Improve efficiency of existing operations
- **Preserve Addresses**: Users continue interacting with the same address
- **Maintain State**: All data (balances, members, etc.) is preserved

**Trade-offs:**
- Slightly higher deployment gas costs
- Requires careful upgrade management
- Need to understand proxy patterns

## Architecture

### UUPS Proxy Pattern

```
User → Proxy Contract (stores data) → Implementation Contract (contains logic)
```

**Components:**
1. **Implementation Contract**: Contains the logic (upgradeable)
2. **Proxy Contract**: Stores the data (permanent address)
3. **Factory Contract**: Deploys new proxies

### Separation of Concerns

```
┌─────────────────────────────────────────────────────┐
│                     PROXY                            │
│  - Stores all state variables                       │
│  - Has permanent address                            │
│  - Delegates calls to implementation                │
│  - Users interact with this address                 │
└──────────────────┬──────────────────────────────────┘
                   │ delegatecall
                   ▼
┌─────────────────────────────────────────────────────┐
│              IMPLEMENTATION                          │
│  - Contains business logic                          │
│  - Can be replaced/upgraded                         │
│  - Never directly accessed by users                 │
└─────────────────────────────────────────────────────┘
```

## Contracts Available

### Upgradeable Contracts

All main contracts have been converted to upgradeable versions:

| Original | Upgradeable Version | Description |
|----------|---------------------|-------------|
| `Membrane.sol` | `MembraneUpgradeable.sol` | Base member management |
| `Holon.sol` | `HolonUpgradeable.sol` | Abstract base with UUPS |
| `Managed.sol` | `ManagedUpgradeable.sol` | Appreciation-based distribution |
| `Zoned.sol` | `ZonedUpgradeable.sol` | Zone-based hierarchical distribution |
| `Splitter.sol` | `SplitterUpgradeable.sol` | Main distribution hub |

### Upgradeable Factories

Factory contracts deploy proxies instead of direct instances:

| Factory | Creates |
|---------|---------|
| `ManagedFactoryUpgradeable.sol` | Managed proxies |
| `ZonedFactoryUpgradeable.sol` | Zoned proxies |
| `SplitterFactoryUpgradeable.sol` | Splitter proxies |

## Deployment

### Step 1: Deploy Implementations

Deploy the logic contracts (one per contract type):

```bash
forge script script/DeployUpgradeable.s.sol:DeployUpgradeable --rpc-url $RPC_URL --broadcast
```

This deploys:
- Implementation contracts (ManagedUpgradeable, ZonedUpgradeable, SplitterUpgradeable)
- Factory contracts
- Example proxy instances for testing

### Step 2: Deploy Proxies via Factories

Use factories to create new instances:

```solidity
// Via ManagedFactoryUpgradeable
address managedProxy = managedFactory.createManaged(
    "creator_userId",
    "MyManagedDAO"
);

// Via ZonedFactoryUpgradeable
address zonedProxy = zonedFactory.createZoned(
    "creator_userId",
    "MyZonedDAO",
    6  // number of zones
);

// Via SplitterFactoryUpgradeable
address splitterProxy = splitterFactory.createSplitter(
    "creator_userId",
    "MySplitter",
    0,  // parameter
    managedFactoryAddress,
    zonedFactoryAddress
);
```

## Upgrading Contracts

### When to Upgrade

- **Bug Fixes**: Critical security issues or bugs
- **Feature Additions**: New functionality requested by community
- **Optimizations**: Gas optimizations or performance improvements

### Upgrade Process

#### Option 1: Using the Upgrade Script

```bash
# Set environment variables
export PRIVATE_KEY="0x..."
export PROXY_ADDRESS="0x..."
export CONTRACT_TYPE="managed"  # or "zoned" or "splitter"

# Run upgrade script
forge script script/UpgradeContract.s.sol:UpgradeContract --rpc-url $RPC_URL --broadcast
```

#### Option 2: Manual Upgrade

```solidity
// 1. Deploy new implementation
ManagedUpgradeable newImpl = new ManagedUpgradeable();

// 2. Call upgradeToAndCall on the proxy (as owner)
ManagedUpgradeable proxy = ManagedUpgradeable(proxyAddress);
proxy.upgradeToAndCall(address(newImpl), "");

// 3. Verify upgrade
// The proxy now uses the new implementation logic
```

### Upgrade Safety Checklist

Before upgrading, ensure:

- [ ] New implementation is thoroughly tested
- [ ] Storage layout is compatible (no removed/reordered variables)
- [ ] Initialize functions are protected with `onlyInitializing`
- [ ] Only owner can call `upgradeTo()`
- [ ] Backup proxy state data
- [ ] Test on testnet first
- [ ] Have rollback plan ready

## Storage Layout Compatibility

### ✅ Safe Changes

```solidity
// ✅ Add new variables at the end
contract ManagedUpgradeableV2 is ManagedUpgradeable {
    uint256 public newFeature;  // OK - added at end
}

// ✅ Add new functions
function newFunction() public { ... }  // OK
```

### ❌ Unsafe Changes

```solidity
// ❌ DO NOT remove variables
// uint256 public oldVariable;  // DANGEROUS

// ❌ DO NOT reorder variables
contract Bad {
    uint256 public var2;  // Was var1
    uint256 public var1;  // Was var2  // DANGEROUS
}

// ❌ DO NOT change variable types
// uint128 public amount;  // Was uint256  // DANGEROUS
```

### Storage Gaps

All upgradeable contracts include storage gaps:

```solidity
uint256[50] private __gap;
```

This reserves space for future variables without affecting child contracts.

## Key Differences from Original Contracts

### Constructors → Initializers

**Before:**
```solidity
constructor(address _creator, string memory _name) {
    creator = _creator;
    name = _name;
}
```

**After:**
```solidity
function initialize(address _creator, string memory _name) public initializer {
    __Holon_init(_creator);
    __Managed_init_unchained(_creator, _name);
}
```

### Inheritance Changes

**Before:**
```solidity
contract Managed is Holon {
    // ...
}
```

**After:**
```solidity
contract ManagedUpgradeable is HolonUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    // ...
}
```

### Import Updates

**Before:**
```solidity
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
```

**After:**
```solidity
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
```

## Access Control

### Who Can Upgrade?

Only the **contract owner** can upgrade:

```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
```

### Transferring Ownership

```solidity
// Transfer ownership
contract.changeOwner(newOwnerAddress);
```

## Testing Upgradeable Contracts

### Test Structure

```solidity
import "forge-std/Test.sol";
import "../src/ManagedUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ManagedUpgradeableTest is Test {
    ManagedUpgradeable implementation;
    ManagedUpgradeable proxy;

    function setUp() public {
        // Deploy implementation
        implementation = new ManagedUpgradeable();

        // Deploy proxy
        bytes memory data = abi.encodeWithSelector(
            ManagedUpgradeable.initialize.selector,
            address(this),
            "TestManaged"
        );

        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(implementation),
            data
        );

        proxy = ManagedUpgradeable(address(proxyContract));
    }

    function testUpgrade() public {
        // Deploy new implementation
        ManagedUpgradeable newImpl = new ManagedUpgradeable();

        // Upgrade
        proxy.upgradeToAndCall(address(newImpl), "");

        // Verify state preserved
        assertEq(proxy.name(), "TestManaged");
    }
}
```

### Testing Checklist

- [ ] Test proxy deployment
- [ ] Test initialization
- [ ] Test upgrade process
- [ ] Test state preservation after upgrade
- [ ] Test access control (only owner can upgrade)
- [ ] Test initialization prevention (can't reinitialize)

## Common Patterns

### Reading Proxy State

```solidity
// Interact with proxy as if it's the implementation
ManagedUpgradeable proxy = ManagedUpgradeable(proxyAddress);
string memory name = proxy.name();
uint256 size = proxy.getSize();
```

### Checking Implementation Address

```solidity
// Using ERC1967 standard storage slot
bytes32 IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
address impl = address(uint160(uint256(vm.load(proxyAddress, IMPLEMENTATION_SLOT))));
```

## Troubleshooting

### "Function selector was not recognized"

**Problem**: Calling function that doesn't exist in current implementation

**Solution**: Upgrade to new implementation or use correct function

### "Initializable: contract is already initialized"

**Problem**: Trying to call initialize() twice

**Solution**: Initialization can only happen once. Deploy new proxy if needed.

### "Address: low-level delegate call failed"

**Problem**: Implementation contract has error or wrong address

**Solution**: Check implementation address and ensure it's deployed correctly

### Storage Collision

**Problem**: Variables overwriting each other after upgrade

**Solution**: Follow storage layout compatibility rules. Never remove/reorder variables.

## Best Practices

1. **Always Test Upgrades on Testnet First**
   - Deploy to testnet
   - Perform upgrade
   - Verify all functions work
   - Check state integrity

2. **Document Changes**
   - Keep changelog of what changed
   - Note any breaking changes
   - Update documentation

3. **Use Storage Gaps**
   - Reserve space for future variables
   - Update gap size when adding variables

4. **Emit Events on Upgrade**
   - Log when upgrades happen
   - Include old and new implementation addresses

5. **Timelock Upgrades** (Optional)
   - Add delay before upgrades take effect
   - Gives users time to review changes

## Migration from Non-Upgradeable

If you have existing non-upgradeable contracts:

1. **Deploy New Proxy**: Deploy upgradeable version
2. **Migrate Data**: Transfer state from old to new
3. **Update References**: Point integrations to new address
4. **Deprecate Old**: Mark old contract as deprecated

## Additional Resources

- [OpenZeppelin Upgradeable Contracts](https://docs.openzeppelin.com/contracts/4.x/upgradeable)
- [UUPS Pattern Explanation](https://eips.ethereum.org/EIPS/eip-1822)
- [Proxy Upgrade Pattern](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies)

## Summary

### Files Created

**Contracts:**
- `src/MembraneUpgradeable.sol`
- `src/HolonUpgradeable.sol`
- `src/ManagedUpgradeable.sol`
- `src/ZonedUpgradeable.sol`
- `src/SplitterUpgradeable.sol`

**Factories:**
- `src/ManagedFactoryUpgradeable.sol`
- `src/ZonedFactoryUpgradeable.sol`
- `src/SplitterFactoryUpgradeable.sol`

**Scripts:**
- `script/DeployUpgradeable.s.sol` - Deploy implementations and factories
- `script/UpgradeContract.s.sol` - Upgrade existing proxy

**Documentation:**
- `UPGRADEABLE_CONTRACTS.md` - This guide

---

**Your contracts are now upgradeable!** Data lives in the proxy, logic can be upgraded. 🚀
