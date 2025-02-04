# Holons Project

This document outlines the steps to set up, deploy, and test the Holons project. It covers repository preparation, graph registration/deployment, smart contract deployment, and testing distribution via the Telegram bot.

## Table of Contents

1. [Repository Setup](#repository-setup)
2. [Graph Registration & Deployment](#graph-registration--deployment)
3. [Contract Deployment](#contract-deployment)
4. [Testing Distribution via Telegram Bot](#testing-distribution-via-telegram-bot)

---

## Repository Setup

1. **Pull the Repository:**

   ```bash
   git clone https://github.com/your-repository-url.git
   ```

2. **Ensure Foundry is Installed:**

   - Verify that you have [`foundry`](https://github.com/foundry-rs/foundry) installed.
   - This step is performed in the `contracts` directory.

3. **Navigate to the Subgraph Directory:**

   ```bash
   cd subgraph
   ```

---

## Graph Registration & Deployment

1. **Start Docker Compose:**

   From within the `subgraph` directory, run:

   ```bash
   docker compose up
   ```

2. **Register the Graph:**

   Run the following commands sequentially:

   - **Generate Graph Code:**

     ```bash
     graph codegen
     ```

   - **Build the Graph:**

     ```bash
     graph build
     ```

   - **Create the Graph:**

     ```bash
     curl -H "Content-Type: application/json" \
          --data '{"jsonrpc":"2.0","method":"subgraph_create","params":{"name":"holons-local"},"id":"1"}' \
          http://127.0.0.1:8020/
     ```

   - **Deploy the Graph:**

     ```bash
     graph deploy --node http://localhost:8020/ holons-local
     ```

3. **Verify Graph Deployment:**

   Open your browser and navigate to [GraphQL Playground](http://localhost:8030/graphql/playground) then run:

   ```graphql
   {
     indexingStatuses {
       subgraph
       chains {
         chainHeadBlock {
           number
         }
         latestBlock {
           number
         }
       }
     }
   }
   ```

   Example Response:

   ```json
   {
     "data": {
       "indexingStatuses": [
         {
           "subgraph": "QmPNm7sshs4cNJmbxKmcbFbvDrhf2CNg3yXXq49mMCNXs7",
           "chains": [
             {
               "chainHeadBlock": {
                 "number": "2795"
               },
               "latestBlock": {
                 "number": "2791"
               }
             }
           ]
         }
       ]
     }
   }
   ```

---

## Contract Deployment

1. **Environment Setup:**

   - Copy the variables from `.env.example` into a new `.env` file.
   - Make sure you are in the `contracts` directory.

2. **Deploy the Contracts:**

   Run the deployment script:

   ```bash
   NETWORK_NAME=localhost forge script script/Deploy.s.sol:Deploy --rpc-url http://0.0.0.0:8545 --broadcast -vvvv --legacy --skip-simulation
   ```

3. **Update Deployment Addresses:**

   Obtain addresses from the log and format them like this:

   ```json
   "localhost": {
     "SplitterFactory": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
     "AppreciativeFactory": "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
     "ZonedFactory": "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
     "ManagedFactory": "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
     "Managed": "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
     "Holons": "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
     "Zoned": "0x0165878A594ca255338adfa4d48449f69242Eb8F",
     "Splitter": "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
     "TestToken": "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6"
   }
   ```

   Replace the current addresses in the [HolonsBot repository](https://github.com/liminalvillage/HolonsBot) (`contracts/deployment.json`).

---

## Testing Distribution via Telegram Bot

1. **Set Up HolonsBot:**

   - Clone the repository:

     ```bash
     git clone https://github.com/liminalvillage/HolonsBot.git
     ```

   - Generate an API key via [@BotFather](https://t.me/BotFather) on Telegram.
   - Populate the `.env` file (refer to `.env.example`).

2. **Start the Bot:**

   ```bash
   npm run start
   ```

3. **Configure Telegram Group:**

   - Create a new group in Telegram and add your bot.
   - Send `join` in the group chat.
   - Send `create holon Managed confirm` to create a holon contract.

4. **Verify Holon Creation:**

   Visit [Subgraph Explorer](http://localhost:8000/subgraphs/name/holons-local/) and run:

   ```graphql
   {
     holonContracts {
       id
       name
       creator
       createdAt
     }
   }
   ```

---

## Final Notes

- **Environment Files:** Ensure all required environment variables are correctly set.
- **Repository Links:** Replace URLs with actual links if they differ.
- **Troubleshooting:** Check logs and review errors if any step fails.

Happy deploying and testing!

