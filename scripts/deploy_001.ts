import { ethers, upgrades } from 'hardhat';
import { ORManagerFactory } from '../typechain-types/contracts/ORManagerFactory';

async function main() {
  // deploy spv
  const ORSpv = await ethers.getContractFactory('ORSpv');
  const spv = await upgrades.deployProxy(ORSpv);
  await spv.deployed();
  console.log('ORSpv deployed to:', spv.address);

  // deplory ORProtocalV1
  const ORProtocalV1 = await ethers.getContractFactory('ORProtocalV1');
  const protocalV1 = await upgrades.deployProxy(ORProtocalV1);
  await protocalV1.deployed();
  console.log('ORProtocalV1 deployed to:', protocalV1.address);

  // deploy factory
  const ORManagerFactory = await ethers.getContractFactory('ORManagerFactory');
  const factoryProxy = await upgrades.deployProxy(ORManagerFactory);
  await factoryProxy.deployed();
  console.log('ORManagerFactory deployed to:', factoryProxy.address);
  const factory = factoryProxy as ORManagerFactory;
  console.log('factory:', factory.address);
  // create maker
  const [_, maker] = await ethers.getSigners();
  await factory.connect(maker).createMaker();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
