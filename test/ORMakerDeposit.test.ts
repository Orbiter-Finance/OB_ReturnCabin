import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumber, BigNumberish, constants, utils } from 'ethers';
import { ethers, network } from 'hardhat';

import lodash from 'lodash';
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
import {
  calculateRulesMerkleTree,
  createRandomRule,
  getRulesRootUpdatedLogs,
  gzipRules,
} from './lib/rule';
import { testReverted, testRevertedOwner } from './utils.test';
import MerkleTree from 'merkletreejs';

describe('ORMakerDeposit', () => {
  let signers: SignerWithAddress[];
  let mdcOwner: SignerWithAddress;
  let orManager: ORManager;
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
      testToken = new TestToken__factory(mdcOwner).attach(testTokenAddress);
    } else {
      testToken = await new TestToken__factory(mdcOwner).deploy();
    }

    await testToken.deployed();
  });

  it('Restoring the ORMakerDeposit should succeed', async function () {
    const predictMDCAddress = await orMDCFactory
      .connect(mdcOwner)
      .predictMDCAddress();
    orMakerDeposit = new ORMakerDeposit__factory(mdcOwner).attach(
      predictMDCAddress,
    );

    const owner = await orMakerDeposit.owner();

    expect(owner).eq(mdcOwner.address);
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

  it('Function deposit should success', async function () {
    const bETHBefore = await mdcOwner.provider?.getBalance(
      orMakerDeposit.address,
    );
    const amountETH = utils.parseEther('1');
    await orMakerDeposit
      .deposit(constants.AddressZero, constants.Zero, { value: amountETH })
      .then((t) => t.wait());
    const bETHAfter = await mdcOwner.provider?.getBalance(
      orMakerDeposit.address,
    );
    expect(bETHAfter?.sub(bETHBefore || 0)).eq(amountETH);

    const bERC20Before = await testToken.balanceOf(orMakerDeposit.address);
    const amountERC20 = utils.parseEther('0.5');
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
    const amountETH = utils.parseEther('0.5');
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
    const amountERC20 = utils.parseEther('0.5');
    await orMakerDeposit
      .withdraw(testToken.address, amountERC20)
      .then((t) => t.wait());
    const bERC20After = await testToken.balanceOf(mdcOwner.address);
    expect(bERC20After.sub(bERC20Before)).eq(amountERC20);
  });

  it('Function updateRulesRoot should emit events and update storage', async function () {
    const rules: any[] = [];
    for (let i = 0; i < 20; i++) {
      const _rule = createRandomRule();
      _rule[0] = Number(_rule[0]) + i;
      _rule[1] = Number(_rule[1]) + i;
      rules.push(_rule);
    }

    const tree = calculateRulesMerkleTree(rules);
    const root = utils.hexlify(tree.getRoot());
    const rsc = gzipRules(rules);

    ebcSample = lodash.sample(defaultsEbcs)!;
    const rootWithVersion = { root, version: 1 };
    const sourceChainIds = [1];
    const pledgeAmounts = [utils.parseEther('0.001')];

    await testReverted(
      orMakerDeposit.updateRulesRoot(
        ebcSample,
        rsc,
        rootWithVersion,
        sourceChainIds,
        pledgeAmounts,
      ),
      'IV',
    );

    const { events } = await orMakerDeposit
      .updateRulesRoot(
        ebcSample,
        rsc,
        rootWithVersion,
        sourceChainIds,
        pledgeAmounts,
        {
          value: pledgeAmounts.reduce((pv, cv) => pv.add(cv)),
        },
      )
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.ebc).eq(ebcSample);
    expect(args.rootWithVersion.root).eq(rootWithVersion.root);
    expect(args.rootWithVersion.version).eq(rootWithVersion.version);

    await testReverted(
      orMakerDeposit.updateRulesRoot(ebcSample, rsc, rootWithVersion, [], []),
      'VE',
    );
    await testRevertedOwner(
      orMakerDeposit
        .connect(signers[2])
        .updateRulesRoot(
          ebcSample,
          rsc,
          { ...rootWithVersion, version: 2 },
          [],
          [],
        ),
    );

    const storageRWV = await orMakerDeposit.rulesRoot(ebcSample);
    expect(storageRWV.root).eq(rootWithVersion.root);
    expect(storageRWV.version).eq(rootWithVersion.version);

    const leaf = lodash.sample(tree.getLeaves())!;
    expect(tree.verify(tree.getProof(leaf), leaf, storageRWV.root)).to.be.true;
  });

  it('Event RulesRootUpdated should emit logs', async function () {
    const rules = await getRulesRootUpdatedLogs(
      signers[0].provider,
      orMakerDeposit.address,
      implementation,
    );
    const tree = calculateRulesMerkleTree(rules);
    const root = utils.hexlify(tree.getRoot());

    const storageRWV = await orMakerDeposit.rulesRoot(ebcSample);
    expect(storageRWV.root).eq(root);
  });

  it('Function updateRulesRootErc20 should emit events and update storage', async function () {
    const rules = await getRulesRootUpdatedLogs(
      signers[0].provider,
      orMakerDeposit.address,
      implementation,
    );

    for (let i = 0; i < 10; i++) {
      const _rule = createRandomRule();
      _rule[0] = Number(rules[rules.length - 1][0]) + 1;
      _rule[1] = Number(rules[rules.length - 1][1]) + 1;
      rules.push(_rule);
    }

    const rootWithVersion = await orMakerDeposit.rulesRoot(ebcSample);

    const rsc = gzipRules(rules);
    const tree = calculateRulesMerkleTree(rules);
    const root = utils.hexlify(tree.getRoot());
    const sourceChainIds = [
      rules[rules.length - 1][0],
      rules[rules.length - 2][0],
    ];
    const pledgeAmounts = [utils.parseEther('0.1'), utils.parseEther('0.2')];

    const balanceBefore = await testToken.balanceOf(mdcOwner.address);

    // Approve
    const approveAmount = pledgeAmounts.reduce((pv, cv) => pv.add(cv));
    await testToken
      .approve(orMakerDeposit.address, approveAmount)
      .then((t) => t.wait());

    await orMakerDeposit
      .updateRulesRootERC20(
        ebcSample,
        rsc,
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
        ebcSample,
        rsc,
        { root, version: rootWithVersion.version + 1 },
        sourceChainIds,
        pledgeAmounts,
        testToken.address,
      ),
      'VE',
    );
    await testReverted(
      orMakerDeposit.updateRulesRootERC20(
        ebcSample,
        rsc,
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
          ebcSample,
          rsc,
          { root, version: rootWithVersion.version + 2 },
          sourceChainIds,
          pledgeAmounts,
          testToken.address,
        ),
    );
  });

  it('Function challenge should success', async function () {
    const sourceChainId = 10;
    const sourceTxHash = utils.keccak256('0x01');
    const freezeToken = constants.AddressZero;
    const freezeAmount = utils.parseEther('0.001');

    const tx = await orMakerDeposit.challenge(
      sourceChainId,
      sourceTxHash,
      freezeToken,
      freezeAmount,
      { value: freezeAmount },
    );

    console.warn('tx.hash:', tx.hash);
    const e = utils.RLP.encode([
      BigNumber.from(tx.chainId).toHexString(),
      BigNumber.from(tx.nonce).toHexString(),
      BigNumber.from(tx.maxPriorityFeePerGas).toHexString(),
      BigNumber.from(tx.maxFeePerGas).toHexString(),
      BigNumber.from(tx.gasLimit).toHexString(),
      BigNumber.from(tx.to).toHexString(),
      BigNumber.from(tx.value).toHexString(),
      BigNumber.from(tx.data).toHexString(),
      tx.accessList,
      BigNumber.from(tx.v).toHexString(),
      BigNumber.from(tx.r).toHexString(),
      BigNumber.from(tx.s).toHexString(),
    ]);
    console.warn(
      'utils.keccak256(e):',
      utils.keccak256(utils.hexConcat(['0x02', e])),
    );

    const h = utils.keccak256(tx.hash);
    console.warn('h:', h);

    const leaves = [tx.hash];
    const tree = new MerkleTree(leaves, utils.keccak256, { hashLeaves: true });
    console.warn('tree.root:', tree.getHexRoot());

    const receipt = await tx.wait();

    const block = await network.provider.send('eth_getBlockByNumber', [
      utils.hexlify(receipt.blockNumber),
      false,
    ]);
    console.warn('block:', JSON.stringify(block));
    console.warn('transactionsRoot:', block.transactionsRoot);
  });
});
