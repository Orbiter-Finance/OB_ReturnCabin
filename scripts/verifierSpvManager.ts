/* eslint-disable prettier/prettier */
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import {
  ORChallengeSpvEra2Mainnet__factory,
  ORChallengeSpvMainnet2Era__factory,
  OREventBinding,
  OREventBinding__factory,
  ORMakerDeposit,
  ORMakerDeposit__factory,
  ORManager,
  ORManager__factory,
  ORSpvData,
  ORSpvData__factory,
  RLPDecoder,
  RLPDecoder__factory,
  TestMakerDeposit,
  TestMakerDeposit__factory,
  TestSpv__factory,
} from '../typechain-types';

import { assert, expect } from 'chai';

import {
  SPVTypeEnum,
  VerifierAbi,
  calculateEnableTime,
  compile_yul,
  createRandomChallenge,
  deployContracts,
  deployMDC,
  getSpvProof,
  hotUpdateSpvVerifier,
  managerUpdateEBC,
  updateSpvType,
} from './utils';
import { BigNumber, BigNumberish, Wallet, constants, utils } from 'ethers';

export async function verifierSpvManager() {
  let signers: SignerWithAddress[];
  signers = await ethers.getSigners();
  const deployer = new Wallet(
    process.env.DEPLOYER_PRIVATE_KEY || '',
    signers[0].provider,
  );

  /// notice: deployContracts will deploy all contracts needed for orbiter
  // await deployContracts(deployer);

  const envSPVAddress = process.env['SPV_ADDRESS'];
  const envSPVEraAddress = process.env['SPV_ADDRESS_ERA'];
  assert(!!envSPVEraAddress && !!envSPVAddress, 'Env miss [OR_MDC_TEST].');
  const spv = new ORChallengeSpvMainnet2Era__factory(deployer).attach(
    envSPVAddress,
  );
  console.log('connect to spv:', spv.address);

  const spvERA = new ORChallengeSpvEra2Mainnet__factory(deployer).attach(
    envSPVEraAddress,
  );
  console.log('connect to spvERA:', spvERA.address);

  console.log('-------------- update spv start!--------------');

  let updateType: updateSpvType = {
    sourceTx: false,
    destTx: true,
  };

  await hotUpdateSpvVerifier(
    spv,
    updateType,
    SPVTypeEnum.mainnet2era,
    deployer,
  );

  updateType = {
    sourceTx: true,
    destTx: false,
  };

  await hotUpdateSpvVerifier(
    spvERA,
    updateType,
    SPVTypeEnum.era2mainnet,
    deployer,
  );

  console.log('-------------- update spv end!--------------');
}

async function main() {
  await verifierSpvManager();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
