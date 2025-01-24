# Use the official Foundry image
FROM ghcr.io/foundry-rs/foundry:latest

# Set working directory (optional but clean)
WORKDIR /anvil

# Set the entry point to run Anvil
ENTRYPOINT ["anvil", "--fork-url", "https://rpc.flashbots.net/", "--host", "0.0.0.0", "-vvvv"]
