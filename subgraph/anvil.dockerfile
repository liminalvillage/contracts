FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Foundry
RUN curl -L https://foundry.paradigm.xyz | bash
RUN /root/.foundry/bin/foundryup

# Add Foundry to PATH
ENV PATH="/root/.foundry/bin:${PATH}"

# Expose port
EXPOSE 8545

# Start Anvil with optimized settings for faster syncing
CMD ["anvil", "--host", "0.0.0.0", "--port", "8545", "--fork-url", "https://rpc.flashbots.net/", "--gas-limit", "100000000", "--block-time", "1", "--gas-price", "1000000000"]