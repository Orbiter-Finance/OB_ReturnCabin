import { ethers, upgrades } from 'hardhat';
import { ORManagerFactory } from '../typechain-types/contracts/ORManagerFactory';
import { ORMakerV1Factory } from '../typechain-types/contracts/ORMakerV1Factory';

async function main() {
  // deploy spv
  const ORSpv = await ethers.getContractFactory('ORSpv');
  const spv = await upgrades.deployProxy(ORSpv);
  await spv.deployed();
  console.log('ORSpv deployed to:', spv.address);

  // deploy factory
  const ORManagerFactory = await ethers.getContractFactory('ORManagerFactory');
  const factoryProxy = await upgrades.deployProxy(ORManagerFactory);
  await factoryProxy.deployed();
  console.log('ORManagerFactory deployed to:', factoryProxy.address);
  const factory = factoryProxy as ORManagerFactory;
  const ORMakerV1Factory = await ethers.getContractFactory('ORMakerV1Factory');
  const makerfactoryProxy = await upgrades.deployProxy(ORMakerV1Factory, [
    factory.address,
  ]);
  await makerfactoryProxy.deployed();
  console.log('ORMakerV1Factory deployed to:', makerfactoryProxy.address);
  const makerV1factory = makerfactoryProxy as ORMakerV1Factory;

  // create maker
  const [_, maker] = await ethers.getSigners();
  const tx = await makerV1factory.connect(maker).createMaker();
  console.log('Create Maker Tx:', tx.hash);
  // deplory ORProtocalV1
  const ORProtocalV1 = await ethers.getContractFactory('ORProtocalV1');
  const protocalV1 = await upgrades.deployProxy(ORProtocalV1, [
    factory.address,
  ]);
  await protocalV1.deployed();
  console.log('ORProtocalV1 deployed to:', protocalV1.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
