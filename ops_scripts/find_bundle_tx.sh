# Create the script
cat > find_bundle_tx.sh << 'EOF'
#!/bin/bash

BUNDLE_ADDR="0xff406De64b14E23E363B605A0D30aC9dd2860f98"
MANAGED_ADDR="0x036CcB7466Bb88d7958aC8B215B4DAf0dBf66ef4"
ZONED_ADDR="0xD3F3e6801fd0d35FdB7d859402eABD61b69EfEA6"

echo "Searching for transactions involving your bundle addresses..."
echo "Bundle: $BUNDLE_ADDR"
echo "Managed: $MANAGED_ADDR"
echo "Zoned: $ZONED_ADDR"
echo ""

for i in {1400..1500}; do
  block_hex=$(printf '0x%x' $i)
  result=$(curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$block_hex\",true],\"id\":1}")
  
  # Check if any transaction involves our addresses
  if echo "$result" | grep -q "$BUNDLE_ADDR\|$MANAGED_ADDR\|$ZONED_ADDR"; then
    echo "Found relevant transaction in block $i:"
    echo "$result" | jq '.result.transactions[] | select(.to == "'$BUNDLE_ADDR'" or .to == "'$MANAGED_ADDR'" or .to == "'$ZONED_ADDR'") | {hash: .hash, to: .to, from: .from, input: .input[0:10]}'
    echo ""
  fi
done
EOF