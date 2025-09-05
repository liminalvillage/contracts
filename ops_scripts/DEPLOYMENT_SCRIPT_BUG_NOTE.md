# 🐛 DEPLOYMENT SCRIPT BUG - FIX NEEDED

## **Issue Found:**
The `update-subgraph-from-deployment.sh` script incorrectly updates ALL contract addresses in `subgraph.yaml` to the Holons contract address.

## **Problem Location:**
File: `ops_scripts/update-subgraph-from-deployment.sh`
Lines: 95-96

```bash
# ❌ WRONG - This replaces ALL addresses
sed -i "s/address: \"[^\"]*\"/address: \"$HOLONS_ADDRESS\"/g" subgraph.yaml
```

## **What Happens:**
- ✅ Correctly updates Holons contract address
- ❌ **INCORRECTLY** updates ManagedFactory address to Holons address
- ❌ **INCORRECTLY** updates ZonedFactory address to Holons address
- ❌ **INCORRECTLY** updates all other contract addresses to Holons address

## **The Fix:**
Replace the global sed command with a more specific one that only updates the Holons contract:

```bash
# ✅ CORRECT - Only update the Holons contract address
sed -i "/name: Holons/,/abi: Holons/s/address: \"[^\"]*\"/address: \"$HOLONS_ADDRESS\"/" subgraph.yaml
```

## **Alternative Fix:**
Use a more targeted approach by finding the specific line:

```bash
# Find and replace only the Holons contract address
sed -i "/^  - kind: ethereum$/,/^  - kind: ethereum$/ s/address: \"[^\"]*\"/address: \"$HOLONS_ADDRESS\"/" subgraph.yaml
```

## **Why This Matters:**
- Factory contracts need their own addresses for dynamic tracking
- Setting factory addresses to Holons address breaks the subgraph
- The subgraph can't track factory events if addresses are wrong

## **Manual Fix Applied:**
For this deployment, I manually corrected the addresses:
- ManagedFactory: `0x057ef64e23666f000b34ae31332854acbd1c8544`
- ZonedFactory: `0x261d8c5e9742e6f7f1076fa1f560894524e19cad`

## **Next Steps:**
1. Fix the `update-subgraph-from-deployment.sh` script
2. Test the fix with a new deployment
3. Consider adding validation to ensure factory addresses are correct

---
**Date:** $(date)
**Issue Found By:** AI Assistant during full infrastructure redeployment
**Status:** Manual fix applied, script fix pending

