import { Wallet, constants } from 'ethers';
import { ethers } from 'hardhat';
import {
  OREventBinding__factory,
  ORFeeManager__factory,
  ORMDCFactory__factory,
  ORMakerDeposit__factory,
  ORManager__factory,
  ORSpvData__factory,
} from '../typechain-types';

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

  const orManager = await new ORManager__factory(deployer).deploy(
    deployer.address,
  );
  console.log(
    `Address of orManager: ${
      orManager.address
    }, deployed blockNumber: ${await ethers.provider.getBlockNumber()} `,
  );
  await orManager.deployed();

  const orSpvData = await new ORSpvData__factory(deployer).deploy(
    orManager.address,
    process.env.OR_SPV_DATA_INJECT_OWNER || constants.AddressZero,
  );
  console.log(
    `Address of orSpvData: ${
      orSpvData.address
    }, deployed blockNumber: ${await ethers.provider.getBlockNumber()} `,
  );
  await orSpvData.deployed();

  const orMakerDeposit_impl = await new ORMakerDeposit__factory(
    deployer,
  ).deploy();
  console.log('Address of orMakerDeposit_impl:', orMakerDeposit_impl.address);
  await orMakerDeposit_impl.deployed();

  const orMDCFactory = await new ORMDCFactory__factory(deployer).deploy(
    orManager.address,
    orMakerDeposit_impl.address,
  );
  console.log(
    `Address of orMDCFactory: ${
      orMDCFactory.address
    }, deployed blockNumber: ${await ethers.provider.getBlockNumber()} `,
  );
  await orMDCFactory.deployed();

  const feeManager = await new ORFeeManager__factory(deployer).deploy(
    deployer.address,
    orManager.address,
  );
  await feeManager.deployed();
  console.log(
    `Address of feeManager: ${
      feeManager.address
    }, deployed blockNumber: ${await ethers.provider.getBlockNumber()} 
Address of feeManagerOwner: ${await feeManager.owner()} `,
  );

  const ebc = await new OREventBinding__factory(deployer).deploy();
  await ebc.deployed();
  console.log('Address of EBC:', ebc.address);

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
