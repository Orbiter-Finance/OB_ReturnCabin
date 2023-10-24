/* eslint-disable prettier/prettier */
import assert from 'assert';
import { Wallet } from 'ethers';
import { ethers } from 'hardhat';
import {
  ORMDCFactory__factory,
  ORMakerDeposit__factory,
} from '../typechain-types';

export async function deploy() {
  const signers = await ethers.getSigners();
  const deployer = new Wallet(
    process.env.DEPLOYER_PRIVATE_KEY || '',
    signers[0].provider,
  );
  console.log('deployer:', deployer.address);

  const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
  assert(!!envORManagerAddress, 'Env miss [OR_MANAGER_ADDRESS].');

  console.warn('envORManagerAddress:', envORManagerAddress, 'ddd');

  const orMakerDeposit_impl = await new ORMakerDeposit__factory(
    deployer,
  ).deploy();
  console.log('Address of orMakerDeposit_impl:', orMakerDeposit_impl.address);
  await orMakerDeposit_impl.deployed();

  const orMDCFactory = await new ORMDCFactory__factory(deployer).deploy(
    envORManagerAddress,
    orMakerDeposit_impl.address,
  );
  console.log(
    `Address of orMDCFactory: ${
      orMDCFactory.address
    }, deployed blockNumber: ${await ethers.provider.getBlockNumber()} `,
  );
  await orMDCFactory.deployed();

  return {
    deployer,
    orManager: envORManagerAddress,
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
