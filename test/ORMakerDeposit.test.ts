import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumber, BigNumberish, constants, utils } from 'ethers';
import { ethers } from 'hardhat';
import fs from 'fs';
import { getMappingStructXSlot } from './lib/readStorage';

import {
  BytesLike,
  arrayify,
  defaultAbiCoder,
  keccak256,
  solidityPack,
} from 'ethers/lib/utils';
import lodash, { random } from 'lodash';
import { BaseTrie } from 'merkle-patricia-tree';
import {
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
  calculateRuleKey,
  calculateRulesTree,
  createRandomRule,
  getRulesRootUpdatedLogs,
} from './lib/rule';
import {
  embedVersionIncreaseAndEnableTime,
  getEffectiveEbcsFromLogs,
  getMinEnableTime,
  hexToBuffer,
  testReverted,
  testRevertedOwner,
} from './utils.test';
import {
  callDataCost,
  chainIdsMock,
  dealersMock,
  ebcMock,
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
  let ebcSample: string;
  let testToken: TestToken;

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
    orManagerEbcs = await getEffectiveEbcsFromLogs(orManager);

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
          mdcEbcs.push(ebcMock);
        }
        mdcEbcs.sort(() => Math.random() - 0.5);

        const mdcDealers: string[] = await dealersMock();
        const chainIds: number[] = chainIdsMock;
        const columnArrayHash = utils.keccak256(
          utils.solidityPack(
            ['uint256[]', 'uint256[]', 'uint256[]'],
            [mdcDealers, mdcEbcs, chainIds],
          ),
        );

        console.log(
          `mdcDealers: ${mdcDealers}, mdcEbcs: ${mdcEbcs}, mdcChainIds: ${chainIds}, columnArrayHash: ${columnArrayHash}`,
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
          `maker update [chainId:${chainIds.toString()} - spv:${spvs}]`,
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
          // console.log(`ethRule-${i} :[${_rule}]`);
          rules.push(_rule);
        }

        const tree = await calculateRulesTree(rules);
        const root = utils.hexlify(tree.root);
        if (process.env['EVENT_BINDING_CONTRACT'] != undefined) {
          ebcSample = process.env['EVENT_BINDING_CONTRACT'];
        } else {
          ebcSample = ebcMock;
        }

        const rootWithVersion = { root, version: 1 };
        const sourceChainIds = [1];
        const pledgeAmounts = [utils.parseEther('0.0001')];

        console.log(`ebc :[${ebcSample}]`);
        // await testReverted(
        //   orMakerDeposit.updateRulesRoot(
        //     getMinEnableTime(
        //       (
        //         await orMakerDeposit.getVersionAndEnableTime()
        //       ).enableTime,
        //     ),
        //     ebcSample,
        //     rules,
        //     rootWithVersion,
        //     sourceChainIds,
        //     pledgeAmounts,
        //   ),
        //   'IV',
        // );
        const { events } = await orMakerDeposit
          .updateRulesRoot(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            ebcSample,
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
            `updateRule, totoalGas: ${recpt.gasUsed}, callDataGasCost:${inpudataGas}`,
          );
        }
        const args = events?.[0].args;
        expect(args?.ebc).eq(ebcSample);
        expect(args?.rootWithVersion.root).eq(rootWithVersion.root);
        expect(args?.rootWithVersion.version).eq(rootWithVersion.version);

        await testReverted(
          orMakerDeposit.updateRulesRoot(
            getMinEnableTime(
              (
                await orMakerDeposit.getVersionAndEnableTime()
              ).enableTime,
            ),
            ebcSample,
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
              ebcSample,
              rules,
              { ...rootWithVersion, version: 2 },
              [],
              [],
            ),
        );

        const storageRWV = await orMakerDeposit.rulesRoot(ebcSample);
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

    const storageRWV = await orMakerDeposit.rulesRoot(ebcSample);
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

        const rootWithVersion = await orMakerDeposit.rulesRoot(ebcSample);

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
            ebcSample,
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
            ebcSample,
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
            ebcSample,
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
              ebcSample,
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
    const firstVerifyStatus = await orMakerDeposit?.getWithdrawVerifyStatus(
      constants.AddressZero,
    );
    expect(BigNumber.from(firstVerifyStatus.request_timestamp)).eq(0);
    await testReverted(orMakerDeposit.withdraw(constants.AddressZero), 'WTN');
    const amountETH = utils.parseEther('0.001');
    const requestReceipt = await orMakerDeposit
      .withdrawRequest(constants.AddressZero, amountETH)
      .then((t) => t.wait());
    const secondVerifyStatus = await orMakerDeposit?.getWithdrawVerifyStatus(
      constants.AddressZero,
    );
    expect(BigNumber.from(secondVerifyStatus.request_timestamp)).gt(0);
    await testReverted(
      orMakerDeposit.withdrawRequest(constants.AddressZero, amountETH),
      'RHB',
    );
    await testReverted(orMakerDeposit.withdraw(constants.AddressZero), 'WTN');
    const currentBlockInfo = await ethers.provider.getBlock('latest');
    await mineXTimes(
      BigNumber.from(secondVerifyStatus.request_timestamp)
        .sub(currentBlockInfo.timestamp)
        .toNumber(),
      true,
    );
    const withdrawReceipt = await orMakerDeposit
      .withdraw(constants.AddressZero)
      .then((t) => t.wait());
    const thirdVerifyStatus = await orMakerDeposit?.getWithdrawVerifyStatus(
      constants.AddressZero,
    );
    expect(BigNumber.from(thirdVerifyStatus.request_timestamp)).eq(0);
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

    await testRevertedOwner(
      orMakerDeposit
        .connect(signers[2])
        .withdrawRequest(constants.AddressZero, amountETH),
    );

    await testRevertedOwner(
      orMakerDeposit.connect(signers[2]).withdraw(constants.AddressZero),
    );
  });

  describe('ORMakerDeposit challenge', () => {
    let spv: TestSpv;
    let verifyContract: { address: PromiseOrValue<string> };
    const chainId = 5;
    interface challengeInputInfo {
      sourceChainId: BigNumberish;
      sourceTxHash: BigNumberish;
      sourceTxTime: BigNumberish;
      freezeToken: string;
      freezeAmount: BigNumberish;
    }

    interface verifyinfoBase {
      freeTokenDest: string;
      chainIdDest: BigNumberish;
      ebc: string;
    }

    interface VerifyInfoSlotStruct {
      account: string;
      key: BytesLike;
      value: BigNumberish;
    }

    interface VerifyInfo {
      data: BigNumberish[];
      slots: VerifyInfoSlotStruct[];
    }

    /**
     * notice: this function *only* used to check the current slot of contract,
     * it cannot be used to check the historical slots.
     * In production environments, historical slot values will be used.
     * @param {ORMakerDeposit} maker - ORMakerDeposit contract
     * @param {ORManager} manager - ORManager contract
     * @param {challengeInputInfo} challenge - carry basic challenge info
     * @return {VerifyInfoSlotStruct[]} The parameters of verifyChallengeSource()
     */
    const getVerifyinfoSlots = async (
      maker: ORMakerDeposit,
      manager: ORManager,
      challenge: challengeInputInfo,
      verifyinfoBase: verifyinfoBase,
    ): Promise<VerifyInfoSlotStruct[]> => {
      const managerAddress = manager.address;
      const makerAddress = maker.address;
      const chainId = challenge.sourceChainId;
      const chainId_Dest = verifyinfoBase.chainIdDest;
      const freezeToken_Dest = verifyinfoBase.freeTokenDest;
      const freezeToken = challenge.freezeToken;
      const ebc = verifyinfoBase.ebc;

      // set Verifyinfo 0
      // ORManager.sol - ChainInfo - maxVerifyChallengeSourceTxSecond | minVerifyChallengeSourceTxSecond
      // slot 2
      let slot0;
      const slot0_I = keccak256(
        solidityPack(['uint256', 'uint256'], [chainId, 2]),
      );
      const value0 =
        utils.hexZeroPad(
          (
            await orManager.getChainInfo(5)
          ).maxVerifyChallengeSourceTxSecond.toHexString(),
          8,
        ) +
        utils
          .hexZeroPad(
            (
              await orManager.getChainInfo(5)
            ).minVerifyChallengeSourceTxSecond.toHexString(),
            8,
          )
          .slice(2);
      {
        const { slot, itemSlot, value } = await getMappingStructXSlot(
          '0x2',
          managerAddress,
          BigNumber.from(chainId).toHexString(),
          1,
          'number',
        );

        const newValue =
          '0x' +
          BigNumber.from(await value)
            .toHexString()
            .slice(-32);
        const storageValue =
          '0x' +
          (
            await ethers.provider.getStorageAt(
              managerAddress,
              utils.hexZeroPad(itemSlot, 32),
            )
          ).slice(-32);
        slot0 = itemSlot;
        expect(slot0_I)
          .to.equal(slot)
          .to.equal(BigNumber.from(itemSlot).sub(1));
        expect(value0).to.equal(newValue).to.equal(storageValue);
      }
      // --------------------------------------------------------------
      // set Verifyinfo 1
      // ORManager.sol - chainTokenInfo - mainnetToken
      // slot 3
      let slot1;
      const slot1_I = keccak256(
        solidityPack(
          ['uint256', 'uint256'],
          [
            keccak256(
              solidityPack(['uint256', 'uint256'], [chainId, freezeToken]),
            ),
            3,
          ],
        ),
      );
      const value1 = (await orManager.getChainTokenInfo(chainId, freezeToken))
        .mainnetToken;
      {
        const hashKey = keccak256(
          solidityPack(['uint256', 'uint256'], [chainId, freezeToken]),
        );
        const { slot, itemSlot, value } = await getMappingStructXSlot(
          '0x3',
          managerAddress,
          hashKey,
          1,
          'number',
        );

        const storageValue =
          '0x' +
          (
            await ethers.provider.getStorageAt(
              managerAddress,
              utils.hexZeroPad(itemSlot, 32),
            )
          ).slice(-40);

        const value1_S =
          '0x' +
          utils.hexZeroPad(BigNumber.from(value).toHexString(), 32).slice(-40);
        slot1 = itemSlot;
        expect(slot)
          .to.equal(slot1_I)
          .to.equal(BigNumber.from(itemSlot).sub(1));
        expect(value1.toLocaleLowerCase())
          .to.equal(value1_S)
          .to.equal(storageValue);
      }

      // --------------------------------------------------------------
      // set Verifyinfo 2
      // ORManager.sol - _minChallengeRatio
      // slot: 6
      const slot2 = '0x6';
      const value2 = (await manager.minChallengeRatio()).toBigInt();
      {
        const storageValue = await ethers.provider.getStorageAt(
          managerAddress,
          utils.hexZeroPad(slot2, 32),
        );
        const minChallengeRatio = BigNumber.from(
          '0x' + storageValue.slice(-16),
        ).toBigInt();
        expect(value2).to.equal(minChallengeRatio);
      }

      // --------------------------------------------------------------
      // set Verifyinfo 3
      // ORMakerDeposit.sol - _columnArrayHash
      // slot: 3
      const slot3 = '0x3';
      const value3: BytesLike = await orMakerDeposit.columnArrayHash();
      {
        const storageValue = await ethers.provider.getStorageAt(
          makerAddress,
          utils.hexZeroPad(slot3, 32),
        );
        expect(value3).to.equal(storageValue);
      }

      // --------------------------------------------------------------
      // set Verifyinfo 4
      // ORManager.sol - chainTokenInfo - mainnetToken
      // slot 3
      let slot4;
      const slot4_I = keccak256(
        solidityPack(
          ['uint256', 'uint256'],
          [
            keccak256(
              solidityPack(
                ['uint256', 'uint256'],
                [chainId_Dest, freezeToken_Dest],
              ),
            ),
            3,
          ],
        ),
      );
      const value4 = (
        await orManager.getChainTokenInfo(chainId_Dest, freezeToken_Dest)
      ).mainnetToken;
      {
        const hashKey = keccak256(
          solidityPack(
            ['uint256', 'uint256'],
            [chainId_Dest, freezeToken_Dest],
          ),
        );
        const { slot, itemSlot, value } = await getMappingStructXSlot(
          '0x3',
          managerAddress,
          hashKey,
          1,
          'number',
        );

        const storageValue =
          '0x' +
          (
            await ethers.provider.getStorageAt(
              managerAddress,
              utils.hexZeroPad(itemSlot, 32),
            )
          ).slice(-40);

        const value4_S =
          '0x' +
          utils.hexZeroPad(BigNumber.from(value).toHexString(), 32).slice(-40);
        slot4 = itemSlot;
        expect(slot)
          .to.equal(slot4_I)
          .to.equal(BigNumber.from(itemSlot).sub(1));
        expect(value4.toLocaleLowerCase())
          .to.equal(value4_S)
          .to.equal(storageValue);
      }
      // --------------------------------------------------------------
      // set Verifyinfo 5
      // ORMakerDeposit.sol - responseMakersHash
      // slot 5
      const slot5 = '0x5';
      const value5: BytesLike = await orMakerDeposit.responseMakersHash();
      {
        const storageValue = await ethers.provider.getStorageAt(
          makerAddress,
          utils.hexZeroPad(slot5, 32),
        );
        expect(value5).to.equal(storageValue);
      }

      // --------------------------------------------------------------
      // set Verifyinfo 6
      // ORMakerDeposit.sol - ruleRoot
      // slot 6
      let slot6;
      const slot6_I = keccak256(solidityPack(['uint256', 'uint256'], [ebc, 6]));
      const value6 = (await maker.rulesRoot(ebcSample)).root;
      {
        const storageValue = await ethers.provider.getStorageAt(
          makerAddress,
          utils.hexZeroPad(slot6_I, 32),
        );
        slot6 = slot6_I;
        expect(storageValue).to.equal(value6);
      }

      const slotValue: VerifyInfoSlotStruct[] = [
        {
          // verifyInfo 0
          // ORManager.sol - ChainInfo - maxVerifyChallengeSourceTxSecond | minVerifyChallengeSourceTxSecond
          // slot: 2
          // itemSlot: 1
          account: managerAddress,
          key: slot0,
          value: value0,
        },
        {
          // verifyInfo 1
          // ORManager.sol - chainTokenInfo - mainnetToken (sourceChain)
          // slot: 3
          // itemSlot: 1
          account: managerAddress,
          key: slot1,
          value: value1,
        },
        {
          // verifyInfo 2
          // ORManager.sol - _rulesRoots
          // slot: 5
          account: managerAddress,
          key: slot2,
          value: value2,
        },
        {
          // verifyInfo 3
          // ORMakerDeposit.sol - _columnArrayHash
          // slot: 3
          account: makerAddress,
          key: slot3,
          value: value3,
        },
        {
          // verifyInfo 4
          // ORManager.sol - chainTokenInfo - mainnetToken (destChain)
          // slot: 3
          // itemSlot: 1
          account: managerAddress,
          key: slot4,
          value: value4,
        },
        {
          // Verifyinfo 5
          // ORMakerDeposit.sol - responseMakersHash
          // slot 5
          account: makerAddress,
          key: slot5,
          value: value5,
        },
        {
          // Verifyinfo 6
          // ORMakerDeposit.sol - responseMakersHash
          // slot 6
          account: makerAddress,
          key: slot6,
          value: value6,
        },
      ];
      console.log('slotValue: ', slotValue);
      return slotValue;
    };

    const createChallenge = async (
      challenge: challengeInputInfo,
      revertReason?: string,
    ): Promise<string> => {
      if (revertReason != undefined) {
        await expect(
          orMakerDeposit.challenge(
            challenge.sourceChainId,
            challenge.sourceTxHash.toString(),
            challenge.sourceTxTime,
            challenge.freezeToken,
            challenge.freezeAmount,
            { value: challenge.freezeAmount },
          ),
        ).to.revertedWith(revertReason);
        return revertReason;
      } else {
        const tx = await orMakerDeposit
          .challenge(
            challenge.sourceChainId,
            challenge.sourceTxHash.toString(),
            challenge.sourceTxTime,
            challenge.freezeToken,
            challenge.freezeAmount,
            { value: challenge.freezeAmount },
          )
          .then((t) => t.wait());
        const args = tx.events?.[0].args;
        expect(args).not.empty;
        if (!!args) {
          // console.warn('args.ChallengeInfo:', args.ChallengeInfo);
          expect(args.challengeId).not.empty;
          expect(args.challengeInfo.sourceTxFrom).eql(BigNumber.from(0));
          expect(args.challengeInfo.sourceTxTime).eql(
            BigNumber.from(challenge.sourceTxTime),
          );
          expect(args.challengeInfo.challenger).eql(mdcOwner.address);
          expect(args.challengeInfo.freezeToken).eql(challenge.freezeToken);
          expect(args.challengeInfo.freezeAmount0).eql(challenge.freezeAmount);
          expect(args.challengeInfo.freezeAmount1).eql(challenge.freezeAmount);
        }
        return args?.challengeId;
      }
    };

    before(async function () {
      const verifyBytesCode = await compile_yul(
        'contracts/zkp/goerli_1_evm.yul',
      );

      const verifyFactory = new ethers.ContractFactory(
        VerifierAbi,
        verifyBytesCode,
        mdcOwner,
      );
      verifyContract = await verifyFactory.deploy();
      spv = await new TestSpv__factory(mdcOwner).deploy(verifyContract.address);
      console.log(`verifier: ${verifyContract.address}, spv: ${spv.address}`);
    });

    it('test function verifyChallengeSource Revert case', async function () {
      const challenge: challengeInputInfo = {
        sourceChainId: random(200),
        sourceTxHash: utils.keccak256(mdcOwner.address),
        sourceTxTime: random(5000000),
        freezeToken: constants.AddressZero,
        freezeAmount: utils.parseEther('0.001'),
      };
      await createChallenge(challenge);
      const invalidVerifyInfo0: VerifyInfo = {
        data: [1],
        slots: [
          {
            account: constants.AddressZero,
            key: utils.keccak256(mdcOwner.address),
            value: 1,
          },
        ],
      };
      const invalidSPV0 = constants.AddressZero;
      await expect(
        orMakerDeposit.verifyChallengeSource(
          invalidSPV0,
          [],
          [
            utils.keccak256(mdcOwner.address),
            utils.keccak256(mdcOwner.address),
          ],
          invalidVerifyInfo0,
          [],
        ),
      ).to.revertedWith('CI');
      const chainId = defaultChainInfo.id;
      const invalidVerifyInfo1: VerifyInfo = {
        data: [chainId.toString()],
        slots: [
          {
            account: constants.AddressZero,
            key: utils.keccak256(mdcOwner.address),
            value: 1,
          },
        ],
      };
      await expect(
        orMakerDeposit.verifyChallengeSource(
          invalidSPV0,
          [],
          [
            utils.keccak256(mdcOwner.address),
            utils.keccak256(mdcOwner.address),
          ],
          invalidVerifyInfo1,
          [],
        ),
      ).to.revertedWith('SI');

      const chainInfo = await orManager.getChainInfo(chainId);
      const spvs = chainInfo.spvs.slice(0, 1);
      console.log(`test spv: ${spvs.toString()}`);
    });

    it('test prase spv proof data', async function () {
      return;
      const fake_spvProof: BytesLike = utils.keccak256(mdcOwner.address);
      const spvProof: BytesLike = utils.arrayify(
        '0x' + fs.readFileSync('test/example/spv.calldata', 'utf-8'),
      );

      const { blockHash, toAddress, transferAmount, timestamp } =
        await spv.parseProofData(spvProof);
      console.log(
        `blcokHash: ${blockHash}, toAddress: ${toAddress}, transferAmount: ${transferAmount}, timestamp: ${timestamp}`,
      );

      await expect(spv.verifyProof(fake_spvProof)).to.revertedWith(
        'verify fail',
      );

      const tx = await spv.verifyProof(spvProof).then((t) => t.wait());
      expect(tx.status).to.be.eq(1);
      const txrc = await ethers.provider.getTransaction(tx.transactionHash);
      const inpudataGas = callDataCost(txrc.data);
      console.log(
        // eslint-disable-next-line prettier/prettier
        `verify totalGas: ${
          tx.gasUsed
        }, callDataGas: ${inpudataGas}, excuteGas: ${
          tx.gasUsed.toNumber() - inpudataGas
        }`,
      );
    });

    const updateSpv = async (
      challengeInputInfo: challengeInputInfo,
      spvAddress: string,
    ) => {
      const enableTimeTime =
        // eslint-disable-next-line prettier/prettier
        (await getCurrentTime()) >
        (await orManager.getVersionAndEnableTime()).enableTime.toNumber()
          ? await getCurrentTime()
          : (await orManager.getVersionAndEnableTime()).enableTime;

      await orManager
        .updateChainSpvs(
          getMinEnableTime(BigNumber.from(enableTimeTime)),
          challengeInputInfo.sourceChainId,
          [spvAddress],
          [0],
          {
            gasLimit: 10e6,
          },
        )
        .then((t) => t.wait());
    };

    it('challenge Verify Source TX should success', async function () {
      const challenge: challengeInputInfo = {
        sourceChainId: 5,
        sourceTxHash: utils.keccak256(randomBytes(7800)),
        sourceTxTime: (await getCurrentTime()) - random(await getCurrentTime()),
        // freezeToken: '0xa0321efeb50c46c17a7d72a52024eea7221b215a',
        freezeToken: constants.AddressZero,
        freezeAmount: utils.parseEther('0.001'),
      };

      const verifyinfoBase: verifyinfoBase = {
        chainIdDest: 420,
        // freeTokenDest: '0x4C6c591254769CD6D1850aa626bc45B12d8d9ce0',
        freeTokenDest: constants.AddressZero,
        ebc: ebcSample,
      };

      await updateSpv(challenge, spv.address);

      await getVerifyinfoSlots(
        orMakerDeposit,
        orManager,
        challenge,
        verifyinfoBase,
      );

      await createChallenge(challenge);
    });

    it('challenge case test', async function () {
      const case1SourceChainId = chainId;
      const case1SourceTxHash = utils.keccak256(randomBytes(100));
      const case1freezeAmount = '0.1';
      const challenge: challengeInputInfo = {
        sourceChainId: case1SourceChainId,
        sourceTxHash: case1SourceTxHash,
        sourceTxTime: (await getCurrentTime()) - 1,
        freezeToken: constants.AddressZero,
        freezeAmount: utils.parseEther(case1freezeAmount),
      };
      const case1balanceOfMakerbefore = utils.formatEther(
        await ethers.provider.getBalance(orMakerDeposit.address),
      );
      await expect(
        orMakerDeposit.checkChallenge(
          case1SourceChainId,
          case1SourceTxHash,
          [],
        ),
      ).to.revertedWith('CNE');
      const challengeFake: challengeInputInfo = {
        sourceChainId: challenge.sourceChainId,
        sourceTxHash: challenge.sourceTxHash,
        sourceTxTime: (await getCurrentTime()) + 7800,
        freezeToken: challenge.freezeToken,
        freezeAmount: challenge.freezeAmount,
      };
      await createChallenge(challengeFake, 'STOF');
      await createChallenge(challenge);
      await createChallenge(challenge, 'CE');

      await mineXMinutes(100);
      expect(
        await orMakerDeposit.checkChallenge(
          case1SourceChainId,
          case1SourceTxHash,
          [],
        ),
      ).to.be.satisfy;
      const case1balanceOfMakerAfter = utils.formatEther(
        await ethers.provider.getBalance(orMakerDeposit.address),
      );
      console.log(
        `challenge 1 balanceOfMakerbefore :${case1balanceOfMakerbefore}, balanceOfMakerAfter :${case1balanceOfMakerAfter}, freezeAmount: ${case1freezeAmount}`,
      );
      expect(parseFloat(case1balanceOfMakerAfter).toFixed(2)).equal(
        (parseFloat(case1balanceOfMakerbefore) + parseFloat(case1freezeAmount))
          .toFixed(2)
          .toString(),
      );

      await expect(
        orMakerDeposit.checkChallenge(
          case1SourceChainId,
          case1SourceTxHash,
          [],
        ),
      ).to.revertedWith('CNE');
      const challenge2: challengeInputInfo = {
        sourceChainId: challenge.sourceChainId,
        sourceTxHash: challenge.sourceTxHash,
        sourceTxTime: (await getCurrentTime()) - 1,
        freezeToken: challenge.freezeToken,
        freezeAmount: challenge.freezeAmount,
      };
      await createChallenge(challenge2);

      const case2balanceOfMakerAfter = utils.formatEther(
        await ethers.provider.getBalance(orMakerDeposit.address),
      );
      expect(parseFloat(case2balanceOfMakerAfter).toFixed(2)).equal(
        (parseFloat(case1balanceOfMakerAfter) + parseFloat(case1freezeAmount))
          .toFixed(2)
          .toString(),
      );
      console.log(
        `challenge 2 balanceOfMakerbefore :${case1balanceOfMakerAfter}, balanceOfMakerAfter :${case2balanceOfMakerAfter}, freezeAmount: ${case1freezeAmount}`,
      );

      await expect(
        orMakerDeposit.checkChallenge(
          case1SourceChainId,
          case1SourceTxHash,
          [],
        ),
      ).to.revertedWith('VCST');

      await mineXMinutes(100);

      expect(
        await orMakerDeposit.checkChallenge(
          case1SourceChainId,
          case1SourceTxHash,
          [],
        ),
      ).to.be.satisfy;

      await expect(
        orMakerDeposit.checkChallenge(
          case1SourceChainId,
          case1SourceTxHash,
          [],
        ),
      ).to.revertedWith('CNE');
    });
  });
});
