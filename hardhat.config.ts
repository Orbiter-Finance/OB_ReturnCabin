import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@nomiclabs/hardhat-web3';
import { task } from "hardhat/config";
import 'dotenv/config';
task("accounts", "Prints the list of accounts", async (_, { ethers, web3 }) => {
  const accounts = await ethers.getSigners();
  for (const account of accounts) {
    const balance = await hre.web3.eth.getBalance(account.address);
    console.log(`account：${account.address}, balance：${balance.toString()}`);
  }
});
const { INFURA_API_KEY, ETHERSCAN_API_KEY, ALCHEMY_KEY, NETWORK, ACCOUNTS } =
  process.env;
const config: HardhatUserConfig = {
  solidity: "0.8.18",
  defaultNetwork: NETWORK,
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
  },
  typechain: {
    outDir: "build/types",
    target: "ethers-v5",
  },
};

export default config;
