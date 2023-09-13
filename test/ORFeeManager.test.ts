import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';

import { defaultAbiCoder, keccak256 } from 'ethers/lib/utils';
import {
  ORFeeManager,
  ORFeeManager__factory,
  ORManager,
  ORManager__factory,
  Verifier,
  Verifier__factory,
} from '../typechain-types';
import { log } from 'console';
import {
  dealersSignersMock,
  initTestToken,
  submitterMock,
} from './lib/mockData';

describe('ORFeeManger', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orFeeManager: ORFeeManager;
  let dealerSinger: SignerWithAddress;
  let verifier: Verifier;
  let feeMangerOwner: string;
  let DEALER_WITHDRAW_DELAY: number;
  let WITHDRAW_DURATION: number;
  let LOCK_DURATION: number;
  const secondsInMinute = 60;

  before(async function () {
    initTestToken();
    signers = await ethers.getSigners();
    dealerSinger = signers[2];
    feeMangerOwner = signers[0].address;
    DEALER_WITHDRAW_DELAY = 3600;
    WITHDRAW_DURATION = 3360;
    LOCK_DURATION = 240;

    const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
    assert(
      !!envORManagerAddress,
      'Env miss [OR_MANAGER_ADDRESS]. You may need to test ORManager.test.ts first. Example: npx hardhat test test/ORManager.test test/ORFeeManager.test.ts',
    );

    orManager = new ORManager__factory(signers[0]).attach(envORManagerAddress);
    console.log('connected to orManager contract:', orManager.address);
    // await orManager.deployed();

    verifier = await new Verifier__factory(signers[0]).deploy();

    if (process.env['OR_FEE_MANAGER_ADDRESS'] != undefined) {
      orFeeManager = new ORFeeManager__factory(signers[1]).attach(
        process.env['OR_FEE_MANAGER_ADDRESS'],
      );
    } else {
      orFeeManager = await new ORFeeManager__factory(signers[0]).deploy(
        signers[0].address,
        orManager.address,
        verifier.address,
      );
      process.env['OR_FEE_MANAGER_ADDRESS'] = orFeeManager.address;
    }

    console.log('Address of orFeeManager:', orFeeManager.address);
    // await orFeeManager.deployed();
  });

  // it("transferOwnership should succeed", async function () {
  //   await orFeeManager
  //     .connect(signers[1])
  //     .transferOwnership(feeMangerOwner);

  //   const newOwner = await orFeeManager.owner();
  //   expect(newOwner).eq(feeMangerOwner);

  // });

  it("ORFeeManager's functions prefixed with _ should be private", async function () {
    for (const key in orFeeManager.functions) {
      expect(key.replace(/^_/, '')).eq(key);
    }
  });

  it('Function updateDealer should emit events and update dealerInfo', async function () {
    const feeRatio = BigNumber.from(1000);
    const extraInfoTypes = ['string', 'string'];
    const extraInfoValues = ['https://orbiter.finance/', '@Orbiter_Finance'];
    const extraInfo = defaultAbiCoder.encode(extraInfoTypes, extraInfoValues);

    const dealersigners: SignerWithAddress[] = await dealersSignersMock();

    await Promise.all(
      dealersigners.map(async (dealersigner) => {
        const { events } = await orFeeManager
          .connect(dealersigner)
          .updateDealer(feeRatio, extraInfo)
          .then((t) => t.wait());

        const args = events?.[0].args;
        expect(args?.dealer).eq(dealersigner.address);
        expect(args?.feeRatio).eq(feeRatio);
        expect(args?.extraInfo).eq(extraInfo);

        const dealerInfo = await orFeeManager.getDealerInfo(
          dealersigner.address,
        );
        log('Address of dealer:', dealersigner.address);
        expect(dealerInfo.feeRatio).eq(feeRatio);
        expect(dealerInfo.extraInfoHash).eq(keccak256(extraInfo));
      }),
    );
  });

  async function registerSubmitter() {
    if (process.env['REGISTER_SUBMITTER'] != undefined) {
      const submitter = process.env['REGISTER_SUBMITTER'];
      const marginAmount = BigNumber.from(1000);
      await orFeeManager.registerSubmitter(marginAmount, submitter);
      console.log('register submitter:', submitter);
    } else {
      const submitter = await submitterMock();
      const marginAmount = BigNumber.from(1000);
      await orFeeManager.registerSubmitter(marginAmount, submitter);
      console.log('register submitter:', submitter);
    }
  }

  it('registerSubmitter should succeed', async function () {
    await registerSubmitter();
    if (process.env['REGISTER_SUBMITTER'] == undefined) {
      expect(await orFeeManager.submitter(await submitterMock())).eq(
        BigNumber.from(1000),
      );
      console.log('connect to submitter:', await submitterMock());
    } else {
      expect(
        await orFeeManager.submitter(process.env['REGISTER_SUBMITTER']),
      ).eq(BigNumber.from(1000));
      console.log('connect to submitter:', process.env['REGISTER_SUBMITTER']);
    }
  });
});
