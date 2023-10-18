import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import assert from 'assert';
import { expect } from 'chai';
import { BigNumber, utils } from 'ethers';
import { ethers } from 'hardhat';
import {
  ORMDCFactory,
  ORMDCFactory__factory,
  ORMakerDeposit,
  ORMakerDeposit__factory,
  ORManager,
  ORManager__factory,
} from '../typechain-types';
import { testReverted } from './utils.test';
import { initTestToken } from './lib/mockData';

describe('ORMDCFactory', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orMakerDeposit_impl: ORMakerDeposit;
  let orMakerDeposit: ORMakerDeposit;
  let orMDCFactory: ORMDCFactory;
  let signerMaker: SignerWithAddress;

  before(async function () {
    initTestToken();
    signers = await ethers.getSigners();
    signerMaker = signers[1];

    const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
    assert(
      !!envORManagerAddress,
      'Env miss [OR_MANAGER_ADDRESS]. You may need to test ORManager.test.ts first. Example: npx hardhat test test/ORManager.test test/ORMDCFactory.test.ts',
    );

    orManager = new ORManager__factory(signers[0]).attach(envORManagerAddress);
    await orManager.deployed();

    if (process.env['OR_MDC_IMPL'] == undefined) {
      orMakerDeposit_impl = await new ORMakerDeposit__factory(
        signers[0],
      ).deploy();
      await orMakerDeposit_impl.deployed();
      process.env['OR_MDC_IMPL'] = orMakerDeposit_impl.address;
    } else {
      orMakerDeposit_impl = new ORMakerDeposit__factory(signers[0]).attach(
        process.env['OR_MDC_IMPL']!,
      );
    }
    console.log('Address of orMakerDeposit_impl:', orMakerDeposit_impl.address);

    if (process.env['OR_MDC_FACTORY_ADDRESS'] == undefined) {
      orMDCFactory = await new ORMDCFactory__factory(signers[0]).deploy(
        orManager.address,
        orMakerDeposit_impl.address,
      );
      await orMDCFactory.deployed();
      process.env['OR_MDC_FACTORY_ADDRESS'] = orMDCFactory.address;
    } else {
      orMDCFactory = new ORMDCFactory__factory(signers[0]).attach(
        process.env['OR_MDC_FACTORY_ADDRESS']!,
      );
    }
    console.log('Address of orMDCFactory:', orMDCFactory.address);
  });

  it("ORMDCFactory's functions prefixed with _ should be private", async function () {
    for (const key in orMDCFactory.functions) {
      expect(key.replace(/^_/, '')).eq(key);
    }
  });

  it('Manager and implementation should have been set up successfully', async function () {
    const manager = await orMDCFactory.manager();
    expect(manager).eq(orManager.address);

    const implementation = await orMDCFactory.implementation();
    expect(implementation).eq(orMakerDeposit_impl.address);
  });

  it('Function createMDC should succeed', async function () {
    // const signerMaker = signers[1];

    const { events } = await orMDCFactory
      .connect(signerMaker)
      .createMDC()
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.maker).eq(signerMaker.address);

    const salt = utils.keccak256(
      utils.solidityPack(
        ['uint256', 'uint256'],
        [orMDCFactory.address, signerMaker.address],
      ),
    );
    const creationCode = [
      '0x3d602d80600a3d3981f3363d3d373d3d3d363d73',
      orMakerDeposit_impl.address.replace(/0x/, '').toLowerCase(),
      '5af43d82803e903d91602b57fd5bf3',
    ].join('');
    const mdcAddress = utils.getCreate2Address(
      orMDCFactory.address,
      salt,
      utils.keccak256(creationCode),
    );
    expect(args.mdc).eq(mdcAddress);
    console.warn('Address of mdcAddress:', mdcAddress);

    orMakerDeposit = new ORMakerDeposit__factory(signerMaker).attach(
      mdcAddress,
    );
  });

  it("Function createMDC should cann't recreate", async function () {
    // const signerMaker = signers[1];

    await testReverted(
      orMDCFactory.connect(signerMaker).createMDC(),
      'ERC1167: create2 failed',
    );
  });

  it('Function updateMaxMDCLimit should effective', async function () {
    await orManager.updateMaxMDCLimit(1).then((t) => t.wait());

    await testReverted(orMDCFactory.createMDC(), 'MML');

    await orManager
      .updateMaxMDCLimit(BigNumber.from(2).pow(64).sub(1))
      .then((t) => t.wait());
  });

  it("ORMDCFactory's mdcCreatedTotal should be 1", async function () {
    const mdcCreatedTotal = await orMDCFactory.mdcCreatedTotal();

    expect(mdcCreatedTotal).eq(1);
  });

  it("ORMakerDeposit's owner should be maker", async function () {
    // const signerMaker = signers[1];

    const owner = await orMakerDeposit.owner();

    expect(owner).eq(signerMaker.address);
  });

  it("ORMakerDeposit's mdcFactory should be maker", async function () {
    const mdcFactory = await orMakerDeposit.mdcFactory();

    expect(mdcFactory).eq(orMDCFactory.address);
  });
});
