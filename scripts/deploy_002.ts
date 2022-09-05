import { ethers, upgrades } from 'hardhat';
import { ORManager } from '../typechain-types/contracts/ORManager';
import { ORMakerV1Factory } from '../typechain-types/contracts/ORMakerV1Factory';

async function main() {
  // deploy factory
  const ORManager = await ethers.getContractFactory('ORManager');
  const factoryProxy = await upgrades.deployProxy(ORManager);
  await factoryProxy.deployed();
  console.log('ORManager deployed to:', factoryProxy.address);
  const factory = factoryProxy as ORManager;
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
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
