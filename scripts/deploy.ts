import { ethers } from 'hardhat';
import {
  OREventBinding__factory,
  ORFeeManager__factory,
  ORMDCFactory__factory,
  ORMakerDeposit__factory,
  ORManager__factory,
} from '../typechain-types';

export async function deploy() {
  const signers = await ethers.getSigners();
  const deployer = signers[0];

  const orManager = await new ORManager__factory(deployer).deploy(
    deployer.address,
  );
  console.log(`Address of orManager: ${orManager.address}
Address of orManagerOwner: ${await orManager.owner()}`);
  await orManager.deployed();

  const orMakerDeposit_impl = await new ORMakerDeposit__factory(
    deployer,
  ).deploy();
  console.log('Address of orMakerDeposit_impl:', orMakerDeposit_impl.address);
  await orMakerDeposit_impl.deployed();

  const orMDCFactory = await new ORMDCFactory__factory(deployer).deploy(
    orManager.address,
    orMakerDeposit_impl.address,
  );
  console.log('Address of orMDCFactory:', orMDCFactory.address);
  await orMDCFactory.deployed();

  const ebc = await new OREventBinding__factory(deployer).deploy();
  console.log('Address of EBC:', ebc.address);

  const feeManager = await new ORFeeManager__factory(deployer).deploy(
    deployer.address,
    orManager.address,
  );
  await feeManager.deployed();
  console.log(
    `Address of feeManager: ${feeManager.address}
Address of feeManagerOwner: ${await feeManager.owner()}`,
  );

  return {
    deployer,
    orManager,
    orMakerDeposit_impl,
    orMDCFactory,
  };
}

async function main() {
  await deploy();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
