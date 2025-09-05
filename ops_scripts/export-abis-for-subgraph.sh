#!/bin/bash

# Create abis directory if it doesn't exist
mkdir -p subgraph/abis

# Export ABIs using forge inspect
echo "Exporting ABIs..."

forge inspect src/Holons.sol:Holons abi > subgraph/abis/Holons.json
forge inspect src/Splitter.sol:Splitter abi > subgraph/abis/Splitter.json
forge inspect src/Managed.sol:Managed abi > subgraph/abis/Managed.json
forge inspect src/Zoned.sol:Zoned abi > subgraph/abis/Zoned.json

echo "ABIs exported to subgraph/abis/"

# Verify the ABIs were created successfully
echo "Verifying ABIs..."
for abi_file in subgraph/abis/*.json; do
    if [ -f "$abi_file" ]; then
        echo "✓ $(basename "$abi_file")"
    else
        echo "✗ Missing: $(basename "$abi_file")"
    fi
done

# Optional: Show file sizes to verify they're not empty
echo ""
echo "ABI file sizes:"
ls -lh subgraph/abis/*.json

echo ""
echo "ABIs are ready for subgraph use!"