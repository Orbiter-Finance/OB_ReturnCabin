import 'dotenv/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-web3';
import '@openzeppelin/hardhat-upgrades';
import 'hardhat-contract-sizer';
import "@nomiclabs/hardhat-etherscan";
import 'solidity-docgen';
import { HardhatUserConfig, task } from 'hardhat/config';
const { INFURA_API_KEY, ETHERSCAN_API_KEY, NETWORK,ACCOUNTS} = process.env;
task('accounts', 'Prints accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  for (const account of accounts) {
    const balance = await hre.web3.eth.getBalance(account.address);
    console.log(`account：${account.address}, balance：${balance.toString()}`);
  }
});
const accounts = ACCOUNTS?.split(',');
const config: HardhatUserConfig = {
  defaultNetwork: NETWORK,
  docgen: {
  },
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    ganache: {
      chainId: 5777,
      url: 'http://127.0.0.1:7545',
      accounts
    },
    test: {
      chainId: 599,
      url: 'http://ec2-54-178-23-104.ap-northeast-1.compute.amazonaws.com:8545',
      accounts
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${INFURA_API_KEY}`,
      accounts
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
      accounts
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${INFURA_API_KEY}`,
      timeout: 1000 * 60 * 60 * 5,
      // gas: 643356,
      // blockGasLimit:,
      gasPrice: 20000000000,
      accounts,
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${INFURA_API_KEY}`,
      accounts
    },
    arbitrum: {
      url: `https://arbitrum-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts
    },
    optimismKovan: {
      url: `https://optimism-kovan.infura.io/v3/${INFURA_API_KEY}`,
      accounts
    },
    optimism: {
      url: `https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts
    },
    mumbai: {
      url: `https://polygon-mumbai.infura.io/v3/${INFURA_API_KEY}`,
      accounts
    },
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: ETHERSCAN_API_KEY,
  },
  mocha: {
    // timeout: 40000 * 10
  }
};

export default config;
