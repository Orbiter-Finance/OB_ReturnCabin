import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumber, BigNumberish, Wallet, constants, utils } from 'ethers';
import { ethers } from 'hardhat';
import lodash from 'lodash';
import pako from 'pako';
import {
  ORMDCFactory,
  ORMDCFactory__factory,
  ORMakerDeposit,
  ORMakerDeposit__factory,
  ORManager,
  ORManager__factory,
} from '../typechain-types';
import { defaultChainInfo } from './defaults';
import { testReverted } from './utils.test';
import MerkleTree from 'merkletreejs';

describe('ORMakerDeposit', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orMDCFactory: ORMDCFactory;
  let orMakerDeposit: ORMakerDeposit;
  let implementation: string;

  before(async function () {
    signers = await ethers.getSigners();

    const envORMDCFactoryAddress = process.env['ORMDCFACTORY_ADDRESS'];
    assert(
      !!envORMDCFactoryAddress,
      'Env miss [ORMDCFACTORY_ADDRESS]. You may need to test ORMDCFactory.test.ts first. Example: npx hardhat test test/ORManager.test test/ORMDCFactory.test.ts test/ORMakerDeposit.test.ts',
    );

    orMDCFactory = new ORMDCFactory__factory(signers[0]).attach(
      envORMDCFactoryAddress,
    );
    implementation = await orMDCFactory.implementation();

    orManager = new ORManager__factory(signers[0]).attach(
      await orMDCFactory.manager(),
    );
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

  it('Function updateColumnArray should emit events and update hash', async function () {
    const ebcs = await orManager.ebcs();

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

    await testReverted(
      orMakerDeposit.connect(signers[2]).updateColumnArray([], mdcEbcs, []),
      'Ownable: caller is not the owner',
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

    await testReverted(
      orMakerDeposit.connect(signers[2]).updateSpvs(spvs, chainIds),
      'Ownable: caller is not the owner',
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

    await testReverted(
      orMakerDeposit
        .connect(signers[2])
        .updateResponseMakers(responseMakers, indexs),
      'Ownable: caller is not the owner',
    );
  });

  it('Test', async function () {
    const types = [
      'uint16',
      'uint16',
      'uint8',
      'uint8',
      'uint',
      'uint',
      'uint128',
      'uint128',
      'uint128',
      'uint128',
      'uint16',
      'uint16',
      'uint32',
      'uint32',
      'uint32',
      'uint32',
    ];
    const getValues = () => {
      return [
        1,
        2,
        0,
        1,
        Wallet.createRandom().address,
        Wallet.createRandom().address,
        BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1),
        BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1),
        BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1),
        BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1),
        1,
        2,
        (2 ^ 32) - 1,
        (2 ^ 31) - 1,
        (2 ^ 30) - 1,
        (2 ^ 29) - 1,
      ];
    };

    // const rules: string[] = [];
    // for (let i = 0; i < 100; i++) {
    //   const pack = utils.solidityPack(types, values);
    //   rules.push(pack);
    // }
    // console.warn('pack:', rules[0]);

    // const rules: string[] = [];
    // for (let i = 0; i < 200; i++) {
    //   const _values = lodash.cloneDeep(values);
    //   _values[0] = Number(_values[0]) + i;
    //   _values[1] = Number(_values[1]) + i;
    //   const pack = utils.defaultAbiCoder.encode(types, _values);
    //   rules.push(utils.hexlify(pako.gzip(utils.arrayify(pack), { level: 9 })));
    // }
    // console.warn('encode:', rules[0]);

    const valuesList: any[] = [];
    for (let i = 0; i < 200; i++) {
      const _values = getValues();
      _values[0] = Number(_values[0]) + i;
      _values[1] = Number(_values[1]) + i;
      valuesList.push(_values);
    }
    const encode = utils.defaultAbiCoder.encode(
      [`tuple(${types.join(',')})[]`],
      [valuesList],
    );
    console.warn('encode.length:', encode.length);

    const rsc = utils.hexlify(pako.gzip(utils.arrayify(encode), { level: 9 }));
    console.warn('rsc.length:', rsc.length);

    const [sources] = utils.defaultAbiCoder.decode(
      [`tuple(${types.join(',')})[]`],
      utils.hexlify(pako.ungzip(utils.arrayify(rsc))),
    );
    console.warn('sources[0]:', sources[0]);

    const leaves = valuesList.map((values) =>
      utils.keccak256(utils.defaultAbiCoder.encode(types, values)),
    );

    console.warn('leaves.length:', leaves.length);

    const tree = new MerkleTree(leaves, utils.keccak256);
    const root = utils.hexlify(tree.getRoot());
    console.warn('root:', root);

    const { events } = await orMakerDeposit
      .updateRules(Wallet.createRandom().address, rsc, root, 1)
      .then((t) => t.wait());

    // console.warn('events[0].args:', events![0].args);
  });
});
