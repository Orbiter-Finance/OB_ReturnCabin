import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import {
  ORMDCFactory,
  ORMDCFactory__factory,
  ORMakerDeposit,
  ORMakerDeposit__factory,
  ORManager,
  ORManager__factory,
} from '../typechain-types';
import { utils } from 'ethers';

describe('ORMDCFactory', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orMakerDeposit_impl: ORMakerDeposit;
  let orMakerDeposit: ORMakerDeposit;
  let orMDCFactory: ORMDCFactory;

  before(async function () {
    signers = await ethers.getSigners();

    const envORManagerAddress = process.env['ORMANAGER_ADDRESS'];
    if (envORManagerAddress) {
      orManager = new ORManager__factory(signers[0]).attach(
        envORManagerAddress,
      );
      console.log('Address of orManager[env]:', orManager.address);
    } else {
      orManager = await new ORManager__factory(signers[0]).deploy(
        signers[0].address,
      );
      console.log('Address of orManager:', orManager.address);
      await orManager.deployed();
    }

    orMakerDeposit_impl = await new ORMakerDeposit__factory(
      signers[0],
    ).deploy();
    console.log('Address of orMakerDeposit_impl:', orMakerDeposit_impl.address);
    await orMakerDeposit_impl.deployed();

    orMDCFactory = await new ORMDCFactory__factory(signers[0]).deploy(
      orManager.address,
      orMakerDeposit_impl.address,
    );
    console.log('Address of orMDCFactory:', orMDCFactory.address);
    await orMDCFactory.deployed();

    // set environment variables
    process.env['ORMDCFACTORY_ADDRESS'] = orMDCFactory.address;
  });

  it('Manager and implementation should have been set up successfully', async function () {
    const manager = await orMDCFactory.manager();
    expect(manager).eq(orManager.address);

    const implementation = await orMDCFactory.implementation();
    expect(implementation).eq(orMakerDeposit_impl.address);
  });

  it('Function createMDC should succeed', async function () {
    const signerMaker = signers[1];

    const { events } = await orMDCFactory
      .connect(signerMaker)
      .createMDC()
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.maker).eq(signerMaker.address);

    const salt = utils.keccak256(
      utils.solidityPack(
        ['address', 'address'],
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
    console.warn('mdcAddress:', mdcAddress);

    orMakerDeposit = new ORMakerDeposit__factory(signerMaker).attach(
      mdcAddress,
    );
  });

  it("Function createMDC should cann't recreate", async function () {
    const signerMaker = signers[1];

    try {
      await orMDCFactory
        .connect(signerMaker)
        .createMDC()
        .then((t) => t.wait());
    } catch (err: any) {
      expect(err.message.indexOf(`'ERC1167: create2 failed'`) > -1).to.be.eq(
        true,
      );
    }
  });

  it('Function updateMaxMDCLimit should effective', async function () {
    try {
      await orManager.updateMaxMDCLimit(1);
      await orMDCFactory.createMDC();
    } catch (err: any) {
      expect(err.message.indexOf(`'MML'`) > -1).to.be.eq(true);
    }
  });

  it("ORMDCFactory's mdcCreatedTotal should be 1", async function () {
    const mdcCreatedTotal = await orMDCFactory.mdcCreatedTotal();

    expect(mdcCreatedTotal).eq(1);
  });

  it("ORMakerDeposit's owner should be maker", async function () {
    const signerMaker = signers[1];

    const owner = await orMakerDeposit.owner();

    expect(owner).eq(signerMaker.address);
  });

  it("ORMakerDeposit's mdcFactory should be maker", async function () {
    const mdcFactory = await orMakerDeposit.mdcFactory();

    expect(mdcFactory).eq(orMDCFactory.address);
  });
});
