import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumberish } from 'ethers';
import { ethers } from 'hardhat';
import {
  ORMDCFactory,
  ORMDCFactory__factory,
  ORMakerDeposit,
  ORMakerDeposit__factory,
  ORManager,
  ORManager__factory,
} from '../typechain-types';
import { sleep } from './utils.test';

describe('ORMakerDeposit', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orMDCFactory: ORMDCFactory;
  let orMakerDeposit: ORMakerDeposit;

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

  it('Function updateEbcs should emit event and update storage', async function () {
    const ebcs = await orManager.ebcs();
    console.warn('ebcs:', ebcs);

    const impl = await orMDCFactory.implementation();
    const filter = {
      address: orMakerDeposit.address,
      // topics: [BigNumber.from(impl).add(0).toHexString()],
      topics: [
        '0xa5f584f9fa7dffc81ef84ec3e9587fe3891b7cbf11a4156c905ddc4bb253e2df',
      ],
    };
    signers[0].provider!.on(filter, (log) => {
      console.warn('log:', log);
    });

    const managerEbcIndexs: BigNumberish[] = [];
    const keys: number[] = [];
    for (const i in ebcs) {
      managerEbcIndexs.push(i);
      keys.push(managerEbcIndexs.length);

      if (managerEbcIndexs.length >= 9) {
        break;
      }
    }

    keys.sort(() => Math.random() - 0.5);

    const { events } = await orMakerDeposit
      .updateEbcs(managerEbcIndexs, keys)
      .then((t) => t.wait());

    for (const i in keys) {
      const ebc = await orMakerDeposit.ebc(keys[i]);
      expect(ebc).eq(ebcs[Number(managerEbcIndexs[i])]);
    }

    try {
    } catch (err: any) {
      console.warn('err:', err.message);
    }

    await sleep(10000);
  });
});
