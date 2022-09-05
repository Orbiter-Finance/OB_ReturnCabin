import { ethers, upgrades } from 'hardhat';
import { ORManager } from '../typechain-types/contracts/ORManager';
import { ORMakerV1Factory } from '../typechain-types/contracts/ORMakerV1Factory';

async function main() {
  // deploy spv
  const ORSpv = await ethers.getContractFactory('ORSpv');
  const spv = await upgrades.deployProxy(ORSpv);
  await spv.deployed();
  console.log('ORSpv deployed to:', spv.address);

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
  const [owner, maker] = await ethers.getSigners();
  console.log('owner wallet:', owner.address);
  console.log('maker wallet:', maker.address);
  const tx = await makerV1factory.connect(maker).createMaker();
  console.log('Create Maker Tx:', tx.hash);
  tx.wait()
    .then((rawTx) => {
      const makerMapEvent = rawTx.events?.find(
        (row) => row.event == 'MakerCreated',
      );
      if (makerMapEvent && makerMapEvent.args) {
        console.log('First Maker User:', makerMapEvent.args[0]);
        console.log('First Maker User Pool:', makerMapEvent.args[1]);
      }
    })
    .catch((error) => {
      console.error('Create Maker Error:', error);
    });
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
