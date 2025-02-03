# Use the official Foundry image
FROM ghcr.io/foundry-rs/foundry:latest

# Set working directory (optional but clean)
WORKDIR /anvil

# Set the entry point to run Anvil ( if it's a fork )
# ENTRYPOINT ["anvil", "--fork-url", "https://rpc.flashbots.net/", "--host", "0.0.0.0", "-vvvv"]

# Set the entry point to run Anvil ( if it's not a fork )
# ENTRYPOINT ["anvil", "--host", "0.0.0.0", "-vvvv"]

# We were still seeing the reorgs with the previous solution ^
ENTRYPOINT ["anvil", "--host", "0.0.0.0", "--block-time", "2", "--chain-id", "1"]