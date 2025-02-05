## Setup Instructions for local Holons subgraph

### 1. Pull the Repository
```sh
 git clone https://github.com/liminalvillage/contracts
```

### 2. Install Dependencies
- Make sure that you have `foundry` installed (inside the `contracts` directory)
- Ensure that you are in the `subgraph` directory

### 3. Start Docker Services
```sh
docker compose up
```

### 4. Register the Graph
```sh
graph codegen
graph build
```

```sh
curl -H "Content-Type: application/json" \  
     --data '{"jsonrpc":"2.0","method":"subgraph_create","params":{"name":"holons-local"},"id":"1"}' \  
     http://127.0.0.1:8020/
```

```sh
graph deploy --node http://localhost:8020/ holons-local
```

#### Verify Deployment
Visit [GraphQL Playground](http://localhost:8030/graphql/playground) and run the following query:
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

##### Example Response:
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

### 5. Deploy Contracts

- Add variables to the `.env` file (refer to `.env.example`)
- Ensure you are in the `contracts` directory
- Run the deployment script:
```sh
NETWORK_NAME=localhost forge script script/Deploy.s.sol:Deploy --rpc-url http://0.0.0.0:8545 --broadcast -vvvv --legacy --skip-simulation
```

- Get the deployed contract addresses from the log and format them as follows:
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

Replace the current set of addresses in the `HolonsBot` repository ([HolonsBot](https://github.com/liminalvillage/HolonsBot)) under `contracts/deployment.json`.

### 6. Verify Deployment
Visit [GraphQL Query](http://localhost:8000/subgraphs/name/holons-local/) and execute the following query:
```graphql
{
  newFlavors(first: 10, orderBy: blockTimestamp, orderDirection: desc) {
    id
    flavor
    name
    blockNumber
    blockTimestamp
    transactionHash
  }
}
```

#### Expected Response:
```json
{
  "data": {
    "newFlavors": [
      {
        "id": "0x9d543e4dfeffab306cbe253090042984ad33b215c95f3d53f483f39dcf2f981800000000",
        "flavor": "0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9",
        "name": "Managed",
        "blockNumber": "3358",
        "blockTimestamp": "1738678222",
        "transactionHash": "0x9d543e4dfeffab306cbe253090042984ad33b215c95f3d53f483f39dcf2f9818"
      }
    ]
  }
}
```

### 7. Testing Distribution via Telegram Bot

- Clone [HolonsBot Repository](https://github.com/liminalvillage/HolonsBot)
- Generate an API key via `@BotFather` on Telegram
- Add variables to the `.env` file
- Start the bot:
```sh
npm run start
```

- Create a new Telegram group and add the bot
- Send `join` in the group chat
- Send `create holon Managed confirm` to create a Holon smart contract
- Verify deployment:
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

##### Expected Response:
```json
{
  "data": {
    "holonContracts": [
      {
        "id": "0x61c36a8d610163660e21a8b7359e1cac0c9133e1",
        "name": "-4640118763",
        "creator": "0x70997970c51812dc3a010c7d01b50e0d17dc79c8",
        "createdAt": "1738679450"
      }
    ]
  }
}
```

- Send `/addmembers` in the group chat
- Modify `script/SendTestTokenToHolons.s.sol` to update `holonsContractAddress` and `testTokenAddress`
- Export the private key from HolonsBot `.env` file:
```sh
export PRIVATE_KEY=<PrivateKeyThatYouSet>
```
- Run the script to send test tokens:
```sh
forge script script/SendTestTokenToHolon.s.sol:SendTestTokenToHolon --rpc-url http://0.0.0.0:8545 --broadcast --legacy --skip-simulation
```

- Verify token balance:
```sh
tokenbalance <TestTokenAddress>
```
- Reward tokens:
```sh
reward <TestTokenAddress> 10
```
- Claim rewards:
```sh
claim <yourAddress>
```

### 8. Verify Indexing
```graphql
{
  rewardDistributions(where: { holon: "0x61c36a8d610163660E21a8b7359e1Cac0C9133e1" }) {
    amount
    rewardType
  }
  memberRewards(where: { holon: "0x61c36a8d610163660E21a8b7359e1Cac0C9133e1" }) {
    from
    to
    amount
    rewardType
  }
}
```

#### Expected Response:
```json
{
  "data": {
    "rewardDistributions": [
      {
        "amount": "1000000000000000000",
        "rewardType": "ERC20"
      }
    ]
  }
}
```
From the response we can see that the amount was first stored for the user ( STORED_ERC20 ) before the claim of funds happened ( ERC20 )