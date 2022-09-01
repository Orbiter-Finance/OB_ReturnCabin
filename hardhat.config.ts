import 'dotenv/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-web3';
import '@openzeppelin/hardhat-upgrades';
import 'hardhat-contract-sizer';
import { HardhatUserConfig, task } from 'hardhat/config';
const { INFURA_API_KEY, ETHERSCAN_API_KEY } = process.env;
task('accounts', 'Prints accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  for (const account of accounts) {
    const balance = await hre.web3.eth.getBalance(account.address);
    console.log(`account：${account.address}, balance：${balance.toString()}`);
  }
});

const config: HardhatUserConfig = {
  // defaultNetwork: "ganache",
  solidity: {
    version: '0.8.9',
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
    gache: {
      url: 'http://127.0.0.1:7545',
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${INFURA_API_KEY}`,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${INFURA_API_KEY}`,
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${INFURA_API_KEY}`,
    },
    arbitrumRinkeby: {
      url: `https://arbitrum-rinkeby.infura.io/v3/${INFURA_API_KEY}`,
    },
    arbitrum: {
      url: `https://arbitrum-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    },
    optimismKovan: {
      url: `https://optimism-kovan.infura.io/v3/${INFURA_API_KEY}`,
    },
    optimism: {
      url: `https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    },
    mumbai: {
      url: `https://polygon-mumbai.infura.io/v3/${INFURA_API_KEY}`,
    },
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: ETHERSCAN_API_KEY,
  },
};

export default config;
