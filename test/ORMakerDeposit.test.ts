import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect, util } from 'chai';
import { BigNumber, BigNumberish, constants, utils } from 'ethers';
import { ethers } from 'hardhat';
import fs from 'fs';

import {
  BytesLike,
  arrayify,
  defaultAbiCoder,
  keccak256,
} from 'ethers/lib/utils';
import lodash, { random } from 'lodash';
import { BaseTrie } from 'merkle-patricia-tree';
import {
  OREventBinding,
  OREventBinding__factory,
  ORMDCFactory,
  ORMDCFactory__factory,
  ORMakerDeposit,
  ORMakerDeposit__factory,
  ORManager,
  ORManager__factory,
  TestSpv,
  TestSpv__factory,
  TestToken,
  TestToken__factory,
} from '../typechain-types';
import { defaultChainInfo } from './defaults';
import {
  RuleStruct,
  calculateRuleKey,
  calculateRulesTree,
  createMakerRule,
  createRandomRule,
  encodeChallengeRawData,
  getRulesRootUpdatedLogs,
} from './lib/rule';
import {
  verifyinfoBase,
  VerifyInfo,
  challengeInputInfo,
  columnArray,
  embedVersionIncreaseAndEnableTime,
  getEffectiveEbcsFromLogs,
  getMinEnableTime,
  hexToBuffer,
  testReverted,
  testRevertedOwner,
  updateSpv,
  getSecurityCode,
  getVerifyinfo,
  createChallenge,
  getChallengeIdentNumSortList,
  getLastChallengeIdentNum,
} from './utils.test';
import {
  callDataCost,
  chainIdsMock,
  dealersMock,
  getCurrentTime,
  mineXTimes,
} from './lib/mockData';
import { PromiseOrValue } from '../typechain-types/common';
import { VerifierAbi, compile_yul } from '../scripts/utils';
import { randomBytes } from 'crypto';

describe('ORMakerDeposit', () => {
  let signers: SignerWithAddress[];
  let mdcOwner: SignerWithAddress;
  let orManager: ORManager;
  let orManagerEbcs: string[];
  let ebcs: string[];
  let orMDCFactory: ORMDCFactory;
  let orMakerDeposit: ORMakerDeposit;
  let implementation: string;
  let testToken: TestToken;
  let columnArray: columnArray;
  let ebc: OREventBinding;

  before(async function () {
    signers = await ethers.getSigners();
    mdcOwner = signers[1];

    const envORMDCFactoryAddress = process.env['OR_MDC_FACTORY_ADDRESS'];
    assert(
      !!envORMDCFactoryAddress,
      'Env miss [OR_MDC_FACTORY_ADDRESS]. You may need to test ORMDCFactory.test.ts first. Example: npx hardhat test test/ORManager.test test/ORFeeManager.test.ts test/ORMDCFactory.test.ts test/ORMakerDeposit.test.ts',
    );

    orMDCFactory = new ORMDCFactory__factory(signers[0]).attach(
      envORMDCFactoryAddress,
    );
    implementation = await orMDCFactory.implementation();

    orManager = new ORManager__factory(signers[0]).attach(
      await orMDCFactory.manager(),
    );

    if (process.env['EVENT_BINDING_CONTRACT'] != undefined) {
      ebc = OREventBinding__factory.connect(
        process.env['EVENT_BINDING_CONTRACT'],
        signers[0],
      );
      console.log('connect to ebc contract', ebc.address);
    } else {
      ebc = await new OREventBinding__factory(signers[0]).deploy();
      process.env['EVENT_BINDING_CONTRACT'] = ebc.address;
      console.log('Address of ebc:', ebc.address);
    }

    orManagerEbcs = [ebc.address].concat(
      await getEffectiveEbcsFromLogs(orManager),
    );

    const envTestTokenAddress = process.env['TEST_TOKEN_ADDRESS'];

    if (envTestTokenAddress) {
      testToken = new TestToken__factory(mdcOwner).attach(envTestTokenAddress);
      console.log('connect of testToken:', testToken.address);
    } else {
      testToken = await new TestToken__factory(mdcOwner).deploy(
        'TestToken',
        'OTT',
      );
      console.log('Address of testToken:', testToken.address);
      process.env['TEST_TOKEN_ADDRESS'] = testToken.address;
    }
    await testToken.deployed();

    ebcs = lodash.cloneDeep(orManagerEbcs);
    await mineXTimes(60);
  });

  it('Restoring the ORMakerDeposit should succeed', async function () {
    const predictMDCAddress = await orMDCFactory
      .connect(mdcOwner)
      .predictMDCAddress();
    orMakerDeposit = new ORMakerDeposit__factory(mdcOwner).attach(
      predictMDCAddress,
    );
    console.log('connect of mdc:', orMakerDeposit.address);
    const owner = await orMakerDeposit.owner();

    expect(owner).eq(mdcOwner.address);
  });

  it("ORMakerDeposit's functions prefixed with _ should be private", async function () {
    for (const key in orMakerDeposit.functions) {
      expect(key.replace(/^_/, '')).eq(key);
    }
  });

  it(
    'Function updateColumnArray should emit events and update hash',
    embedVersionIncreaseAndEnableTime(
      () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
      async function () {
        const mdcEbcs: string[] = ebcs.slice(0, 8);
        if (process.env['EVENT_BINDING_CONTRACT'] != undefined) {
          mdcEbcs.push(process.env['EVENT_BINDING_CONTRACT']);
        } else {
          mdcEbcs.push(ebc.address);
        }
        mdcEbcs.sort(() => Math.random() - 0.5);

        const mdcDealers: string[] = await dealersMock();
        const chainIds: number[] = chainIdsMock;
        const columnArrayHash = utils.keccak256(
          utils.defaultAbiCoder.encode(
            ['uint256[]', 'uint256[]', 'uint256[]'],
            [mdcDealers, mdcEbcs, chainIds],
          ),
        );
        columnArray = {
          dealers: mdcDealers,
          ebcs: mdcEbcs,
          chainIds: chainIds,
        };
        console.log(
          `columnArray:${columnArray}, columnHash: ${columnArrayHash}`,
        );

        const { events } = await orMakerDeposit
          .updateColumnArray(
            getMinEnableTime(BigNumber.from(await getCurrentTime())),
            mdcDealers,
            mdcEbcs,
            chainIds,
            {
              gasLimit: 10000000,
            },
          )
          .then((t) => t.wait());

        const args = events?.[0].args;
        expect(args?.impl).eq(implementation);
        expect(await orMakerDeposit.columnArrayHash()).eq(columnArrayHash);
        expect(lodash.toPlainObject(args?.ebcs)).to.deep.includes(mdcEbcs);
        expect(lodash.toPlainObject(args?.dealers)).to.deep.includes(
          mdcDealers,
        );

        await testRevertedOwner(
          orMakerDeposit
            .connect(signers[2])
            .updateColumnArray(
              getMinEnableTime(
                (
                  await orMakerDeposit.getVersionAndEnableTime()
                ).enableTime,
              ),
              [],
              mdcEbcs,
              [],
            ),
        );

        await expect(
          orMakerDeposit.updateColumnArray(
            (
              await orMakerDeposit.getVersionAndEnableTime()
            ).enableTime,
            mdcDealers,
            mdcEbcs,
            chainIds,
            {
              gasLimit: 10000000,
            },
          ),
        ).to.revertedWith('OFET');

        await expect(
          orMakerDeposit.updateColumnArray(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ).add(10000000),
            mdcDealers,
            mdcEbcs,
            chainIds,
            {
              gasLimit: 10000000,
            },
          ),
        ).to.revertedWith('OFET');

        // // Test length
        // await testReverted(
        //   orMakerDeposit.updateColumnArray(
        //     getMinEnableTime(
        //       (
        //         await orMakerDeposit.getVersionAndEnableTime()
        //       ).enableTime,
        //     ),
        //     new Array(11).fill(constants.AddressZero),
        //     [],
        //     [],
        //     {
        //       gasLimit: 1e6,
        //     },
        //   ),
        //   'DECOF',
        // );

        // await testReverted(
        //   orMakerDeposit.updateColumnArray(
        //     getMinEnableTime(
        //       (
        //         await orMakerDeposit.getVersionAndEnableTime()
        //       ).enableTime,
        //     ),
        //     [],
        //     new Array(11).fill(constants.AddressZero),
        //     [],
        //   ),
        //   'DECOF',
        // );
        // await testReverted(
        //   orMakerDeposit.updateColumnArray(
        //     getMinEnableTime(
        //       (
        //         await orMakerDeposit.getVersionAndEnableTime()
        //       ).enableTime,
        //     ),
        //     [],
        //     [],
        //     new Array(101).fill(1),
        //   ),
        //   'DECOF',
        // );

        // // Test validity
        // await testReverted(
        //   orMakerDeposit.updateColumnArray(
        //     getMinEnableTime(
        //       (
        //         await orMakerDeposit.getVersionAndEnableTime()
        //       ).enableTime,
        //     ),
        //     [],
        //     [constants.AddressZero],
        //     [],
        //   ),
        //   'EI',
        // );
        // await testReverted(
        //   orMakerDeposit.updateColumnArray(
        //     getMinEnableTime(
        //       (
        //         await orMakerDeposit.getVersionAndEnableTime()
        //       ).enableTime,
        //     ),
        //     [],
        //     [],
        //     [2 ** 16 - 1],
        //   ),
        //   'CI',
        // );
      },
    ),
  );

  it(
    'Function updateSpvs should emit events and update storage',
    embedVersionIncreaseAndEnableTime(
      () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
      async function () {
        const chainId = defaultChainInfo.id;
        const chainInfo = await orManager.getChainInfo(chainId);

        const spvs = chainInfo.spvs.slice(0, 1);
        const chainIds = [chainId];
        console.log(
          `maker update[chainId: ${chainIds.toString()} - spv: ${spvs}]`,
        );

        const { events } = await orMakerDeposit
          .updateSpvs(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            spvs,
            chainIds,
          )
          .then((t) => t.wait());

        events?.forEach((event, index) => {
          expect(event.args?.['impl']).eq(implementation);
          expect(event.args?.['chainId']).eq(chainIds[index]);
          expect(event.args?.['spv']).eq(spvs[index]);
        });

        // eslint-disable-next-line @typescript-eslint/no-for-in-array
        for (const i in chainIds) {
          const spv = await orMakerDeposit.spv(chainIds[i]);
          expect(spv).eq(spvs[i]);
        }

        await testRevertedOwner(
          orMakerDeposit
            .connect(signers[2])
            .updateSpvs(
              getMinEnableTime(
                (
                  await orMakerDeposit.getVersionAndEnableTime()
                ).enableTime,
              ),
              spvs,
              chainIds,
            ),
        );

        await testReverted(
          orMakerDeposit.updateSpvs(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            spvs,
            [2 ** 16 - 1],
          ),
          'CI',
        );
        await testReverted(
          orMakerDeposit.updateSpvs(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            [constants.AddressZero],
            chainIds,
          ),
          'SI',
        );
      },
    ),
  );

  it(
    'Function updateResponseMakers should emit events and update hash',
    embedVersionIncreaseAndEnableTime(
      () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
      async function () {
        const responseSigners = signers.slice(10, 11);
        const responseMakers: BigNumberish[] = [];
        const responseMakerSignatures: BytesLike[] = [];
        const message = arrayify(
          keccak256(
            defaultAbiCoder.encode(['address'], [orMakerDeposit.address]),
          ),
        ); // Convert to byte array to prevent utf-8 decode when signMessage

        for (const s of responseSigners) {
          const signature = await s.signMessage(message);

          responseMakers.push(BigNumber.from(s.address));
          responseMakerSignatures.push(signature);
        }

        utils.verifyMessage(message, responseMakerSignatures[0]);

        const { events } = await orMakerDeposit
          .updateResponseMakers(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            responseMakerSignatures,
          )
          .then((t) => t.wait());

        const args = events?.[0].args;
        expect(args?.responseMakers).to.deep.eq(responseMakers);

        const responseMakersHash = await orMakerDeposit.responseMakersHash();
        expect(responseMakersHash).to.eq(
          keccak256(defaultAbiCoder.encode(['uint[]'], [responseMakers])),
        );

        await testRevertedOwner(
          orMakerDeposit
            .connect(signers[2])
            .updateResponseMakers(
              getMinEnableTime(
                (
                  await orMakerDeposit.getVersionAndEnableTime()
                ).enableTime,
              ),
              responseMakerSignatures,
            ),
        );
      },
    ),
  );

  it('Function deposit should success', async function () {
    const bETHBefore = await mdcOwner.provider?.getBalance(
      orMakerDeposit.address,
    );
    const amountETH = utils.parseEther('0.001');
    await orMakerDeposit
      .deposit(constants.AddressZero, constants.Zero, { value: amountETH })
      .then((t) => t.wait());
    const bETHAfter = await mdcOwner.provider?.getBalance(
      orMakerDeposit.address,
    );
    expect(bETHAfter?.sub(bETHBefore || 0)).eq(amountETH);

    const bERC20Before = await testToken.balanceOf(orMakerDeposit.address);
    const amountERC20 = utils.parseEther('0.001');
    await testToken
      .approve(orMakerDeposit.address, amountERC20)
      .then((t) => t.wait());
    await orMakerDeposit
      .deposit(testToken.address, amountERC20)
      .then((t) => t.wait());
    const bERC20After = await testToken.balanceOf(orMakerDeposit.address);
    expect(bERC20After.sub(bERC20Before)).eq(amountERC20);
  });

  it(
    'Function updateRulesRoot should emit events and update storage',
    embedVersionIncreaseAndEnableTime(
      () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
      async function () {
        // const currentBlock = await mdcOwner.provider?.getBlock('latest');
        const getNative = true;

        const rules: any[] = [];
        for (let i = 0; i < 5 * 4; i++) {
          const _rule = createRandomRule(getNative);
          // _rule[0] = Number(_rule[0]) + i;
          // _rule[1] = Number(_rule[1]) + i;
          // _rule[4] = 0;
          // _rule[5] = 0;
          // console.log(`ethRule - ${ i } : [${ _rule }]`);
          rules.push(_rule);
        }

        const tree = await calculateRulesTree(rules);
        const root = utils.hexlify(tree.root);

        const rootWithVersion = { root, version: 1 };
        const sourceChainIds = [1];
        const pledgeAmounts = [utils.parseEther('0.0001')];

        console.log(`ebc : [${ebc.address}]`);
        await testReverted(
          orMakerDeposit.updateRulesRoot(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            ebc.address,
            rules,
            rootWithVersion,
            sourceChainIds,
            pledgeAmounts,
          ),
          'IV',
        );

        const { events } = await orMakerDeposit
          .updateRulesRoot(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            ebc.address,
            rules,
            rootWithVersion,
            sourceChainIds,
            pledgeAmounts,
            {
              value: pledgeAmounts.reduce((pv, cv) => pv.add(cv)),
            },
          )
          .then((t) => t.wait());

        if (!!events) {
          const txrc = await ethers.provider.getTransaction(
            events[0].transactionHash,
          );
          const recpt = await ethers.provider.getTransactionReceipt(
            events[0].transactionHash,
          );
          const inpudataGas = callDataCost(txrc.data);
          console.log(
            `updateRule, totoalGas: ${recpt.gasUsed}, callDataGasCost: ${inpudataGas}`,
          );
        }
        const args = events?.[0].args;
        expect(args?.ebc).eq(ebc.address);
        expect(args?.rootWithVersion.root).eq(rootWithVersion.root);
        expect(args?.rootWithVersion.version).eq(rootWithVersion.version);

        await testReverted(
          orMakerDeposit.updateRulesRoot(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            ebc.address,
            rules,
            rootWithVersion,
            [],
            [],
          ),
          'VE',
        );
        await testRevertedOwner(
          orMakerDeposit
            .connect(signers[2])
            .updateRulesRoot(
              getMinEnableTime(
                (
                  await orMakerDeposit.getVersionAndEnableTime()
                ).enableTime,
              ),
              ebc.address,
              rules,
              { ...rootWithVersion, version: 2 },
              [],
              [],
            ),
        );

        const storageRWV = await orMakerDeposit.rulesRoot(ebc.address);
        expect(storageRWV.root).eq(rootWithVersion.root);
        expect(storageRWV.version).eq(rootWithVersion.version);

        const key = hexToBuffer(calculateRuleKey(lodash.sample(rules)));
        const proof = await BaseTrie.createProof(tree, key);
        const v = await BaseTrie.verifyProof(
          hexToBuffer(storageRWV.root),
          key,
          proof,
        );
        expect(v !== null).to.be.true;
      },
    ),
  );

  it('Event RulesRootUpdated should emit logs', async function () {
    const rules = await getRulesRootUpdatedLogs(
      signers[0].provider,
      orMakerDeposit.address,
      implementation,
    );
    const tree = await calculateRulesTree(rules);
    const root = utils.hexlify(tree.root);

    const storageRWV = await orMakerDeposit.rulesRoot(ebc.address);
    expect(storageRWV.root).eq(root);
  });

  it(
    'Function updateRulesRootErc20 should emit events and update storage',
    embedVersionIncreaseAndEnableTime(
      () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
      async function () {
        const getNative = false;
        const totalRules: any[] = await getRulesRootUpdatedLogs(
          signers[0].provider,
          orMakerDeposit.address,
          implementation,
        );

        const rules: any[] = [];
        for (let i = 0; i < 5 * 4; i++) {
          const _rule = createRandomRule(getNative);
          totalRules.push(_rule);
          // console.log(`erc20Rule - ${ i } : [${ _rule }]`);
          rules.push(_rule);
        }

        const rootWithVersion = await orMakerDeposit.rulesRoot(ebc.address);

        const tree = await calculateRulesTree(totalRules);
        const root = utils.hexlify(tree.root);
        const sourceChainIds = [rules[rules.length - 1][0]];
        const pledgeAmounts = [utils.parseEther('0.0001')];

        const balanceBefore = await testToken.balanceOf(mdcOwner.address);

        // Approve
        const approveAmount = pledgeAmounts.reduce((pv, cv) => pv.add(cv));
        await testToken
          .approve(orMakerDeposit.address, approveAmount)
          .then((t) => t.wait());

        await orMakerDeposit
          .updateRulesRootERC20(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            ebc.address,
            rules,
            { root, version: rootWithVersion.version + 1 },
            sourceChainIds,
            pledgeAmounts,
            testToken.address,
          )
          .then((t) => t.wait());

        const balanceAfter = await testToken.balanceOf(mdcOwner.address);
        expect(balanceBefore.sub(balanceAfter)).eq(approveAmount);

        await testReverted(
          orMakerDeposit.updateRulesRootERC20(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            ebc.address,
            rules,
            { root, version: rootWithVersion.version + 1 },
            sourceChainIds,
            pledgeAmounts,
            testToken.address,
          ),
          'VE',
        );
        await testReverted(
          orMakerDeposit.updateRulesRootERC20(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            ebc.address,
            rules,
            { root, version: rootWithVersion.version + 2 },
            [],
            pledgeAmounts,
            testToken.address,
          ),
          'SPL',
        );
        await testRevertedOwner(
          orMakerDeposit
            .connect(signers[2])
            .updateRulesRootERC20(
              getMinEnableTime(
                (
                  await orMakerDeposit.getVersionAndEnableTime()
                ).enableTime,
              ),
              ebc.address,
              rules,
              { root, version: rootWithVersion.version + 2 },
              sourceChainIds,
              pledgeAmounts,
              testToken.address,
            ),
        );
      },
    ),
  );

  it('Function withdraw should success', async function () {
    const bETHBefore = await mdcOwner.provider?.getBalance(mdcOwner.address);
    const M_ETH_Before = await ethers.provider.getBalance(
      orMakerDeposit.address,
    );
    const firstRequestInfo = await orMakerDeposit?.getWithdrawRequestInfo(
      constants.AddressZero,
    );
    expect(BigNumber.from(firstRequestInfo.requestTimestamp)).eq(0);
    await testReverted(orMakerDeposit.withdraw(constants.AddressZero), 'WTN');
    const amountETH = utils.parseEther('0.001');
    const requestReceipt = await orMakerDeposit
      .withdrawRequest(constants.AddressZero, amountETH)
      .then((t) => t.wait());
    const secondRequestInfo = await orMakerDeposit?.getWithdrawRequestInfo(
      constants.AddressZero,
    );
    expect(BigNumber.from(secondRequestInfo.requestTimestamp)).gt(0);
    await testReverted(
      orMakerDeposit.withdrawRequest(constants.AddressZero, amountETH),
      'RHB',
    );
    await testReverted(orMakerDeposit.withdraw(constants.AddressZero), 'WTN');
    const currentBlockInfo = await ethers.provider.getBlock('latest');
    await mineXTimes(
      BigNumber.from(secondRequestInfo.requestTimestamp)
        .sub(currentBlockInfo.timestamp)
        .toNumber(),
      true,
    );
    const withdrawReceipt = await orMakerDeposit
      .withdraw(constants.AddressZero)
      .then((t) => t.wait());
    const thirdRequestInfo = await orMakerDeposit?.getWithdrawRequestInfo(
      constants.AddressZero,
    );
    expect(BigNumber.from(thirdRequestInfo.requestTimestamp)).eq(0);
    const bETHAfter = await mdcOwner.provider?.getBalance(mdcOwner.address);
    const requestGasUsed = requestReceipt.gasUsed.mul(
      requestReceipt.effectiveGasPrice,
    );
    const withdrawGasUsed = withdrawReceipt.gasUsed.mul(
      withdrawReceipt.effectiveGasPrice,
    );
    expect(
      bETHAfter
        ?.add(requestGasUsed)
        .add(withdrawGasUsed)
        .sub(bETHBefore || 0),
    ).eq(amountETH);

    const M_ETH_After = await ethers.provider.getBalance(
      orMakerDeposit.address,
    );

    expect(amountETH?.add(M_ETH_After)).eq(M_ETH_Before);

    await testRevertedOwner(
      orMakerDeposit
        .connect(signers[2])
        .withdrawRequest(constants.AddressZero, amountETH),
    );

    await testRevertedOwner(
      orMakerDeposit.connect(signers[2]).withdraw(constants.AddressZero),
    );
  });

  describe('start challenge test module', () => {
    let spv: TestSpv;
    let verifyContract: { address: PromiseOrValue<string> };
    const makerRule: RuleStruct = createMakerRule(true);
    const chainId = makerRule.chainId0;
    const chainIdDest = makerRule.chainId1;
    const freezeToken: string = constants.AddressZero;
    const freeTokenDest: string = constants.AddressZero;

    const getRawData = async (
      columnArray: columnArray,
      ebc: string,
      makerRule: RuleStruct,
    ): Promise<utils.BytesLike> => {
      const jsEncode = encodeChallengeRawData(
        columnArray.dealers,
        columnArray.ebcs,
        columnArray.chainIds,
        ebc,
        makerRule,
      );

      const contractEncode = await spv.encodeRawDatas(
        columnArray.dealers,
        columnArray.ebcs,
        columnArray.chainIds,
        ebc,
        makerRule,
      );

      expect(jsEncode).eql(contractEncode);

      {
        const { dealers, ebcs, chainIds, ebc, rule } = await spv.decodeRawDatas(
          utils.arrayify(jsEncode),
        );
        expect(dealers).eql(columnArray.dealers);
        expect(ebcs).eql(columnArray.ebcs);
        expect(chainIds.toString()).eql(columnArray.chainIds.toString());
        expect(rule.chainId0).eql(makerRule.chainId0);
        expect(rule.chainId1).eql(makerRule.chainId1);
        expect(rule.status0).eql(makerRule.status0);
        expect(rule.status1).eql(makerRule.status1);
      }
      const columnArrayHash = utils.keccak256(
        utils.defaultAbiCoder.encode(
          ['uint256[]', 'uint256[]', 'uint256[]'],
          [columnArray.dealers, columnArray.ebcs, columnArray.chainIds],
        ),
      );
      expect(columnArrayHash).eql(await orMakerDeposit.columnArrayHash());

      return utils.arrayify(contractEncode);
    };

    // before(async function () {
    //   const verifyBytesCode = await compile_yul(
    //     'contracts/zkp/goerli_1_evm.yul',
    //   );

    //   const verifyFactory = new ethers.ContractFactory(
    //     VerifierAbi,
    //     verifyBytesCode,
    //     mdcOwner,
    //   );
    //   verifyContract = await verifyFactory.deploy();
    //   spv = await new TestSpv__factory(mdcOwner).deploy(verifyContract.address);

    //   console.log(
    //     `Address of verifier: ${verifyContract.address}, Address of spv: ${spv.address}, Address of ebc ${ebc.address} `,
    //   );
    // });

    // it('test function verifyChallengeSource Revert case', async function () {
    //   const latestBlockRes = await orMakerDeposit.provider?.getBlock('latest');
    //   const sourceTxTime = random(5000000);
    //   const sourceChainId = random(200);
    //   const sourceBlockNum = random(latestBlockRes.number);
    //   const sourceTxIndex = random(100);
    //   const challengeIdentNum = getChallengeIdentNumSortList(
    //     sourceTxTime,
    //     sourceChainId,
    //     sourceBlockNum,
    //     sourceTxIndex,
    //   );
    //   const challenge: challengeInputInfo = {
    //     sourceTxTime: sourceTxTime,
    //     sourceChainId: sourceChainId,
    //     sourceBlockNum: sourceBlockNum,
    //     sourceTxIndex: sourceTxIndex,
    //     sourceTxHash: utils.keccak256(mdcOwner.address),
    //     from: await orMakerDeposit.owner(),
    //     freezeToken: constants.AddressZero,
    //     freezeAmount: utils.parseEther('0.001'),
    //     lastChallengeIdentNum: getLastChallengeIdentNum([], challengeIdentNum),
    //   };
    //   await createChallenge(orMakerDeposit, challenge);
    //   const invalidVerifyInfo0: VerifyInfo = {
    //     data: [1],
    //     slots: [
    //       {
    //         account: constants.AddressZero,
    //         key: utils.keccak256(mdcOwner.address),
    //         value: 1,
    //       },
    //     ],
    //   };
    //   const invalidSPV0 = constants.AddressZero;
    //   await expect(
    //     orMakerDeposit.verifyChallengeSource(
    //       invalidSPV0,
    //       [],
    //       [
    //         utils.keccak256(mdcOwner.address),
    //         utils.keccak256(mdcOwner.address),
    //       ],
    //       invalidVerifyInfo0,
    //       [],
    //     ),
    //   ).to.revertedWith('SI');
    //   const chainId = defaultChainInfo.id;
    //   const invalidVerifyInfo1: VerifyInfo = {
    //     data: [chainId.toString()],
    //     slots: [
    //       {
    //         account: constants.AddressZero,
    //         key: utils.keccak256(mdcOwner.address),
    //         value: 1,
    //       },
    //     ],
    //   };
    //   await expect(
    //     orMakerDeposit.verifyChallengeSource(
    //       invalidSPV0,
    //       [],
    //       [
    //         utils.keccak256(mdcOwner.address),
    //         utils.keccak256(mdcOwner.address),
    //       ],
    //       invalidVerifyInfo1,
    //       [],
    //     ),
    //   ).to.revertedWith('SI');
    // });

    it('test function challenge _addChallengeNode', async function () {
      let challengeIdentNumList: bigint[] = [];
      const challengeInputInfos: challengeInputInfo[] = [];
      const latestBlockRes = await orMakerDeposit.provider?.getBlock('latest');
      for (let i = 0; i < 5; i++) {
        const sourceTxTime = random(latestBlockRes.timestamp - 86400);
        const sourceChainId = random(500000);
        const sourceBlockNum = random(latestBlockRes.number);
        const sourceTxIndex = random(i);
        const challengeIdentNum = getChallengeIdentNumSortList(
          sourceTxTime,
          sourceChainId,
          sourceBlockNum,
          sourceTxIndex,
        );
        challengeIdentNumList.push(challengeIdentNum);
        const lastChallengeIdentNum = getLastChallengeIdentNum(
          challengeIdentNumList,
          challengeIdentNum,
        );
        const challengeInputInfo = {
          sourceTxTime,
          sourceChainId,
          sourceBlockNum,
          sourceTxIndex,
          sourceTxHash: utils.keccak256(mdcOwner.address),
          from: await orMakerDeposit.owner(),
          freezeToken: constants.AddressZero,
          freezeAmount: utils.parseEther('0.001'),
          lastChallengeIdentNum,
        };
        challengeInputInfos.push(challengeInputInfo);
        await createChallenge(orMakerDeposit, challengeInputInfo);
      }
      challengeIdentNumList = challengeIdentNumList.sort((a, b) => {
        if (a > b) return -1;
        if (a < b) return 1;
        return 0;
      });
      const lastEleSortNumber = BigNumber.from(challengeIdentNumList[0]);
      const firstEleSortNumber = BigNumber.from(
        challengeIdentNumList[challengeIdentNumList?.length - 1],
      );
      expect(lastEleSortNumber).gt(firstEleSortNumber);
      const canVerify = await orMakerDeposit.getCanChallengeContinue(
        firstEleSortNumber,
      );
      const cantVerify = await orMakerDeposit.getCanChallengeContinue(
        lastEleSortNumber,
      );
      expect(canVerify).to.be.true;
      expect(cantVerify).to.be.false;
      const maxNumInputInfo: challengeInputInfo = challengeInputInfos.find(
        (v) =>
          getChallengeIdentNumSortList(
            v.sourceTxTime,
            v.sourceChainId,
            v.sourceBlockNum,
            v.sourceTxIndex,
          ) === challengeIdentNumList[0],
      );
      const addRequireInputInfo = {
        sourceTxTime: maxNumInputInfo.sourceTxTime - 100000,
        sourceChainId:
          BigNumber.from(maxNumInputInfo.sourceChainId).toNumber() - 1,
        sourceBlockNum: maxNumInputInfo.sourceBlockNum,
        sourceTxIndex: maxNumInputInfo.sourceTxIndex,
        sourceTxHash: utils.keccak256(mdcOwner.address),
        from: await orMakerDeposit.owner(),
        freezeToken: constants.AddressZero,
        freezeAmount: utils.parseEther('0.001'),
        lastChallengeIdentNum: 0,
      };
      await expect(
        createChallenge(orMakerDeposit, addRequireInputInfo),
      ).to.revertedWith('LCINE');
    });

    // it('test prase spv proof data', async function () {
    //   const fake_spvProof: BytesLike = utils.keccak256(mdcOwner.address);
    //   const spvProof: BytesLike = utils.arrayify(
    //     '0x' + fs.readFileSync('test/example/spv.calldata', 'utf-8'),
    //   );

    //   const { blockHash, toAddress, transferAmount, timestamp } =
    //     await spv.parseProofData(spvProof);
    //   console.log(
    //     `blcokHash: ${blockHash}, toAddress: ${toAddress}, transferAmount: ${transferAmount}, timestamp: ${timestamp} `,
    //   );

    //   await expect(spv.verifyProof(fake_spvProof)).to.revertedWith(
    //     'verify fail',
    //   );

    //   const tx = await spv.verifyProof(spvProof).then((t) => t.wait());
    //   expect(tx.status).to.be.eq(1);
    //   const txrc = await ethers.provider.getTransaction(tx.transactionHash);
    //   const inpudataGas = callDataCost(txrc.data);
    //   console.log(
    //     // eslint-disable-next-line prettier/prettier
    //     `verify totalGas: ${
    //       tx.gasUsed
    //     }, callDataGas: ${inpudataGas}, excuteGas: ${
    //       tx.gasUsed.toNumber() - inpudataGas
    //     } `,
    //   );
    // });

    // it('create challenge test', async function () {
    //   const case1SourceChainId = chainId;
    //   const case1SourceTxHash = utils.keccak256(randomBytes(100));
    //   const case1freezeAmount = utils.formatEther(100000000000001111n);
    //   console.log(
    //     `New rule - chain: ${makerRule.chainId0} --> chain: ${makerRule.chainId1}`,
    //   );
    //   const latestBlockRes = await orMakerDeposit.provider?.getBlock('latest');
    //   const sourceTxTime = (await getCurrentTime()) - 1;
    //   const sourceChainId = case1SourceChainId;
    //   const sourceBlockNum = random(latestBlockRes.number);
    //   const sourceTxIndex = random(100);
    //   const challengeIdentNum = getChallengeIdentNumSortList(
    //     sourceTxTime,
    //     sourceChainId,
    //     sourceBlockNum,
    //     sourceTxIndex,
    //   );
    //   const challenge: challengeInputInfo = {
    //     sourceTxTime: (await getCurrentTime()) - 1,
    //     sourceChainId: case1SourceChainId,
    //     sourceBlockNum,
    //     sourceTxIndex,
    //     sourceTxHash: case1SourceTxHash,
    //     from: await orMakerDeposit.owner(),
    //     freezeToken: constants.AddressZero,
    //     freezeAmount: utils.parseEther(case1freezeAmount),
    //     lastChallengeIdentNum: getLastChallengeIdentNum([], challengeIdentNum),
    //   };
    //   const case1balanceOfMakerbefore = utils.formatEther(
    //     await ethers.provider.getBalance(orMakerDeposit.address),
    //   );
    //   await expect(
    //     orMakerDeposit.checkChallenge(
    //       case1SourceChainId,
    //       case1SourceTxHash,
    //       [],
    //     ),
    //   ).to.revertedWith('CNE');
    //   const challengeIdentNumFake = getChallengeIdentNumSortList(
    //     (await getCurrentTime()) + 7800,
    //     challenge.sourceChainId,
    //     sourceBlockNum,
    //     sourceTxIndex,
    //   );
    //   const challengeFake: challengeInputInfo = {
    //     sourceTxTime: (await getCurrentTime()) + 7800,
    //     sourceChainId: challenge.sourceChainId,
    //     sourceBlockNum,
    //     sourceTxIndex,
    //     sourceTxHash: challenge.sourceTxHash,
    //     from: await orMakerDeposit.owner(),
    //     freezeToken: challenge.freezeToken,
    //     freezeAmount: challenge.freezeAmount,
    //     lastChallengeIdentNum: getLastChallengeIdentNum(
    //       [],
    //       challengeIdentNumFake,
    //     ),
    //   };
    //   await createChallenge(orMakerDeposit, challengeFake, 'STOF');
    //   await createChallenge(orMakerDeposit, challenge);
    //   await createChallenge(orMakerDeposit, challenge, 'CE');

    //   await mineXTimes(100);
    //   expect(
    //     await orMakerDeposit.checkChallenge(
    //       case1SourceChainId,
    //       case1SourceTxHash,
    //       [],
    //     ),
    //   ).to.be.satisfy;
    //   const case1balanceOfMakerAfter = utils.formatEther(
    //     await ethers.provider.getBalance(orMakerDeposit.address),
    //   );
    //   // console.log(
    //   //   `challenge 1 balanceOfMakerbefore: ${ case1balanceOfMakerbefore }, balanceOfMakerAfter: ${ case1balanceOfMakerAfter }, freezeAmount: ${ case1freezeAmount } `,
    //   // );
    //   expect(parseFloat(case1balanceOfMakerAfter).toFixed(2)).equal(
    //     (parseFloat(case1balanceOfMakerbefore) + parseFloat(case1freezeAmount))
    //       .toFixed(2)
    //       .toString(),
    //   );

    //   await expect(
    //     orMakerDeposit.checkChallenge(
    //       case1SourceChainId,
    //       case1SourceTxHash,
    //       [],
    //     ),
    //   ).to.revertedWith('CNE');
    //   const challengeIdentNum2 = getChallengeIdentNumSortList(
    //     (await getCurrentTime()) - 1,
    //     challenge.sourceChainId,
    //     sourceBlockNum,
    //     sourceTxIndex,
    //   );
    //   const challenge2: challengeInputInfo = {
    //     sourceTxTime: (await getCurrentTime()) - 1,
    //     sourceChainId: challenge.sourceChainId,
    //     sourceBlockNum,
    //     sourceTxIndex,
    //     sourceTxHash: challenge.sourceTxHash,
    //     from: await orMakerDeposit.owner(),
    //     freezeToken: challenge.freezeToken,
    //     freezeAmount: challenge.freezeAmount,
    //     lastChallengeIdentNum: getLastChallengeIdentNum([], challengeIdentNum2),
    //   };
    //   await createChallenge(orMakerDeposit, challenge2);

    //   const case2balanceOfMakerAfter = utils.formatEther(
    //     await ethers.provider.getBalance(orMakerDeposit.address),
    //   );
    //   expect(parseFloat(case2balanceOfMakerAfter).toFixed(2)).equal(
    //     (parseFloat(case1balanceOfMakerAfter) + parseFloat(case1freezeAmount))
    //       .toFixed(2)
    //       .toString(),
    //   );
    //   // console.log(
    //   //   `challenge 2 balanceOfMakerbefore: ${ case1balanceOfMakerAfter }, balanceOfMakerAfter: ${ case2balanceOfMakerAfter }, freezeAmount: ${ case1freezeAmount } `,
    //   // );

    //   await expect(
    //     orMakerDeposit.checkChallenge(
    //       case1SourceChainId,
    //       case1SourceTxHash,
    //       [],
    //     ),
    //   ).to.revertedWith('VCST');

    //   await mineXTimes(100);

    //   expect(
    //     await orMakerDeposit.checkChallenge(
    //       case1SourceChainId,
    //       case1SourceTxHash,
    //       [],
    //     ),
    //   ).to.be.satisfy;

    //   await expect(
    //     orMakerDeposit.checkChallenge(
    //       case1SourceChainId,
    //       case1SourceTxHash,
    //       [],
    //     ),
    //   ).to.revertedWith('CNE');
    // });

    // it('challenge Verify Source TX should success', async function () {
    //   const testFreezeAmount =
    //     '10000000000000' +
    //     getSecurityCode(
    //       columnArray,
    //       ebc.address,
    //       mdcOwner.address,
    //       parseInt(chainIdDest.toString()),
    //     );
    //   const case1SourceChainId = chainId;
    //   const destChainId = chainIdDest;
    //   const case1SourceTxHash = utils.keccak256(randomBytes(100));
    //   const case1freezeAmount = utils.formatEther(
    //     BigNumber.from(testFreezeAmount),
    //   );
    //   const latestBlockRes = await orMakerDeposit.provider?.getBlock('latest');
    //   const sourceTxTime = (await getCurrentTime()) - 1;
    //   const sourceChainId = case1SourceChainId;
    //   const sourceBlockNum = random(latestBlockRes.number);
    //   const sourceTxIndex = random(100);
    //   const challengeIdentNum = getChallengeIdentNumSortList(
    //     sourceTxTime,
    //     sourceChainId,
    //     sourceBlockNum,
    //     sourceTxIndex,
    //   );
    //   const challenge: challengeInputInfo = {
    //     sourceTxTime: (await getCurrentTime()) - 1,
    //     sourceChainId: case1SourceChainId,
    //     sourceBlockNum,
    //     sourceTxIndex,
    //     sourceTxHash: case1SourceTxHash,
    //     from: await orMakerDeposit.owner(),
    //     freezeToken: freezeToken,
    //     freezeAmount: utils.parseEther(case1freezeAmount),
    //     lastChallengeIdentNum: getLastChallengeIdentNum([], challengeIdentNum),
    //   };

    //   const verifyinfoBase: verifyinfoBase = {
    //     chainIdDest: destChainId,
    //     freeTokenDest: freeTokenDest,
    //     ebc: ebc.address,
    //   };

    //   // spv should be setting by manager
    //   await updateSpv(challenge, spv.address, orManager);

    //   // get related slots & values of maker/manager contract
    //   const verifyInfo = await getVerifyinfo(
    //     orMakerDeposit,
    //     orManager,
    //     spv,
    //     challenge,
    //     verifyinfoBase,
    //     makerRule,
    //   );

    //   const rawData = await getRawData(columnArray, ebc.address, makerRule);

    //   await createChallenge(orMakerDeposit, challenge);

    //   await mineXTimes(2);

    //   expect(
    //     await orMakerDeposit.verifyChallengeSource(
    //       spv.address,
    //       [],
    //       [
    //         utils.keccak256(mdcOwner.address),
    //         utils.keccak256(mdcOwner.address),
    //       ],
    //       verifyInfo,
    //       rawData,
    //       {
    //         gasLimit: 10000000,
    //       },
    //     ),
    //   ).is.satisfy;
    // });
  });
});
