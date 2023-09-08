import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { ethers } from 'hardhat';
import { ORManager, ORManager__factory } from '../typechain-types';
import { initTestToken } from './lib/mockData';
import { constants } from 'ethers';
import lodash from 'lodash';
import { defaultsEbcs } from './defaults';

describe('Test ORManager', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;

  before(async function () {
    signers = await ethers.getSigners();
    initTestToken();

    const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
    assert(
      !!envORManagerAddress,
      'Env miss [OR_MANAGER_ADDRESS]. You may need to test ORManager.test.ts first. Example: npx hardhat test test/ORManager.test test/ORFeeManager.test.ts',
    );

    orManager = new ORManager__factory(signers[0]).attach(envORManagerAddress);
  });

  // it('Owner should be able to be set when deploying the contract', async function () {
  //   orManager = await new ORManager__factory(signers[0]).deploy(
  //     signers[1].address,
  //   );
  //   console.log('Address of orManager contract:', orManager.address);
  //   await orManager.deployed();

  //   // set environment variables
  //   process.env['OR_MANAGER_ADDRESS'] = orManager.address;

  //   const owner = await orManager.owner();
  //   expect(owner).eq(signers[1].address);
  // });

  it("ORManager's functions prefixed with _ should be private", async function () {
    for (const key in orManager.functions) {
      expect(key.replace(/^_/, '')).eq(key);
    }
  });

  // it('Function transferOwnership should succeed', async function () {
  //   await testRevertedOwner(orManager.transferOwnership(signers[0].address));

  //   await orManager
  //     .connect(signers[1])
  //     .transferOwnership(signers[0].address)
  //     .then((t) => t.wait());
  // });

  // it(
  //   'Function registerChains should succeed',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orManager.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       // const chains = [
  //       //   lodash.cloneDeepWith(defaultChainInfo),
  //       //   lodash.cloneDeepWith(defaultChainInfo),
  //       // ];
  //       const chains = defaultChainInfoArray.map((chainInfo) => {
  //         return lodash.cloneDeepWith(chainInfo);
  //       });

  //       const { events } = await orManager
  //         .registerChains(getMinEnableTime(), chains)
  //         .then((i) => i.wait());

  //       // print all chain ids
  //       console.log(
  //         'register chainIds:',
  //         events!.map((event) => event.args!.chainInfo.id.toString()),
  //         'nativeToken',
  //         events!.map((event) => event.args!.chainInfo.nativeToken.toHexString()),
  //       );

  //       for (const i in chains) {
  //         const event = events![i];
  //         let chainInfo: BridgeLib.ChainInfoStruct = lodash.toPlainObject(
  //           event.args!.chainInfo,
  //         );

  //         expect(lodash.toPlainObject(chainInfo)).to.deep.includes(chains[i]);

  //         const storageChainInfo = await orManager.getChainInfo(chains[i].id);
  //         expect(storageChainInfo.id).eq(chains[i].id);
  //       }
  //     },
  //   ),
  // );

  // it(
  //   'Function updateChainSpvs should succeed',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orManager.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       const chains = defaultChainInfoArray.map((chainInfo) => {
  //         return lodash.cloneDeepWith(chainInfo);
  //       });

  //       for (let i = 0; i < 1; i++) {
  //         const chainId = chains[i].id;

  //         const spvs: string[] = [];
  //         const indexs: BigNumberish[] = [BigNumber.from(0)];
  //         for (let j = 0; j < 10; j++) {
  //           spvs.push(ethers.Wallet.createRandom().address);
  //         }

  //         const { events } = await orManager
  //           .updateChainSpvs(getMinEnableTime(), chainId, spvs, indexs)
  //           .then((t) => t.wait());

  //         console.log(
  //           'current chainIds:',
  //           chainId.toString(),
  //           'register spvs:',
  //           spvs.map((spvs) => spvs),
  //         );

  //         expect(events![0].args!.id).eq(chainId);
  //         expect(events![0].args!.chainInfo.spvs).deep.eq(spvs);
  //       }
  //     },
  //   ),
  // );

  // it(
  //   'Function updateChainTokens should succeed',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orManager.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       const chainIds = defaultChainInfoArray.flatMap((chainInfo) =>
  //         Array.from({ length: testToken.MAINNET_TOKEN.length }, () =>
  //           Number(chainInfo.id),
  //         ),
  //       );
  //       const tokens: BridgeLib.TokenInfoStruct[] = [];

  //       for (let i = 0; i < defaultChainInfoArray.length; i++) {
  //         for (let j = 0; j < testToken.MAINNET_TOKEN.length; j++) {
  //           const chainInfo = defaultChainInfoArray[i];
  //           const chainId = Number(chainInfo.id);
  //           const token = chainIDgetTokenSequence(chainId, j);
  //           const mainnetTestToken = calculateMainnetToken(chainId, token);
  //           tokens.push({
  //             token: BigNumber.from(token).add(0), // add(0), convert _hex uppercase to lowercase
  //             mainnetToken: mainnetTestToken,
  //             decimals: 18,
  //           });
  //         }
  //       }

  //       console.log(
  //         'current chainIds:',
  //         chainIds.map((chainId) => chainId.toString()),
  //         'register tokens:',
  //         tokens.map((token) => BigNumber.from(token.token).toHexString()),
  //         'mainnetTokens:',
  //         tokens.map((token) => token.mainnetToken),
  //       );

  //       const { events } = await orManager
  //         .updateChainTokens(getMinEnableTime(), chainIds, tokens)
  //         .then((t) => t.wait());

  //       (events || []).forEach((event, i) => {
  //         expect(event.args?.id).to.eq(chainIds[i]);
  //         expect(lodash.toPlainObject(event.args?.tokenInfo)).to.deep.includes(
  //           tokens[i],
  //         );
  //       });

  //       const latestIndex = tokens.length - 1;
  //       const tokenInfo = await orManager.getChainTokenInfo(
  //         chainIds[latestIndex],
  //         tokens[latestIndex].token,
  //       );
  //       expect(lodash.toPlainObject(tokenInfo)).to.deep.includes(
  //         tokens[latestIndex],
  //       );
  //     },
  //   ),
  // );

  it('Function updateEbcs should succeed', async function () {
    const ebcs = lodash.cloneDeep(defaultsEbcs);
    const statuses: boolean[] = [];

    const { events } = await orManager
      .updateEbcs(ebcs, statuses)
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.ebcs).to.deep.eq(ebcs);
    expect(args.statuses).to.deep.eq(statuses);

    for (const ebc of ebcs) {
      const status = await orManager.ebcIncludes(ebc);
      expect(status).to.deep.eq(true);
    }

    expect(await orManager.ebcIncludes(constants.AddressZero)).to.deep.eq(
      false,
    );
  });

  // it(
  //   'Function updateSubmitter should succeed',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orManager.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       // const submitter = ethers.Wallet.createRandom().address;
  //       const submitter = await submitterMock()

  //       const { events } = await orManager
  //         .updateSubmitter(getMinEnableTime(), submitter)
  //         .then((t) => t.wait());

  //       const args = events![0].args!;
  //       expect(args.submitter).to.deep.eq(submitter);

  //       const storageSubmitter = await orManager.submitter();
  //       expect(storageSubmitter).to.deep.eq(submitter);
  //       console.log('Submitter:', storageSubmitter);
  //     },
  //   ),
  // );

  // it(
  //   'Function updateProtocolFee should succeed',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orManager.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       const protocolFee = 10;

  //       const { events } = await orManager
  //         .updateProtocolFee(getMinEnableTime(), protocolFee)
  //         .then((t) => t.wait());

  //       const args = events![0].args!;
  //       expect(args.protocolFee).to.deep.eq(protocolFee);

  //       const storageProtocolFee = await orManager.protocolFee();
  //       expect(storageProtocolFee).to.deep.eq(protocolFee);
  //     },
  //   ),
  // );

  // it(
  //   'Function updateMinChallengeRatio should succeed',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orManager.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       const minChallengeRatio = 20;

  //       const { events } = await orManager
  //         .updateMinChallengeRatio(getMinEnableTime(), minChallengeRatio)
  //         .then((t) => t.wait());

  //       const args = events![0].args!;
  //       expect(args.minChallengeRatio).to.deep.eq(minChallengeRatio);

  //       const storageMinChallengeRatio = await orManager.minChallengeRatio();
  //       expect(storageMinChallengeRatio).to.deep.eq(minChallengeRatio);
  //     },
  //   ),
  // );

  // it(
  //   'Function updateChallengeUserRatio should succeed',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orManager.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       const challengeUserRatio = 15;

  //       const { events } = await orManager
  //         .updateChallengeUserRatio(getMinEnableTime(), challengeUserRatio)
  //         .then((t) => t.wait());

  //       const args = events![0].args!;
  //       expect(args.challengeUserRatio).to.deep.eq(challengeUserRatio);

  //       const storageChallengeUserRatio = await orManager.challengeUserRatio();
  //       expect(storageChallengeUserRatio).to.deep.eq(challengeUserRatio);
  //     },
  //   ),
  // );

  // it(
  //   'Function updateFeeChallengeSecond should succeed',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orManager.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       const feeChallengeSecond = 25;

  //       const { events } = await orManager
  //         .updateFeeChallengeSecond(getMinEnableTime(), feeChallengeSecond)
  //         .then((t) => t.wait());

  //       const args = events![0].args!;
  //       expect(args.feeChallengeSecond).to.deep.eq(feeChallengeSecond);

  //       const storageFeeChallengeSecond = await orManager.feeChallengeSecond();
  //       expect(storageFeeChallengeSecond).to.deep.eq(feeChallengeSecond);
  //     },
  //   ),
  // );

  // it(
  //   'Function updateFeeTakeOnChallengeSecond should succeed',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orManager.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       const feeTakeOnChallengeSecond = 25;

  //       const { events } = await orManager
  //         .updateFeeTakeOnChallengeSecond(
  //           getMinEnableTime(),
  //           feeTakeOnChallengeSecond,
  //         )
  //         .then((t) => t.wait());

  //       const args = events![0].args!;
  //       expect(args.feeTakeOnChallengeSecond).to.deep.eq(
  //         feeTakeOnChallengeSecond,
  //       );

  //       const storageFeeTakeOnChallengeSecond =
  //         await orManager.feeTakeOnChallengeSecond();
  //       expect(storageFeeTakeOnChallengeSecond).to.deep.eq(
  //         feeTakeOnChallengeSecond,
  //       );
  //     },
  //   ),
  // );

  // it('Function updateMaxMDCLimit should succeed', async function () {
  //   const maxMDCLimit = BigNumber.from(2).pow(64).sub(1);

  //   const { events } = await orManager
  //     .updateMaxMDCLimit(maxMDCLimit)
  //     .then((t) => t.wait());

  //   const args = events![0].args!;
  //   expect(args.maxMDCLimit).to.deep.eq(maxMDCLimit);

  //   const storageMaxMDCLimit = await orManager.maxMDCLimit();
  //   expect(storageMaxMDCLimit).to.deep.eq(maxMDCLimit);
  // });

  // it(
  //   'Function updateExtraTransferContracts should succeed',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orManager.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       const chainIds = [defaultChainInfo.id];
  //       const extraTransferContracts = [
  //         BigNumber.from(
  //           Wallet.createRandom().address.toLowerCase(),
  //         ).toHexString(),
  //       ];

  //       const { events } = await orManager
  //         .updateExtraTransferContracts(
  //           getMinEnableTime(),
  //           chainIds,
  //           extraTransferContracts,
  //         )
  //         .then((t) => t.wait());

  //       const args = events![0].args!;
  //       expect(args.chainIds).to.deep.eq(chainIds);
  //       expect(args.extraTransferContracts).to.deep.eq(extraTransferContracts);

  //       const storageValue = await orManager.getExtraTransferContract(
  //         chainIds[0],
  //       );
  //       expect(storageValue).to.deep.eq(extraTransferContracts[0]);
  //     },
  //   ),
  // );
});
