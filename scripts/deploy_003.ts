import { ethers } from 'hardhat';

async function main() {
  // deploy factory
  const ORMakerDeposit = await ethers.getContractFactory('ORMakerDeposit');
  const makerDeposit = await ORMakerDeposit.deploy();
  await makerDeposit.deployed();
  console.log('ORManager deployed to:', makerDeposit.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
