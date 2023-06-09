import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumber, BigNumberish, constants, utils } from 'ethers';
import { ethers } from 'hardhat';
import lodash from 'lodash';
import MerkleTree from 'merkletreejs';
import pako from 'pako';
import {
  ORMDCFactory,
  ORMDCFactory__factory,
  ORMakerDeposit,
  ORMakerDeposit__factory,
  ORManager,
  ORManager__factory,
  TestToken,
  TestToken__factory,
} from '../typechain-types';
import { defaultChainInfo, defaultsEbcs } from './defaults';
import { createRandomRule, ruleTypes } from './lib/rule';
import { testReverted, testRevertedOwner } from './utils.test';

describe('ORMakerDeposit', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orMDCFactory: ORMDCFactory;
  let orMakerDeposit: ORMakerDeposit;
  let implementation: string;
  let testToken: TestToken;

  before(async function () {
    signers = await ethers.getSigners();

    const envORMDCFactoryAddress = process.env['OR_MDC_FACTORY_ADDRESS'];
    assert(
      !!envORMDCFactoryAddress,
      'Env miss [OR_MDC_FACTORY_ADDRESS]. You may need to test ORMDCFactory.test.ts first. Example: npx hardhat test test/ORManager.test test/ORMDCFactory.test.ts test/ORMakerDeposit.test.ts',
    );

    orMDCFactory = new ORMDCFactory__factory(signers[0]).attach(
      envORMDCFactoryAddress,
    );
    implementation = await orMDCFactory.implementation();

    orManager = new ORManager__factory(signers[0]).attach(
      await orMDCFactory.manager(),
    );

    const testTokenAddress = process.env['TEST_TOKEN_ADDRESS'];
    if (testTokenAddress) {
      testToken = new TestToken__factory(signers[0]).attach(testTokenAddress);
    } else {
      testToken = await new TestToken__factory(signers[0]).deploy();
    }

    await testToken.deployed();
  });

  it('Restoring the ORMakerDeposit should succeed', async function () {
    const signerMaker = signers[1];

    const predictMDCAddress = await orMDCFactory
      .connect(signerMaker)
      .predictMDCAddress();
    orMakerDeposit = new ORMakerDeposit__factory(signerMaker).attach(
      predictMDCAddress,
    );

    const owner = await orMakerDeposit.owner();

    expect(owner).eq(signerMaker.address);
  });

  it("ORMakerDeposit's functions prefixed with _ should not be callable from outside", async function () {
    for (const key in orMakerDeposit.functions) {
      expect(key.replace(/^_/, '')).eq(key);
    }
  });

  it('Function updateColumnArray should emit events and update hash', async function () {
    const ebcs = lodash.cloneDeep(defaultsEbcs);

    const mdcEbcs: string[] = ebcs.slice(0, 10);
    mdcEbcs.sort(() => Math.random() - 0.5);

    const columnArrayHash = utils.keccak256(
      utils.solidityPack(
        ['address[]', 'address[]', 'uint16[]'],
        [[], mdcEbcs, []],
      ),
    );

    const { events } = await orMakerDeposit
      .updateColumnArray([], mdcEbcs, [])
      .then((t) => t.wait());

    const args = events![0].args!;

    expect(args['impl']).eq(implementation);
    expect(args['columnArrayHash']).eq(columnArrayHash);
    expect(lodash.toPlainObject(args['ebcs'])).to.deep.includes(mdcEbcs);

    await testRevertedOwner(
      orMakerDeposit.connect(signers[2]).updateColumnArray([], mdcEbcs, []),
    );

    // Test length
    await testReverted(
      orMakerDeposit.updateColumnArray(
        new Array(11).fill(constants.AddressZero),
        [],
        [],
      ),
      'DOF',
    );
    await testReverted(
      orMakerDeposit.updateColumnArray(
        [],
        new Array(11).fill(constants.AddressZero),
        [],
      ),
      'EOF',
    );
    await testReverted(
      orMakerDeposit.updateColumnArray([], [], new Array(101).fill(1)),
      'COF',
    );

    // Test validity
    await testReverted(
      orMakerDeposit.updateColumnArray([], [constants.AddressZero], []),
      'EI',
    );
    await testReverted(
      orMakerDeposit.updateColumnArray([], [], [2 ** 16 - 1]),
      'CI',
    );
  });

  it('Function updateSpvs should emit events and update storage', async function () {
    const chainId = defaultChainInfo.id;
    const chainInfo = await orManager.getChainInfo(chainId);

    const spvs = chainInfo.spvs.slice(0, 1);
    const chainIds = [chainId];

    const { events } = await orMakerDeposit
      .updateSpvs(spvs, chainIds)
      .then((t) => t.wait());

    for (const i in events!) {
      const event = events[i];

      expect(event.args!['impl']).eq(implementation);
      expect(event.args!['chainId']).eq(chainIds[i]);
      expect(event.args!['spv']).eq(spvs[i]);
    }

    for (const i in chainIds) {
      const spv = await orMakerDeposit.spv(chainIds[i]);
      expect(spv).eq(spvs[i]);
    }

    await testRevertedOwner(
      orMakerDeposit.connect(signers[2]).updateSpvs(spvs, chainIds),
    );

    await testReverted(orMakerDeposit.updateSpvs(spvs, [2 ** 16 - 1]), 'CI');
    await testReverted(
      orMakerDeposit.updateSpvs([constants.AddressZero], chainIds),
      'SI',
    );
  });

  it('Function updateResponseMakers should emit events and update storage', async function () {
    const responseMakers: string[] = [];
    const indexs: BigNumberish[] = [];
    for (let i = 0; i < 10; i++) {
      responseMakers.push(ethers.Wallet.createRandom().address);
    }

    const { events } = await orMakerDeposit
      .updateResponseMakers(responseMakers, indexs)
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.responseMakers).to.deep.eq(responseMakers);

    const storageResponseMakers = await orMakerDeposit.responseMakers();
    expect(storageResponseMakers).to.deep.eq(responseMakers);

    await testRevertedOwner(
      orMakerDeposit
        .connect(signers[2])
        .updateResponseMakers(responseMakers, indexs),
    );
  });

  it('Function updateRulesRoot should emit events and update storage', async function () {
    const rules: any[] = [];
    for (let i = 0; i < 20; i++) {
      const _rule = createRandomRule();
      _rule[0] = Number(_rule[0]) + i;
      _rule[1] = Number(_rule[1]) + i;
      rules.push(_rule);
    }

    const rsEncode = utils.defaultAbiCoder.encode(
      [`tuple(${ruleTypes.join(',')})[]`],
      [rules],
    );
    const rsc = utils.hexlify(
      pako.gzip(utils.arrayify(rsEncode), { level: 9 }),
    );
    expect(utils.hexlify(pako.ungzip(utils.arrayify(rsc)))).eq(rsEncode);

    const leaves = rules
      .map((values) =>
        utils.keccak256(utils.defaultAbiCoder.encode(ruleTypes, values)),
      )
      .sort((a, b) => (BigNumber.from(a).sub(b).gt(0) ? 1 : -1));
    const tree = new MerkleTree(leaves, utils.keccak256);
    const root = utils.hexlify(tree.getRoot());

    const ebc = lodash.sample(defaultsEbcs)!;
    const rootWithVersion = { root, version: 1 };
    const sourceChainIds = [1];
    const pledgeAmounts = [utils.parseEther('0.001')];

    await testReverted(
      orMakerDeposit.updateRulesRoot(
        ebc,
        rsc,
        rootWithVersion,
        sourceChainIds,
        pledgeAmounts,
      ),
      'IV',
    );

    const { events } = await orMakerDeposit
      .updateRulesRoot(
        ebc,
        rsc,
        rootWithVersion,
        sourceChainIds,
        pledgeAmounts,
        {
          value: pledgeAmounts.reduce((pV, cV) => pV.add(cV)),
        },
      )
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.ebc).eq(ebc);
    expect(args.rootWithVersion.root).eq(rootWithVersion.root);
    expect(args.rootWithVersion.version).eq(rootWithVersion.version);

    await testReverted(
      orMakerDeposit.updateRulesRoot(ebc, rsc, rootWithVersion, [], []),
      'VE',
    );
    await testRevertedOwner(
      orMakerDeposit
        .connect(signers[2])
        .updateRulesRoot(ebc, rsc, { ...rootWithVersion, version: 2 }, [], []),
    );

    const storageRWV = await orMakerDeposit.rulesRoot(ebc);
    expect(storageRWV.root).eq(rootWithVersion.root);
    expect(storageRWV.version).eq(rootWithVersion.version);

    const leaf = lodash.sample(leaves)!;
    expect(tree.verify(tree.getProof(leaf), leaf, storageRWV.root)).to.be.true;
  });

  it('Function updateRulesRootErc20 should emit events and update storage', async function () {
    const logs = await signers[0].provider?.getLogs({
      address: orMakerDeposit.address,
      topics: [
        utils.id('RulesRootUpdated(address,address,(bytes32,uint32))'),
        ethers.utils.hexZeroPad(implementation.toLowerCase(), 32),
      ],
    });

    const updateActions: {
      transactionHash: string;
      ebc: string;
      root: string;
      version: number;
    }[] = [];
    for (const log of logs || []) {
      const [ebc, [root, version]] = utils.defaultAbiCoder.decode(
        ['address', 'tuple(bytes32,uint32)'],
        log.data,
      );
      updateActions.push({
        transactionHash: log.transactionHash,
        ebc,
        root,
        version,
      });
    }
    updateActions.sort((a, b) => a.version - b.version);

    for (const item of updateActions) {
      const transaction = await signers[0].provider?.getTransaction(
        item.transactionHash,
      );
      if (!transaction) continue;

      const [_, rsc] = utils.defaultAbiCoder.decode(
        ['address', 'bytes', 'tuple(bytes32,uint32)', 'uint16[]', 'uint[]'],
        utils.hexDataSlice(transaction.data, 4),
      );

      const ungzipData = pako.ungzip(utils.arrayify(rsc));

      const [rules] = utils.defaultAbiCoder.decode(
        [`tuple(${ruleTypes.join(',')})[]`],
        utils.hexlify(ungzipData),
      );

      console.warn('rules.length:', rules.length);
    }

    // const rules: any[] = [];
    // for (let i = 0; i < 200; i++) {
    //   const _rule = createRandomRule();
    //   _rule[0] = Number(_rule[0]) + i;
    //   _rule[1] = Number(_rule[1]) + i;
    //   rules.push(_rule);
    // }

    // const rsEncode = utils.defaultAbiCoder.encode(
    //   [`tuple(${ruleTypes.join(',')})[]`],
    //   [rules],
    // );
    // const rsc = utils.hexlify(
    //   pako.gzip(utils.arrayify(rsEncode), { level: 9 }),
    // );
    // expect(utils.hexlify(pako.ungzip(utils.arrayify(rsc)))).eq(rsEncode);

    // const leaves = rules
    //   .map((values) =>
    //     utils.keccak256(utils.defaultAbiCoder.encode(ruleTypes, values)),
    //   )
    //   .sort((a, b) => (BigNumber.from(a).sub(b).gt(0) ? 1 : -1));
    // const tree = new MerkleTree(leaves, utils.keccak256);
    // const root = utils.hexlify(tree.getRoot());

    // const ebc = lodash.sample(defaultsEbcs)!;
    // const rootWithVersion = { root, version: 1 };
    // const sourceChainIds = [1];
    // const pledgeAmounts = [utils.parseEther('0.001')];

    // await testReverted(
    //   orMakerDeposit.updateRulesRootERC20(
    //     rsc,
    //     ebc,
    //     rootWithVersion,
    //     sourceChainIds,
    //     pledgeAmounts,
    //     testToken.address,
    //   ),
    //   'IV',
    // );

    // const { events } = await orMakerDeposit
    //   .updateRulesRoot(
    //     rsc,
    //     ebc,
    //     rootWithVersion,
    //     sourceChainIds,
    //     pledgeAmounts,
    //     {
    //       value: pledgeAmounts.reduce((pV, cV) => pV.add(cV)),
    //     },
    //   )
    //   .then((t) => t.wait());

    // const args = events![0].args!;
    // expect(args.ebc).eq(ebc);
    // expect(args.rootWithVersion.root).eq(rootWithVersion.root);
    // expect(args.rootWithVersion.version).eq(rootWithVersion.version);

    // await testReverted(
    //   orMakerDeposit.updateRulesRoot(rsc, ebc, rootWithVersion, [], []),
    //   'VE',
    // );
    // await testRevertedOwner(
    //   orMakerDeposit
    //     .connect(signers[2])
    //     .updateRulesRoot(rsc, ebc, { ...rootWithVersion, version: 2 }, [], []),
    // );

    // const storageRWV = await orMakerDeposit.rulesRoot(ebc);
    // expect(storageRWV.root).eq(rootWithVersion.root);
    // expect(storageRWV.version).eq(rootWithVersion.version);

    // const leaf = lodash.sample(leaves)!;
    // expect(tree.verify(tree.getProof(leaf), leaf, storageRWV.root)).to.be.true;
  });
});
