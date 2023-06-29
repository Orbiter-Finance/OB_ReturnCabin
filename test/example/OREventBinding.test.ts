import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';

import { OREventBinding, OREventBinding__factory } from '../../typechain-types';
import { BigNumber, utils } from 'ethers';
import { expect } from 'chai';
import { AbiCoder, RLP, defaultAbiCoder } from 'ethers/lib/utils';

describe('OREventBinding', () => {
  let signers: SignerWithAddress[];
  let mdcOwner: SignerWithAddress;
  let orEventBinding: OREventBinding;

  before(async function () {
    signers = await ethers.getSigners();

    orEventBinding = await new OREventBinding__factory(signers[0]).deploy();
    console.log('orEventBinding.address:', orEventBinding.address);

    await orEventBinding.deployed();
  });

  it('Function getAmountSecurityCode should succeed', async function () {
    const amount = utils.parseEther('0.101200000000003721');
    const securityCode = await orEventBinding.getAmountSecurityCode(amount);
    expect(amount.mod(10000).toNumber()).eq(securityCode);

    const amount1 = utils.parseUnits('0.103721', 6);
    const securityCode1 = await orEventBinding.getAmountSecurityCode(amount1);
    expect(amount1.mod(10000).toNumber()).eq(securityCode1);
  });

  it('Function getResponsePreview should succeed', async function () {
    try {
      const amount = utils.parseEther('0.101200000000003721');
      const dest = signers[1].address;
      const ruleValues = [
        utils.parseEther('0.1'),
        utils.parseEther('0.2'),
        BigNumber.from(21000)
          .mul(20)
          .mul(10 ** 9),
        30,
      ];
      const preview = await orEventBinding.getResponsePreview(
        amount,
        dest,
        ruleValues,
      );

      const securityCode = await orEventBinding.getAmountSecurityCode(amount);
      const tradeAmount = amount.sub(securityCode);
      const fee = tradeAmount.mul(ruleValues[3]).div(10000).add(ruleValues[2]);
      const responseAmount = tradeAmount.sub(fee);

      console.warn('responseAmount:', responseAmount);

      // const v = defaultAbiCoder.decode(['address', 'uint'], preview);
      // console.warn('v:', v);

      console.warn('preview:', preview);
    } catch (e: any) {
      console.warn('e:', e.message);
    }
  });
});
