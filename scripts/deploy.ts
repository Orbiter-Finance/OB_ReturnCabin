import { Wallet } from 'ethers';
import { ethers } from 'hardhat';
import { deployContracts } from './utils';

export async function deploy() {
  const signers = await ethers.getSigners();
  const deployer = new Wallet(
    process.env.DEPLOYER_PRIVATE_KEY || '',
    signers[0].provider,
  );
  console.log(
    'deployer:',
    deployer.address,
    ', chainId:',
    await deployer.getChainId(),
  );

  const { orManager, orMakerDeposit_impl, orMDCFactory } =
    await deployContracts(deployer);

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
