import { ORMakerDeposit } from './../../typechain-types/contracts/ORMakerDeposit';
import { ethers } from 'hardhat';
import { deploy, printContract } from '../utils';
let contractAddress = process.env['ORManager'] || '';
async function getMakerContract(): Promise<ORMakerDeposit> {
  if (contractAddress) {
    const maker = await ethers.getContractAt('ORMakerDeposit', contractAddress);
    printContract('load ORMakerDeposit contract:', maker.address.toString());
    return maker;
  } else {
    const maker = await deploy<ORMakerDeposit>(true, 'ORManager');
    contractAddress = maker.address;
    return maker;
  }
}
export async function main() {
  const contract = await getMakerContract();
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
