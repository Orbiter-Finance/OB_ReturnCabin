/* eslint-disable prettier/prettier */
import assert from 'assert';
import { Wallet } from 'ethers';
import { ethers } from 'hardhat';
import {
  ORManager__factory
} from '../typechain-types';

export async function managerSetup() {
  const signers = await ethers.getSigners();
  const deployer = new Wallet(
    process.env.DEPLOYER_PRIVATE_KEY || '',
    signers[0].provider,
  );
  console.log('deployer:', deployer.address);
  const networkId = (await ethers.provider.getNetwork()).chainId;
  console.log('current networkId', networkId);

  const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
  assert(
    !!envORManagerAddress &&
      'Env miss [XXXX]. You may need to deploy all the contracts first!',
  );

  const orManager = new ORManager__factory()
    .connect(deployer)
    .attach(envORManagerAddress);

  const tx1 = await orManager.updateSpvDataInjectOwner(
    '0xcc6afbbfc95197c1a71931bbcf4bfca047f5e698',
  );

  console.log('Hash of updateSpvDataInjectOwner:', tx1.hash);
  await tx1.wait(2);
}

async function main() {
  await managerSetup();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
