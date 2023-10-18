import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';

import { constants } from 'ethers';
import { hexConcat, parseEther, solidityPack } from 'ethers/lib/utils';
import {
  ORExtraTransfer,
  ORExtraTransfer__factory,
  TestToken,
  TestToken__factory,
} from '../typechain-types';

describe('ORExtraTransfer', () => {
  let signers: SignerWithAddress[];
  let orExtraTransfer: ORExtraTransfer;
  let testToken: TestToken;

  before(async function () {
    signers = await ethers.getSigners();

    orExtraTransfer = await new ORExtraTransfer__factory(signers[0]).deploy();
    await orExtraTransfer.deployed();

    testToken = await new TestToken__factory(signers[0]).deploy();
    await testToken.deployed();
  });

  it("ORExtraTransfer's functions prefixed with _ should be private", async function () {
    for (const key in orExtraTransfer.functions) {
      expect(key.replace(/^_/, '')).eq(key);
    }
  });

  it('Test transferNative', async function () {
    const balanceBefore = await signers[1].getBalance();

    const value = parseEther('1');

    const ext = hexConcat([
      '0x01', // Ext type
      solidityPack(['uint64'], [await signers[0].getChainId()]),
    ]);
    await orExtraTransfer
      .transferNative(signers[1].address, ext, {
        value,
      })
      .then((t) => t.wait());

    const balanceAfter1 = await signers[1].getBalance();

    expect(balanceAfter1.sub(balanceBefore)).eq(value);

    const tx = await signers[0].sendTransaction({
      to: signers[1].address,
      value,
      data: ext,
    });
    const receipt = await tx.wait();
    console.log('Data of sendTransaction:', tx.data);
    console.log('GasUsed of sendTransaction:', receipt.gasUsed);
  });

  it('Test transferErc20', async function () {
    // Approve
    await testToken
      .approve(orExtraTransfer.address, constants.MaxUint256)
      .then((t) => t.wait());

    const value = parseEther('0.001');

    await testToken.transfer(signers[2].address, value).then((t) => t.wait());

    const ext = hexConcat([
      '0x01', // Ext type
      solidityPack(['uint64'], [await signers[0].getChainId()]),
    ]);

    await orExtraTransfer.transferErc20(
      testToken.address,
      signers[1].address,
      value,
      ext,
    );
  });
});
