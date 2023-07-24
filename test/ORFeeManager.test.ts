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
} from '../typechain-types';

describe('ORMakerDeposit', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orFeeManager: ORFeeManager;
  let dealerSinger: SignerWithAddress;

  before(async function () {
    signers = await ethers.getSigners();
    dealerSinger = signers[1];

    const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
    assert(
      !!envORManagerAddress,
      'Env miss [OR_MANAGER_ADDRESS]. You may need to test ORManager.test.ts first. Example: npx hardhat test test/ORManager.test test/ORFeeManager.test.ts',
    );

    orManager = new ORManager__factory(signers[0]).attach(envORManagerAddress);
    await orManager.deployed();

    orFeeManager = await new ORFeeManager__factory(signers[0]).deploy(
      signers[0].address,
      orManager.address,
    );
    console.log('Address of orFeeManager:', orFeeManager.address);
    await orFeeManager.deployed();
  });

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

    const { events } = await orFeeManager
      .connect(dealerSinger)
      .updateDealer(feeRatio, extraInfo)
      .then((t) => t.wait());

    const args = events?.[0].args;
    expect(args?.dealer).eq(dealerSinger.address);
    expect(args?.feeRatio).eq(feeRatio);
    expect(args?.extraInfo).eq(extraInfo);

    const dealerInfo = await orFeeManager.getDealerInfo(dealerSinger.address);
    expect(dealerInfo.feeRatio).eq(feeRatio);
    expect(dealerInfo.extraInfoHash).eq(keccak256(extraInfo));
  });
});
