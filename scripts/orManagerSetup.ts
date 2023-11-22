/* eslint-disable prettier/prettier */
import { ethers } from 'hardhat';
import orManagerConfig from './orManager.config';
import {
  ORChallengeSpv__factory,
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
import { calculateEnableTime, deploySPVs } from './utils';

export async function managerSetup() {
  let config = orManagerConfig;
  const signers = await ethers.getSigners();
  const deployer = signers[0];
  console.log('deployer:', deployer.address);
  const networkId = (await ethers.provider.getNetwork()).chainId;
  const isTestnet = networkId === 31337 || networkId === 5;
  if (isTestnet) {
    if (process.env['OR_MANAGER_ADDRESS'] == undefined) {
      const orManager = await new ORManager__factory(deployer).deploy(
        deployer.address,
      );
      await orManager.deployed();
      console.log('orManager deployed to:', orManager.address);
      process.env['OR_MANAGER_ADDRESS'] = orManager.address;
    } else {
      console.log('connect to orManager:', process.env['OR_MANAGER_ADDRESS']!);
    }
    if (process.env['SPV_ADDRESS'] == undefined) {
      await deploySPVs(deployer);
    } else {
      console.log('connect to SPV:', process.env['SPV_ADDRESS']!);
    }

    if (process.env['EVENT_BINDING_CONTRACT'] == undefined) {
      const ebc = await new OREventBinding__factory(deployer).deploy();
      await ebc.deployed();
      console.log('ebc deployed to:', ebc.address);
      process.env['EVENT_BINDING_CONTRACT'] = ebc.address;
    } else {
      console.log('connect to ebc:', process.env['EVENT_BINDING_CONTRACT']!);
    }

    if (process.env['RLP_DECODER_ADDRESS'] == undefined) {
      const rlpDecoder = await new RLPDecoder__factory(deployer).deploy();
      await rlpDecoder.deployed();
      console.log('rlpDecoder deployed to:', rlpDecoder.address);
      process.env['RLP_DECODER_ADDRESS'] = rlpDecoder.address;
    } else {
      console.log(
        'connect to rlpDecoder:',
        process.env['RLP_DECODER_ADDRESS']!,
      );
    }

    if (process.env['OR_SPV_DATA_ADRESS'] == undefined) {
      const spvData = await new ORSpvData__factory(deployer).deploy(
        process.env['OR_MANAGER_ADDRESS']!,
      );
      await spvData.deployed();
      console.log('spvData deployed to:', spvData.address);
      process.env['OR_SPV_DATA_ADRESS'] = spvData.address;
    } else {
      console.log('connect to spvData:', process.env['OR_SPV_DATA_ADRESS']!);
    }
  }

  const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
  const envSPVAddress = process.env['SPV_ADDRESS'];
  const envRlpDecoderAddress = process.env['RLP_DECODER_ADDRESS'];
  const envSpvDataAddress = process.env['OR_SPV_DATA_ADRESS'];
  assert(
    !!envORManagerAddress &&
      !!envSPVAddress &&
      !!envRlpDecoderAddress &&
      !!envSpvDataAddress,
    'Env miss [XXXX]. You may need to test ORManager.test.ts and deploy contracts first. Example: npx hardhat test test/ORManager.test test/ORFeeManager.test.ts',
  );

  const orManager = new ORManager__factory()
    .connect(deployer)
    .attach(envORManagerAddress);

  config.chains = isTestnet
    ? (defaultChainInfoArray.map((chain) => ({
        ...chain,
        spvs: [envSPVAddress],
        tokens: config.chains[0].tokens,
      })) as never)
    : config.chains;

  config.ebcs.push(process.env['EVENT_BINDING_CONTRACT']! as never);

  const tx1 = await orManager.registerChains(
    await calculateEnableTime(orManager),
    config.chains,
  );
  // console.log(
  //   'chainInfo',
  //   config.chains.map((chain) => chain),
  // );
  console.log('Hash of registerChains:', tx1.hash);
  await tx1.wait(1);

  const chainIds: BigNumberish[] = [];
  const tokens: BridgeLib.TokenInfoStruct[] = [];
  for (const chain of config.chains) {
    for (const token of chain.tokens) {
      chainIds.push(chain.id);
      tokens.push(token);
    }
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
  await tx2.wait(1);

  // updateEbcs
  if (config.ebcs.length === 0) {
    console.error('Miss config.ebcs');
    return;
  }
  const statuses = config.ebcs.map(() => true);
  const tx3 = await orManager.updateEbcs(config.ebcs, statuses);
  console.log('Hash of updateEbcs:', tx3.hash);
  await tx3.wait(1);

  if (isTestnet) {
    // updateRLPdecoder
    const txUpdateRLPdecoder = await orManager.updateDecoderRLP(
      envRlpDecoderAddress,
    );
    console.log('Hash of updateRLPdecoder:', txUpdateRLPdecoder.hash);
    await txUpdateRLPdecoder.wait(1);

    // updateChallengeUserRatio
    const challengeUserRatio = 15;
    const txUpdateRatio = await orManager.updateChallengeUserRatio(
      await calculateEnableTime(orManager),
      challengeUserRatio,
    );
    await txUpdateRatio.wait(1);
    console.log('Hash of updateChallengeUserRatio:', txUpdateRatio.hash);

    // updateSpvDataContract
    const txUpdateSpvDataContract = await orManager.updateSpvDataContract(
      envSpvDataAddress,
    );
    await txUpdateSpvDataContract.wait(1);
    console.log('Hash of updateSpvDataContract:', txUpdateSpvDataContract.hash);
  }

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
  await tx4.wait(1);
}

async function main() {
  await managerSetup();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
