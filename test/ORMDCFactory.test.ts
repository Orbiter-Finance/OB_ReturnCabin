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

    orManager = await new ORManager__factory(signers[0]).deploy(
      signers[0].address,
    );
    console.log('Address of orManager:', orManager.address);
    await orManager.deployed();

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

    orMakerDeposit = new ORMakerDeposit__factory(signerMaker).attach(
      mdcAddress,
    );

    const owner = await orMakerDeposit.owner();
    console.warn('owner:', owner);

    try {
      await orManager.updateMaxMDCLimit(1);
      await orMDCFactory.connect(signerMaker).createMDC();
    } catch (err: any) {
      expect(err.message.indexOf(`'MML'`) > -1).to.be.eq(true);
    }
  });
});
