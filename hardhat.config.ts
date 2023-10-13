import '@nomicfoundation/hardhat-toolbox';
import { config as dotenvConfig } from 'dotenv';
import { utils } from 'ethers';
import type { HardhatUserConfig } from 'hardhat/config';
import type { NetworkUserConfig } from 'hardhat/types';
import { resolve } from 'path';

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || './.env';
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

// Ensure that we have all the environment variables we need.
const mnemonic: string | undefined = process.env.MNEMONIC;
if (!mnemonic) {
  throw new Error('Please set your MNEMONIC in a .env file');
}

const infuraApiKey: string | undefined = process.env.INFURA_API_KEY;
if (!infuraApiKey) {
  throw new Error('Please set your INFURA_API_KEY in a .env file');
}

export const chainIds = {
  'arbitrum-mainnet': 42161,
  'arbitrum-goerli': 421613,
  'zkSync-Era-Testnet': 280,
  avalanche: 43114,
  bsc: 56,
  hardhat: 31337,
  mainnet: 1,
  'optimism-mainnet': 10,
  'optimism-goerli': 420,
  'polygon-mainnet': 137,
  'polygon-mumbai': 80001,
  sepolia: 11155111,
  goerli: 5,
  ganache: 1337,
};

function getChainConfig(chain: keyof typeof chainIds): NetworkUserConfig {
  let jsonRpcUrl: string;
  switch (chain) {
    case 'avalanche':
      jsonRpcUrl = 'https://api.avax.network/ext/bc/C/rpc';
      break;
    case 'bsc':
      jsonRpcUrl = 'https://bsc-dataseed1.binance.org';
      break;
    case 'arbitrum-goerli':
      jsonRpcUrl = 'https://endpoints.omniatech.io/v1/arbitrum/goerli/public';
      break;
    case 'optimism-goerli':
      jsonRpcUrl = 'https://optimism-goerli.public.blastapi.io';
      break;
    case 'zkSync-Era-Testnet':
      jsonRpcUrl = 'https://zksync-era-testnet.blockpi.network/v1/rpc/public';
      break;
    case 'ganache':
      jsonRpcUrl = 'http://127.0.0.1:7545';
      break;
    default:
      jsonRpcUrl = 'https://' + chain + '.infura.io/v3/' + infuraApiKey;
  }
  return {
    accounts: {
      count: 20,
      mnemonic,
      path: "m/44'/60'/0'/0",
    },
    chainId: chainIds[chain],
    url: jsonRpcUrl,
  };
}

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY || '',
      avalanche: process.env.SNOWTRACE_API_KEY || '',
      bsc: process.env.BSCSCAN_API_KEY || '',
      mainnet: process.env.ETHERSCAN_API_KEY || '',
      optimisticEthereum: process.env.OPTIMISM_API_KEY || '',
      polygon: process.env.POLYGONSCAN_API_KEY || '',
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || '',
      sepolia: process.env.ETHERSCAN_API_KEY || '',
      goerli: process.env.ETHERSCAN_API_KEY || '',
    },
  },
  gasReporter: {
    currency: 'USD',
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    coinmarketcap: process.env.COINMARKETCAP_KEY,
    src: './contracts',
  },
  networks: {
    hardhat: {
      hardfork: 'shanghai',
      accounts: {
        mnemonic,
        count: 20,
        accountsBalance: utils.parseEther('100') + '',
      },
      chainId: chainIds.hardhat,
      allowUnlimitedContractSize: false
    },
    arbitrum: getChainConfig('arbitrum-mainnet'),
    avalanche: getChainConfig('avalanche'),
    bsc: getChainConfig('bsc'),
    mainnet: getChainConfig('mainnet'),
    optimism: getChainConfig('optimism-mainnet'),
    'polygon-mainnet': getChainConfig('polygon-mainnet'),
    'polygon-mumbai': getChainConfig('polygon-mumbai'),
    sepolia: getChainConfig('sepolia'),
    goerli: getChainConfig('goerli'),
    'arbitrum-goerli': getChainConfig('arbitrum-goerli'),
    'optimism-goerli': getChainConfig('optimism-goerli'),
    'era-goerli': getChainConfig('zkSync-Era-Testnet'),
    ganache: getChainConfig('ganache'),
  },
  paths: {
    artifacts: './artifacts',
    cache: './cache',
    sources: './contracts',
    tests: './test',
  },
  solidity: {
    version: '0.8.17',
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/hardhat-template/issues/31
        bytecodeHash: 'none',
      },
      // Disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 10,
      },
      viaIR: true,
    },
  },
  typechain: {
    target: 'ethers-v5',
  },
  mocha: {
    timeout: 4000000000,
  },
};

export default config;
