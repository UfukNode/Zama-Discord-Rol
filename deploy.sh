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
# 0. SISTEM TEMİZLİK VE HAZIRLIK
# ---------------------
echo -e "\n${YELLOW}[0/8] Sistem temizliği ve hazırlık...${NC}"

# APT kilitleri temizle
echo -e "${GREEN}APT kilitleri kontrol ediliyor...${NC}"
sudo killall apt apt-get 2>/dev/null
sudo rm -f /var/lib/apt/lists/lock
sudo rm -f /var/cache/apt/archives/lock
sudo rm -f /var/lib/dpkg/lock-frontend
sudo rm -f /var/lib/dpkg/lock

# dpkg sorunlarını çöz
echo -e "${GREEN}dpkg yapılandırılıyor...${NC}"
sudo dpkg --configure -a

# Broken packages düzelt
echo -e "${GREEN}Eksik paketler düzeltiliyor...${NC}"
sudo apt --fix-broken install -y

# ---------------------
# 1. GÜNCELLEME & KÜTÜPHANELER
# ---------------------
echo -e "\n${YELLOW}[1/8] Sistem güncelleniyor ve kütüphaneler kuruluyor...${NC}"
sudo apt clean
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl git build-essential jq make gcc nano lz4 unzip wget pkg-config libssl-dev liblz4-tool tmux

# Git kontrolü
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git kurulamadı, tekrar deneniyor...${NC}"
    sudo apt install -y git
fi

# ---------------------
# 2. NODE.JS ve NPM
# ---------------------
echo -e "\n${YELLOW}[2/8] Node.js ve npm kuruluyor...${NC}"

# Eski Node.js versiyonlarını temizle
sudo apt remove -y nodejs npm
sudo apt autoremove -y

# Node.js 22 kur
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# npm kontrolü ve kurulumu
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm bulunamadı, manuel kuruluyor...${NC}"
    sudo apt install -y npm
fi

# npm'i güncelle
sudo npm install -g npm@latest

# Yarn kur
echo -e "${GREEN}Yarn kuruluyor...${NC}"
sudo npm install -g yarn

# ---------------------
# 3. HARDHAT KURULUMU
# ---------------------
echo -e "\n${YELLOW}[3/8] Hardhat küresel kurulumu...${NC}"
sudo npm install -g hardhat

# ---------------------
# 4. PROJE TEMİZLİK VE KLONLAMA
# ---------------------
echo -e "\n${YELLOW}[4/8] Proje dizini temizleniyor ve klonlanıyor...${NC}"

# Eski dizini temizle
if [ -d "zama-deploy" ]; then
    echo -e "${GREEN}Eski dizin temizleniyor...${NC}"
    rm -rf zama-deploy
fi

# Yeni klonla
git clone https://github.com/zama-ai/fhevm-hardhat-template zama-deploy

# Dizine geç
cd zama-deploy || {
    echo -e "${RED}HATA: zama-deploy dizinine geçilemedi!${NC}"
    exit 1
}

# ---------------------
# 5. DEPENDENCY KURULUMU
# ---------------------
echo -e "\n${YELLOW}[5/8] Proje bağımlılıkları yükleniyor...${NC}"

# node_modules temizle
if [ -d "node_modules" ]; then
    echo -e "${GREEN}Eski node_modules temizleniyor...${NC}"
    rm -rf node_modules
fi

# package-lock temizle
if [ -f "package-lock.json" ]; then
    rm -f package-lock.json
fi

# Bağımlılıkları yükle
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

# RPC URL
echo -e "${BLUE}Sepolia RPC URL girin${NC}"
echo -e "${GREEN}(Enter'a basarsanız default kullanılır: https://ethereum-sepolia-rpc.publicnode.com)${NC}"
read -p "> " RPC_URL
RPC_URL=${RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}

# Private Key
echo -e "\n${BLUE}Private Key girin ${RED}(başında 0x OLMADAN)${NC}"
read -s -p "> " PRIVATE_KEY
echo ""

# Hardhat vars kontrolü
echo -e "\n${GREEN}Hardhat CLI değişkenleri ayarlanıyor...${NC}"

# npx hardhat komutunun çalıştığını kontrol et
if ! npx hardhat --version &> /dev/null; then
    echo -e "${RED}Hardhat bulunamadı, lokal olarak kuruluyor...${NC}"
    npm install --save-dev hardhat
fi

# Değişkenleri ayarla
npx hardhat vars set SEPOLIA_RPC_URL "$RPC_URL"
npx hardhat vars set PRIVATE_KEY "$PRIVATE_KEY"

# ---------------------
# 8. DERLEME & DEPLOY
# ---------------------
echo -e "\n${YELLOW}[8/8] Akıllı kontrat derleniyor ve deploy ediliyor...${NC}"

# Derleme
echo -e "${GREEN}Kontratlar derleniyor...${NC}"
npx hardhat compile

# Deploy
echo -e "\n${PURPLE}Deploy işlemi başlıyor...${NC}"
echo -e "${YELLOW}NOT: Sepolia ağında işlem onayı 15-30 saniye sürebilir...${NC}"

# Deploy çıktısını yakala
DEPLOY_OUTPUT=$(npx hardhat deploy --network sepolia 2>&1)
echo "$DEPLOY_OUTPUT"

# Kontrat adresini çıktıdan al
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP "(?<=Contract deployed at:[\s])[0x]+[a-fA-F0-9]+|(?<=deployed at[\s])[0x]+[a-fA-F0-9]+|(?<=address:[\s])[0x]+[a-fA-F0-9]+|(?<=to[\s])[0x]+[a-fA-F0-9]+" | head -1)

# Alternatif: deployment klasöründen al
if [ -z "$CONTRACT_ADDRESS" ]; then
    DEPLOYMENT_FILE=$(find ./deployments/sepolia -name "*.json" -type f -exec ls -t {} + | head -1)
    if [ -f "$DEPLOYMENT_FILE" ]; then
        CONTRACT_ADDRESS=$(jq -r '.address' "$DEPLOYMENT_FILE" 2>/dev/null)
    fi
fi

# ---------------------
# SONUÇ
# ---------------------
echo -e "\n${GREEN}=================================================${NC}"
echo -e "${GREEN}        KURULUM VE DEPLOY TAMAMLANDI!            ${NC}"
echo -e "${GREEN}=================================================${NC}"

if [ ! -z "$CONTRACT_ADDRESS" ]; then
    echo -e "${YELLOW}Deployed Contract Address:${NC}"
    echo -e "${PURPLE}$CONTRACT_ADDRESS${NC}"
    echo -e ""
    echo -e "${BLUE}Etherscan'da görüntüle:${NC}"
    echo -e "${BLUE}https://sepolia.etherscan.io/address/$CONTRACT_ADDRESS${NC}"
else
    echo -e "${YELLOW}Kontrat adresi otomatik alınamadı.${NC}"
    echo -e "${YELLOW}Yukarıdaki deploy çıktısında kontrat adresini görebilirsiniz.${NC}"
    echo -e "${BLUE}Etherscan: https://sepolia.etherscan.io${NC}"
fi

echo -e "${GREEN}=================================================${NC}"
