/* eslint-disable prettier/prettier */
import { ethers } from 'hardhat';
import orManagerConfig, {
  deploymentChainInfoArray,
  tokenDefault,
} from './orManager.config';
import {
  // ORChallengeSpv__factory,
  OREventBinding__factory,
  ORManager__factory,
  ORSpvData__factory,
  RLPDecoder__factory,
} from '../typechain-types';
import assert from 'assert';
import { getMinEnableTime } from '../test/utils.test';
import { BridgeLib } from '../typechain-types/contracts/ORManager';
import { BigNumberish, utils, constants, Wallet } from 'ethers';
import { defaultChainInfoArray } from '../test/lib/mockData';
import { calculateEnableTime, deployContracts, deploySPVs } from './utils';
import { env } from 'process';
import lodash, { indexOf } from 'lodash';

export async function managerSetup() {
  let config = orManagerConfig;
  const signers = await ethers.getSigners();
  const deployer = new Wallet(
    process.env.DEPLOYER_PRIVATE_KEY || '',
    signers[0].provider,
  );
  const mdcOwner = signers[2];
  const ebcArray: string[] = [];
  console.log('deployer:', deployer.address);
  const networkId = (await ethers.provider.getNetwork()).chainId;
  console.log('current networkId', networkId);

  /*
  @notice: deployContracts will deploy all contracts needed for orbiter
  */
  // await deployContracts(deployer);

  const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
  const envSPVAddress = process.env['SPV_ADDRESS'];
  const envSPVERAAddress = process.env['SPV_ADDRESS_ERA'];
  const envRlpDecoderAddress = process.env['RLP_DECODER_ADDRESS'];
  const envSpvDataAddress = process.env['OR_SPV_DATA_ADRESS'];
  const envEBCAddress = process.env['EVENT_BINDING_CONTRACT'];
  assert(
    !!envORManagerAddress &&
      !!envSPVAddress &&
      !!envSPVERAAddress &&
      !!envRlpDecoderAddress &&
      !!envEBCAddress &&
      !!envSpvDataAddress,
    'Env miss [XXXX]. You may need to deploy all the contracts first!',
  );

  const orManager = new ORManager__factory()
    .connect(deployer)
    .attach(envORManagerAddress);

  let chainInfo = deploymentChainInfoArray.map((chainInfo) => {
    let chaininfoTmp = lodash.cloneDeepWith(chainInfo);
    if (chaininfoTmp.id == 1) {
      chaininfoTmp.spvs = [envSPVAddress];
    } else if (chaininfoTmp.id == 324) {
      chaininfoTmp.spvs = [envSPVERAAddress];
    }
    return chaininfoTmp;
  });
  console.log('chainInfo', chainInfo);

  const tx1 = await orManager.registerChains(
    await calculateEnableTime(orManager),
    chainInfo,
  );

  console.log('Hash of registerChains:', tx1.hash);
  await tx1.wait(2);
  ebcArray.push(envEBCAddress);
  const chainIds: BigNumberish[] = [];
  const tokens: BridgeLib.TokenInfoStruct[] = [];

  for (const chain of chainInfo) {
    chainIds.push(await chain.id);
    tokens.push(tokenDefault);
  }

  // updateChainTokens
  if (tokens.length === 0) {
    console.error('Miss tokens');
    return;
  }

  const tx2 = await orManager.updateChainTokens(
    await calculateEnableTime(orManager),
    chainIds,
    tokens,
  );
  console.log('Hash of updateChainTokens:', tx2.hash);
  await tx2.wait(2);

  // updateEbcs
  const statuses = ebcArray.map(() => true);
  const tx3 = await orManager.updateEbcs(ebcArray, statuses);
  console.log('Hash of updateEbcs:', tx3.hash);
  await tx3.wait(2);

  // updateRLPdecoder
  const txUpdateRLPdecoder = await orManager.updateDecoderAddress(
    envRlpDecoderAddress,
  );
  console.log('Hash of updateRLPdecoder:', txUpdateRLPdecoder.hash);
  await txUpdateRLPdecoder.wait(2);

  // updateSpvDataContract
  const txUpdateSpvDataContract = await orManager.updateSpvDataContract(
    envSpvDataAddress,
  );
  await txUpdateSpvDataContract.wait(2);
  console.log('Hash of updateSpvDataContract:', txUpdateSpvDataContract.hash);

  // updateSubmitter
  if (!config.submitter) {
    console.error('Miss orManagerConfig.submitter');
    return;
  }
  const tx4 = await orManager.updateSubmitter(
    getMinEnableTime(),
    config.submitter,
  );
  console.log('Hash of updateSubmitter:', tx4.hash);
  await tx4.wait(2);
}

async function main() {
  await managerSetup();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
