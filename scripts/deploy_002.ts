import { ethers } from 'hardhat';

async function main() {
  // deploy spv
  const Greeter = await ethers.getContractFactory('ORSpv');
  const greeter = await Greeter.deploy();
  console.log('Greeter deployed to:', greeter.address);
  await greeter.deployed();
  console.log('Greeter deployed to after:', greeter.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
