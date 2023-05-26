import { ethers } from 'hardhat';
import {
  ORMDCFactory__factory,
  ORMakerDeposit__factory,
  ORManager__factory,
} from '../typechain-types';

async function main() {
  const signers = await ethers.getSigners();

  const orManager = await new ORManager__factory(signers[0]).deploy(
    signers[0].address,
  );
  console.log('Address of orManager contract:', orManager.address);
  await orManager.deployed();

  const orMakerDeposit_impl = await new ORMakerDeposit__factory(
    signers[0],
  ).deploy();
  console.log('Address of orMakerDeposit_impl:', orMakerDeposit_impl.address);
  await orMakerDeposit_impl.deployed();

  const orMDCFactory = await new ORMDCFactory__factory(signers[0]).deploy(
    orManager.address,
    orMakerDeposit_impl.address,
  );
  console.log('Address of orMDCFactory:', orMDCFactory.address);
  await orMDCFactory.deployed();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
