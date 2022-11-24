import { ORManager } from './../typechain-types/contracts/ORManager';
import { ORSpv } from './../typechain-types/contracts/ORSpv';
import { ethers } from 'hardhat';
import { ORMakerV1Factory } from '../typechain-types/contracts/ORMakerV1Factory';
import { ORProtocalV1 } from '../typechain-types';
import { deploy, printAddress, printHash } from './utils';

async function main() {
  // deploy spv
  const spv = await deploy<ORSpv>(true, 'ORSpv');
  // deploy factory
  const manager = await deploy<ORManager>(true, 'ORManager');

  const makerV1factory = await deploy<ORMakerV1Factory>(
    true,
    'ORMakerV1Factory',
    manager.address,
    100,
  );
  // // create maker
  const accounts = await ethers.getSigners();
  const [owner, maker] = accounts;
  printAddress('owner wallet:', owner.address);
  printAddress('maker wallet:', maker.address);
  // const tx = await makerV1factory.connect(maker).createMaker();
  // printHash('Create Maker Tx:', tx.hash);
  // tx.wait()
  //   .then((rawTx) => {
  //     const makerMapEvent = rawTx.events?.find(
  //       (row) => row.event == 'MakerCreated',
  //     );
  //     if (makerMapEvent && makerMapEvent.args) {
  //       printAddress('First Maker User:', makerMapEvent.args[0]);
  //       printAddress('First Maker User Pool:', makerMapEvent.args[1]);
  //     }
  //   })
  //   .catch((error) => {
  //     console.error('Create Maker Error:', error);
  //   });
  // deplory ORProtocalV1
  const protocalV1 = await deploy<ORProtocalV1>(
    true,
    'ORProtocalV1',
    manager.address,
    ethers.utils.parseEther('0.1'),
    10,
    10,
    10,
    300,
  );
  // // set spv
  const tx1 = await manager.setSPV(spv.address);
  await tx1.wait();
  printHash('setSPV', tx1.hash);
  // set ebc
  const tx2 = await manager.setEBC(protocalV1.address);
  await tx2.wait();
  printHash('setEBC', tx2.hash);
  // init manager();
  require('./init/initManager');
  // require('./init/initMaker');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
