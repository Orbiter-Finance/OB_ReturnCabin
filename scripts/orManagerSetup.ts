/* eslint-disable prettier/prettier */
import { ethers } from 'hardhat';
import orManagerConfig from './orManager.config';
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
import { BigNumberish, utils } from 'ethers';
import { defaultChainInfoArray } from '../test/lib/mockData';
import { calculateEnableTime, deployContracts, deploySPVs } from './utils';
import { env } from 'process';
import { indexOf } from 'lodash';

export async function managerSetup() {
  let config = orManagerConfig;
  const signers = await ethers.getSigners();
  const deployer = signers[0];
  const mdcOwner = signers[2];
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
  assert(
    !!envORManagerAddress &&
      !!envSPVAddress &&
      !!envSPVERAAddress &&
      !!envRlpDecoderAddress &&
      !!envSpvDataAddress,
    'Env miss [XXXX]. You may need to test ORManager.test.ts and deploy contracts first. Example: npx hardhat test test/ORManager.test test/ORFeeManager.test.ts',
  );
  const envSPVAddressArray: string[] = [envSPVAddress, envSPVERAAddress];

  const orManager = new ORManager__factory()
    .connect(deployer)
    .attach(envORManagerAddress);

  config.chains = defaultChainInfoArray.map((chain) => ({
    ...chain,
    spvs: [envSPVAddressArray[indexOf(defaultChainInfoArray, chain)]],
    tokens: config.chains[0].tokens,
  })) as never;

  console.log(
    'chainInfo',
    config.chains.map((chain) => chain),
  );

  const tx1 = await orManager.registerChains(
    await calculateEnableTime(orManager),
    config.chains,
  );

  console.log('Hash of registerChains:', tx1.hash);
  await tx1.wait(3);
  config.ebcs.push(process.env['EVENT_BINDING_CONTRACT']! as never);
  const chainIds: BigNumberish[] = [];
  const tokens: BridgeLib.TokenInfoStruct[] = [];

  for (const chain of config.chains) {
    for (const token of chain.tokens) {
      chainIds.push(chain.id);
      tokens.push(token);
    }
  }
  console.log('update tokens', tokens);

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
  await tx2.wait(3);

  // updateEbcs
  if (config.ebcs.length === 0) {
    console.error('Miss config.ebcs');
    return;
  }
  const statuses = config.ebcs.map(() => true);
  const tx3 = await orManager.updateEbcs(config.ebcs, statuses);
  console.log('Hash of updateEbcs:', tx3.hash);
  await tx3.wait(3);

  // updateRLPdecoder
  const txUpdateRLPdecoder = await orManager.updateDecoderAddress(
    envRlpDecoderAddress,
  );
  console.log('Hash of updateRLPdecoder:', txUpdateRLPdecoder.hash);
  await txUpdateRLPdecoder.wait(3);

  // updateChallengeUserRatio
  const challengeUserRatio = 1000;
  const txUpdateRatio = await orManager.updateChallengeUserRatio(
    await calculateEnableTime(orManager),
    challengeUserRatio,
  );
  await txUpdateRatio.wait(3);
  console.log('Hash of updateChallengeUserRatio:', txUpdateRatio.hash);

  // updateSpvDataContract
  const txUpdateSpvDataContract = await orManager.updateSpvDataContract(
    envSpvDataAddress,
  );
  await txUpdateSpvDataContract.wait(3);
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
  await tx4.wait(3);
}

async function main() {
  await managerSetup();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
