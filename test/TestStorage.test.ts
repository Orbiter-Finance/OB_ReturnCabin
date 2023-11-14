import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import {
  defaultAbiCoder,
  hexConcat,
  hexDataSlice,
  hexZeroPad,
  keccak256,
  parseEther,
} from 'ethers/lib/utils';
import { ethers } from 'hardhat';
import { TestStorage, TestStorage__factory } from '../typechain-types';

describe('TestStorage', () => {
  let signers: SignerWithAddress[];
  let testStorage: TestStorage;

  const getStorageAt = async (
    position: BigNumberish | Promise<BigNumberish>,
  ) => {
    return await testStorage.provider.getStorageAt(
      testStorage.address,
      position,
    );
  };

  before(async function () {
    signers = await ethers.getSigners();

    testStorage = await new TestStorage__factory(signers[0]).deploy();
    await testStorage.deployed();
    console.warn('Address of testStorage:', testStorage.address);
  });

  it('Function updateU256', async function () {
    const u256 = parseEther('100');
    await testStorage.updateU256(u256).then((t) => t.wait());

    const storageValue = await getStorageAt(hexZeroPad('0x00', 32));

    expect(hexZeroPad(u256.toHexString(), 32)).to.eq(storageValue);
  });

  it('Function updateU64s', async function () {
    const u64_1 = parseEther('1');
    const u64_2 = parseEther('2');
    const u64_3 = parseEther('3');
    const u64_4 = parseEther('4');
    await testStorage
      .updateU64s(u64_1, u64_2, u64_3, u64_4)
      .then((t) => t.wait());

    const storageValue = await getStorageAt(hexZeroPad('0x01', 32));
    const storageU64_1 = hexDataSlice(storageValue, 24, 32);
    const storageU64_2 = hexDataSlice(storageValue, 16, 24);
    const storageU64_3 = hexDataSlice(storageValue, 8, 16);
    const storageU64_4 = hexDataSlice(storageValue, 0, 8);

    expect(hexZeroPad(u64_1.toHexString(), 8)).to.eq(storageU64_1);
    expect(hexZeroPad(u64_2.toHexString(), 8)).to.eq(storageU64_2);
    expect(hexZeroPad(u64_3.toHexString(), 8)).to.eq(storageU64_3);
    expect(hexZeroPad(u64_4.toHexString(), 8)).to.eq(storageU64_4);
  });

  it('Function updateU128s', async function () {
    const u128_1 = parseEther('100');
    const u128_2 = parseEther('200');
    await testStorage.updateU128s(u128_1, u128_2).then((t) => t.wait());

    const storageValue = await getStorageAt(hexZeroPad('0x02', 32));
    const storageU128_1 = hexDataSlice(storageValue, 16, 32);
    const storageU128_2 = hexDataSlice(storageValue, 0, 16);

    expect(hexZeroPad(u128_1.toHexString(), 16)).to.eq(storageU128_1);
    expect(hexZeroPad(u128_2.toHexString(), 16)).to.eq(storageU128_2);
  });

  it('Function updateArray', async function () {
    const arr = [parseEther('0.1'), parseEther('0.2'), parseEther('0.3')];
    await testStorage.updateArray(arr, []).then((t) => t.wait());

    const storageKey = keccak256(hexZeroPad('0x03', 32));
    const storageValue = await getStorageAt(storageKey);
    const storageArray_0 = hexDataSlice(storageValue, 16, 32);
    const storageArray_1 = hexDataSlice(storageValue, 0, 16);
    expect(hexZeroPad(arr[0].toHexString(), 16)).to.eq(storageArray_0);
    expect(hexZeroPad(arr[1].toHexString(), 16)).to.eq(storageArray_1);

    const storageValue1 = await getStorageAt(
      hexZeroPad(BigNumber.from(storageKey).add(1).toHexString(), 32),
    );
    const storageArray_2 = hexDataSlice(storageValue1, 16, 32);
    expect(hexZeroPad(arr[2].toHexString(), 16)).to.eq(storageArray_2);
  });

  it('Function updateMapping', async function () {
    const key = '0x01';
    const value = parseEther('300');
    await testStorage.updateMapping(key, value).then((t) => t.wait());

    const storageKey = keccak256(
      hexConcat([hexZeroPad(key, 32), hexZeroPad('0x04', 32)]),
    );
    const storageValue = await getStorageAt(storageKey);

    expect(hexZeroPad(value.toHexString(), 32)).to.eq(storageValue);
  });

  it('Function updateMappingStruct', async function () {
    const key = '0x01';
    const struct = {
      u128_1: parseEther('400'),
      u128_2: parseEther('500'),
      u128_3: parseEther('600'),
      uarr: ['0x1000', '0x2000', '0x3000'],
    };

    await testStorage.updateMappingStruct(key, struct).then((t) => t.wait());

    const storageKey = keccak256(
      defaultAbiCoder.encode(['uint256', 'uint256'], [key, '0x05']),
    );
    const storageValue = await getStorageAt(storageKey);
    const storageU128_1 = hexDataSlice(storageValue, 16, 32);
    const storageU128_2 = hexDataSlice(storageValue, 0, 16);
    expect(hexZeroPad(struct.u128_1.toHexString(), 16)).to.eq(storageU128_1);
    expect(hexZeroPad(struct.u128_2.toHexString(), 16)).to.eq(storageU128_2);

    const storageValue1 = await getStorageAt(
      hexZeroPad(BigNumber.from(storageKey).add(1).toHexString(), 32),
    );
    const storageU128_3 = hexDataSlice(storageValue1, 16, 32);
    expect(hexZeroPad(struct.u128_3.toHexString(), 16)).to.eq(storageU128_3);

    const storageKeyUarr = keccak256(
      hexZeroPad(BigNumber.from(storageKey).add(2).toHexString(), 32),
    );
    for (let i = 0; i < struct.uarr.length; i++) {
      const key = hexZeroPad(
        BigNumber.from(storageKeyUarr).add(i).toHexString(),
        32,
      );
      const value = await getStorageAt(key);

      expect(BigNumber.from(value)).to.eq(BigNumber.from(struct.uarr[i]));
    }
  });

  it('Function calcSecondKey', async function () {
    const position = '0x00';
    const sub = '0x01';
    const k_byConcat = keccak256(
      hexConcat([hexZeroPad(sub, 32), hexZeroPad(position, 32)]),
    );

    const k_byEncode = keccak256(
      defaultAbiCoder.encode(['uint256', 'uint256'], [sub, position]),
    );
    expect(k_byConcat).to.eq(k_byEncode);

    const secondKey = await testStorage.calcSecondKey(position, sub);
    expect(k_byConcat).to.eq(secondKey);
  });
});
