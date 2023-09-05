import { assert, expect } from 'chai';
import { utils } from 'ethers';
import { ethers } from 'hardhat';
import lodash from 'lodash';
import { BaseTrie } from 'merkle-patricia-tree';
import {
  createRandomRule,
  calculateRulesTree,
  calculateRuleKey,
  getRulesRootUpdatedLogs,
} from './lib/rule';
import {
  embedVersionIncreaseAndEnableTime,
  testReverted,
  getMinEnableTime,
  testRevertedOwner,
  hexToBuffer,
  getEffectiveEbcsFromLogs,
} from './utils.test';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
  ORManager,
  ORMDCFactory,
  ORMakerDeposit,
  TestToken,
  ORMDCFactory__factory,
  ORManager__factory,
  TestToken__factory,
  ORMakerDeposit__factory,
} from '../typechain-types';
import { ebcMock, initTestToken } from './lib/mockData';

describe('Update Root', () => {
  let signers: SignerWithAddress[];
  let mdcOwner: SignerWithAddress;
  let orManager: ORManager;
  let orManagerEbcs: string[];
  let orMDCFactory: ORMDCFactory;
  let orMakerDeposit: ORMakerDeposit;
  let implementation: string;
  let ebcSample: string;
  let testToken: TestToken;
  let ebcs: string[];

  before(async function () {
    signers = await ethers.getSigners();
    mdcOwner = signers[1];
    initTestToken();

    const envORMDCFactoryAddress = process.env['OR_MDC_FACTORY_ADDRESS'];
    assert(
      !!envORMDCFactoryAddress,
      'Env miss [OR_MDC_FACTORY_ADDRESS]. You may need to test ORMDCFactory.test.ts first. Example: npx hardhat test test/ORManager.test test/ORFeeManager.test.ts test/ORMDCFactory.test.ts test/ORMakerDeposit.test.ts',
    );

    orMDCFactory = new ORMDCFactory__factory(signers[0]).attach(
      envORMDCFactoryAddress,
    );
    console.log('connect of orMDCFactory:', orMDCFactory.address);
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

    // await testToken.deployed();
    ebcs = lodash.cloneDeep(orManagerEbcs);
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

  // it(
  //   'Function updateColumnArray should emit events and update hash',
  //   embedVersionIncreaseAndEnableTime(
  //     () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
  //     async function () {
  //       // const ebcs = lodash.cloneDeep(orManagerEbcs);
  //       const mdcEbcs: string[] = ebcs.slice(0, 8);
  //       mdcEbcs.push(ebcMock);
  //       mdcEbcs.sort(() => Math.random() - 0.5);

  //       // get dealers
  //       const mdcDealers: string[] = await dealersMock();
  //       // get chainIds
  //       const chainIds: number[] = chainIdsMock;

  //       console.log(
  //         `mdcDealers: ${mdcDealers}, mdcEbcs: ${mdcEbcs}, mdcChainIds: ${chainIds}`,
  //       );

  //       const columnArrayHash = utils.keccak256(
  //         utils.solidityPack(
  //           ['address[]', 'address[]', 'uint16[]'],
  //           [mdcDealers, mdcEbcs, chainIds],
  //         ),
  //       );

  //       const { events } = await orMakerDeposit
  //         .updateColumnArray(getMinEnableTime(), mdcDealers, mdcEbcs, chainIds)
  //         .then((t) => t.wait());

  //       const args = events![0].args!;

  //       expect(args['impl']).eq(implementation);
  //       expect(args['columnArrayHash']).eq(columnArrayHash);
  //       expect(lodash.toPlainObject(args['ebcs'])).to.deep.includes(mdcEbcs);
  //       expect(lodash.toPlainObject(args['dealers'])).to.deep.includes(
  //         mdcDealers,
  //       );

  //       await testRevertedOwner(
  //         orMakerDeposit
  //           .connect(signers[2])
  //           .updateColumnArray(getMinEnableTime(), [], mdcEbcs, []),
  //       );

  //       // Test length
  //       await testReverted(
  //         orMakerDeposit.updateColumnArray(
  //           getMinEnableTime(),
  //           new Array(11).fill(constants.AddressZero),
  //           [],
  //           [],
  //         ),
  //         'DECOF',
  //       );
  //       await testReverted(
  //         orMakerDeposit.updateColumnArray(
  //           getMinEnableTime(),
  //           [],
  //           new Array(11).fill(constants.AddressZero),
  //           [],
  //         ),
  //         'DECOF',
  //       );
  //       await testReverted(
  //         orMakerDeposit.updateColumnArray(
  //           getMinEnableTime(),
  //           [],
  //           [],
  //           new Array(101).fill(1),
  //         ),
  //         'DECOF',
  //       );

  //       // Test validity
  //       await testReverted(
  //         orMakerDeposit.updateColumnArray(
  //           getMinEnableTime(),
  //           [],
  //           [constants.AddressZero],
  //           [],
  //         ),
  //         'EI',
  //       );
  //       await testReverted(
  //         orMakerDeposit.updateColumnArray(
  //           getMinEnableTime(),
  //           [],
  //           [],
  //           [2 ** 16 - 1],
  //         ),
  //         'CI',
  //       );
  //     },
  //   ),
  // );

  it(
    'Function updateRulesRoot should emit events and update storage',
    embedVersionIncreaseAndEnableTime(
      () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
      async function () {
        const currentBlock = await mdcOwner.provider?.getBlock('latest');
        const getNative = true;

        const rules: any[] = [];
        for (let i = 0; i < 5 * 4; i++) {
          const _rule = createRandomRule(getNative);
          // _rule[0] = Number(_rule[0]) + i;
          // _rule[1] = Number(_rule[1]) + i;
          // _rule[4] = 0;
          // _rule[5] = 0;
          rules.push(_rule);
        }

        const tree = await calculateRulesTree(rules);
        const root = utils.hexlify(tree.root);
        ebcSample = ebcMock;
        const rootWithVersion = { root, version: 3 };
        const sourceChainIds = [1];
        const pledgeAmounts = [utils.parseEther('0.0001')];

        // await testReverted(
        //   orMakerDeposit.updateRulesRoot(
        //     getMinEnableTime(),
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
            getMinEnableTime(),
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

        // const args = events![0].args!;
        // expect(args.ebc).eq(ebcSample);
        // expect(args.rootWithVersion.root).eq(rootWithVersion.root);
        // expect(args.rootWithVersion.version).eq(rootWithVersion.version);

        // await testReverted(
        //   orMakerDeposit.updateRulesRoot(
        //     getMinEnableTime(),
        //     ebcSample,
        //     rules,
        //     rootWithVersion,
        //     [],
        //     [],
        //   ),
        //   'VE',
        // );
        // await testRevertedOwner(
        //   orMakerDeposit
        //     .connect(signers[2])
        //     .updateRulesRoot(
        //       getMinEnableTime(),
        //       ebcSample,
        //       rules,
        //       { ...rootWithVersion, version: 2 },
        //       [],
        //       [],
        //     ),
        // );

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

  // it('Event RulesRootUpdated should emit logs', async function () {
  //   const rules = await getRulesRootUpdatedLogs(
  //     signers[0].provider,
  //     orMakerDeposit.address,
  //     implementation,
  //   );
  //   const tree = await calculateRulesTree(rules);
  //   const root = utils.hexlify(tree.root);

  //   const storageRWV = await orMakerDeposit.rulesRoot(ebcSample);
  //   expect(storageRWV.root).eq(root);
  // });

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
          // _rule[0] = Number(_rule[0]) + 1;
          // _rule[1] = Number(_rule[1]) + 1;
          totalRules.push(_rule);
          // console.log(`ERC20rule-${i} :[${_rule}]`);
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
            getMinEnableTime(),
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
            getMinEnableTime(),
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
            getMinEnableTime(),
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
              getMinEnableTime(),
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
});
