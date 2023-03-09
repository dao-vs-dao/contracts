import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
import "hardhat-deploy";
import "@typechain/hardhat";
import "solidity-coverage";
import { HardhatUserConfig } from "hardhat/types";

require("dotenv").config({ path: ".env" });

const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY!;
const NODE_PROVIDER_MATIC_RPC_URL = process.env.NODE_PROVIDER_MATIC_RPC_URL;
const NODE_PROVIDER_MUMBAI_RPC_URL = process.env.NODE_PROVIDER_MUMBAI_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY!;

const config: HardhatUserConfig & { etherscan: any } = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 137 // fake Polygon chain for testing purposes
    },
    matic: {
      url: NODE_PROVIDER_MATIC_RPC_URL || "https://matic-mainnet.chainstacklabs.com",
      accounts: [PRIVATE_KEY],
      timeout: 120000
    },
    mumbai: {
      url: NODE_PROVIDER_MUMBAI_RPC_URL || "https://matic-mumbai.chainstacklabs.com",
      accounts: [PRIVATE_KEY],
      timeout: 120000
    }
  },
  etherscan: {
    apiKey: {
      polygon: POLYGONSCAN_API_KEY,
      polygonMumbai: POLYGONSCAN_API_KEY
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: { optimizer: { enabled: true, runs: 100 }, viaIR: true }
      }
    ]
  }
};

export default config;
