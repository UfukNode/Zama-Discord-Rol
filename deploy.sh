#!/bin/bash

# Renk tanımlamaları
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${PURPLE}=================================================${NC}"
echo -e "${PURPLE}  Bu Script UFUKDEGEN Tarafından Hazırlanmıştır  ${NC}"
echo -e "${PURPLE}=================================================${NC}"
echo ""

echo -e "\n${BLUE}[ZAMA SETUP]${NC} ${GREEN}Sıfırdan kurulum ve deploy başlatılıyor...${NC}"
# ---------------------
# 1. GÜNCELLEME & KÜTÜPHANELER
# ---------------------
echo -e "\n${YELLOW}[1/8] Sistem güncelleniyor ve kütüphaneler kuruluyor...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git build-essential jq make gcc nano lz4 unzip wget pkg-config libssl-dev liblz4-tool tmux
# ---------------------
# 2. NODE.JS ve YARN
# ---------------------
echo -e "\n${YELLOW}[2/8] Node.js kuruluyor...${NC}"
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
npm install -g yarn
# ---------------------
# 3. HARDHAT KURULUMU
# ---------------------
echo -e "\n${YELLOW}[3/8] Hardhat küresel kurulumu...${NC}"
npm install -g hardhat
# ---------------------
# 4. PROJE KLONLAMA
# ---------------------
echo -e "\n${YELLOW}[4/8] Zama FHE template klonlanıyor...${NC}"
git clone https://github.com/zama-ai/fhevm-hardhat-template zama-deploy
cd zama-deploy || exit 1
# ---------------------
# 5. DEPENDENCY KURULUMU
# ---------------------
echo -e "\n${YELLOW}[5/8] Proje bağımlılıkları yükleniyor...${NC}"
npm install
# ---------------------
# 6. HARDHAT CONFIG OLUŞTURMA
# ---------------------
echo -e "\n${YELLOW}[6/8] hardhat.config.ts oluşturuluyor...${NC}"
cat > hardhat.config.ts << 'EOF'
import "@fhevm/hardhat-plugin";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "hardhat-deploy";
import "hardhat-gas-reporter";
import type { HardhatUserConfig } from "hardhat/config";
import { vars } from "hardhat/config";
import "solidity-coverage";
import "dotenv/config";
import "./tasks/accounts";
import "./tasks/FHECounter";

// Load environment variables
const MNEMONIC: string = vars.get("MNEMONIC", "test test test test test test test test test test test junk");
const PRIVATE_KEY: string = vars.get("PRIVATE_KEY", "");
const ETHERSCAN_API_KEY: string = vars.get("ETHERSCAN_API_KEY", "");
const SEPOLIA_RPC_URL: string = vars.get("SEPOLIA_RPC_URL");

// Validate required environment variables
if (!SEPOLIA_RPC_URL) {
  throw new Error("SEPOLIA_RPC_URL is not set in .env file");
}
if (!PRIVATE_KEY) {
  throw new Error("PRIVATE_KEY is not set in .env file");
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: 0,
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_API_KEY,
    },
  },
  gasReporter: {
    currency: "USD",
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic: MNEMONIC,
      },
      chainId: 31337,
    },
    anvil: {
      accounts: {
        mnemonic: MNEMONIC,
        path: "m/44'/60'/0'/0/",
        count: 10,
      },
      chainId: 31337,
      url: "http://localhost:8545",
    },
    sepolia: {
      accounts: [`0x${PRIVATE_KEY}`],
      chainId: 11155111,
      url: SEPOLIA_RPC_URL,
    },
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.24",
    settings: {
      metadata: {
        bytecodeHash: "none",
      },
      optimizer: {
        enabled: true,
        runs: 800,
      },
      evmVersion: "cancun",
    },
  },
  typechain: {
    outDir: "types",
    target: "ethers-v6",
  },
};

export default config;
EOF
# ---------------------
# 7. RPC & PRIVATE KEY AYARI
# ---------------------
echo -e "\n${YELLOW}[7/8] RPC ve Private Key ayarlanıyor...${NC}"
read -p "$(echo -e ${BLUE}Sepolia RPC URL gir ${NC}[default: https://ethereum-sepolia-rpc.publicnode.com]: )" RPC_URL
RPC_URL=${RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}
read -p "$(echo -e ${BLUE}Private Key gir ${RED}[başında 0x OLMADAN]${NC}: )" PRIVATE_KEY
echo -e "\n${GREEN}Hardhat CLI değişkenleri ayarlanıyor...${NC}"
npx hardhat vars set SEPOLIA_RPC_URL "$RPC_URL"
npx hardhat vars set PRIVATE_KEY "$PRIVATE_KEY"
# ---------------------
# 8. DERLEME & DEPLOY
# ---------------------
echo -e "\n${YELLOW}[8/8] Derleniyor...${NC}"
npx hardhat compile
echo -e "\n${PURPLE}Deploy işlemi başlıyor...${NC}"
npx hardhat deploy --network sepolia
echo -e "\n${GREEN}=================================================${NC}"
echo -e "${GREEN}Kurulum ve deploy tamamlandı!${NC}"
echo -e "${GREEN}Yukarıda kontrat adresini görebilirsiniz.${NC}"
echo -e "${GREEN}=================================================${NC}"
