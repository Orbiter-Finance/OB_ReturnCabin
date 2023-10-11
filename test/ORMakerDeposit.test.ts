import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumber, BigNumberish, constants, utils } from 'ethers';
import { ethers } from 'hardhat';
import fs from 'fs';
import {
  getMappingItem,
  getMappingStruct,
  getUint256,
} from './lib/readStorage';

import {
  BytesLike,
  arrayify,
  defaultAbiCoder,
  keccak256,
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
  mineXMinutes,
} from './lib/mockData';
import { PromiseOrValue } from '../typechain-types/common';
import { VerifierAbi, compile_yul } from '../scripts/utils';

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
    await mineXMinutes(60);
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
        // const block = await ethers.provider.getBlock('latest');

        // console.log(
        //   `mdcDealers: ${mdcDealers}, mdcEbcs: ${mdcEbcs}, mdcChainIds: ${chainIds}`,
        // );

        const columnArrayHash = utils.keccak256(
          utils.solidityPack(
            ['address[]', 'address[]', 'uint16[]'],
            [mdcDealers, mdcEbcs, chainIds],
          ),
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
        expect(args?.columnArrayHash).eq(columnArrayHash);
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

        for (const i in events) {
          const event = events[i];

          expect(event.args?.['impl']).eq(implementation);
          expect(event.args?.['chainId']).eq(chainIds[i]);
          expect(event.args?.['spv']).eq(spvs[i]);
        }

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

  it('Function withdraw should success', async function () {
    const bETHBefore = await mdcOwner.provider?.getBalance(mdcOwner.address);
    const amountETH = utils.parseEther('0.001');
    const receipt = await orMakerDeposit
      .withdraw(constants.AddressZero, amountETH)
      .then((t) => t.wait());
    const bETHAfter = await mdcOwner.provider?.getBalance(mdcOwner.address);
    expect(
      bETHAfter
        ?.add(receipt.gasUsed.mul(receipt.effectiveGasPrice))
        .sub(bETHBefore || 0),
    ).eq(amountETH);

    await testRevertedOwner(
      orMakerDeposit
        .connect(signers[2])
        .withdraw(constants.AddressZero, amountETH),
    );

    const bERC20Before = await testToken.balanceOf(mdcOwner.address);
    const amountERC20 = utils.parseEther('0.001');
    await orMakerDeposit
      .withdraw(testToken.address, amountERC20)
      .then((t) => t.wait());
    const bERC20After = await testToken.balanceOf(mdcOwner.address);
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
          const inpudataGas = callDataCost(txrc.data);
          console.log('inputData', inpudataGas);
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
          // console.log(`erc20Rule-${i} :[${_rule}]`);
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

  describe('ORMakerDeposit challenge', () => {
    let spv: TestSpv;
    let verifyContract: { address: PromiseOrValue<string> };
    interface challengeInputInfo {
      sourceChainId: BigNumberish;
      sourceTxHash: BigNumberish;
      sourceTxTime: BigNumberish;
      freezeToken: string;
      freezeAmount: BigNumberish;
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
    const slot: any[] = [];
    async function slotInit() {
      slot.push(await orMakerDeposit.owner());
      slot.push(await orMakerDeposit.mdcFactory());
      slot.push(await orMakerDeposit.columnArrayHash());
      slot.push(await orMakerDeposit.spv(5));
      slot.push(await orMakerDeposit.responseMakersHash());
      slot.push((await orMakerDeposit.rulesRoot(ebcSample)).root);
      console.log(
        'slots',
        slot.map((slot) => slot.toString()),
      );
    }

    async function createChallenge(challenge: challengeInputInfo) {
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

    before(async function () {
      const verifyBytesCode = await compile_yul(
        'contracts/zkp/goerli_1_evm.yul',
      );
      // const verifyBytesCode = fs.readFileSync(
      //   'contracts/zkp/goerli_1_evm.bytecode',
      //   'utf-8',
      // );

      // console.log('verifyBytesCode:', verifyBytesCode);

      const verifyFactory = new ethers.ContractFactory(
        VerifierAbi,
        verifyBytesCode,
        mdcOwner,
      );
      verifyContract = await verifyFactory.deploy();
      spv = await new TestSpv__factory(mdcOwner).deploy(verifyContract.address);
      console.log(`verifier: ${verifyContract.address}, spv: ${spv.address}`);
    });

    it('slot check should succeed', async function () {
      const MdcAddress = orMakerDeposit.address;
      console.log('MDC address', MdcAddress);
      await slotInit();

      console.log(
        'getVersionAndEnableTime',
        await orMakerDeposit.getVersionAndEnableTime(),
      );
      console.log('slot0', (await getUint256('0x0', MdcAddress)).toHexString());
      console.log('slot1', (await getUint256('0x1', MdcAddress)).toHexString());
      console.log('slot2', (await getUint256('0x2', MdcAddress)).toHexString());
      console.log('slot3', (await getUint256('0x3', MdcAddress)).toHexString());
      console.log(
        'slot4',
        (await getMappingItem('0x4', MdcAddress, '0x5')).toHexString(),
      );
      console.log('slot5', (await getUint256('0x5', MdcAddress)).toHexString());
      console.log(
        'slot6-0',
        await getMappingStruct('0x6', MdcAddress, ebcSample, 0, 'bytes'),
      );
      console.log(
        'slot6-1',
        (
          await getMappingStruct('0x6', MdcAddress, ebcSample, 1, 'number')
        )?.toString(),
      );
      // expect(await getUint256('0x0', MdcAddress)).to.equal(slot[0].toString);
    });

    it('Function challenge should success', async function () {
      const challenge: challengeInputInfo = {
        sourceChainId: random(200),
        sourceTxHash: utils.keccak256(mdcOwner.address),
        sourceTxTime: 10000,
        freezeToken: constants.AddressZero,
        freezeAmount: utils.parseEther('0.001'),
      };
      const challengeId = await createChallenge(challenge);
      console.log(`create challengeId: ${challengeId}`);
    });

    it('test function verifyChallengeSource Revert case', async function () {
      const challenge: challengeInputInfo = {
        sourceChainId: random(200),
        sourceTxHash: utils.keccak256(mdcOwner.address),
        sourceTxTime: random(5000000),
        freezeToken: constants.AddressZero,
        freezeAmount: utils.parseEther('0.001'),
      };
      const challengeId = await createChallenge(challenge);
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
        `verify total gas used: ${tx.gasUsed}, input data gas: ${inpudataGas}, excuteGas:${tx.gasUsed.toNumber() - inpudataGas}`,
      );
    });
  });
});
