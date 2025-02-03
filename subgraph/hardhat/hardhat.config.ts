import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20", // Updated version
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // Adjust if needed
      },
      viaIR: true, // Enables IR-based optimization
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
      mining: {
        auto: true,
        interval: 1000,
      },
    },
    local: {
      url: "http://localhost:8545",
      chainId: 31337
    }
  },
};

export default config;
