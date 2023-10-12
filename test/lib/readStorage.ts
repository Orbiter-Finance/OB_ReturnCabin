import { BytesLike, BigNumberish } from 'ethers';
import { ethers } from 'hardhat';
// require('dotenv').config();

// ethers methods
const utils = ethers.utils;
const BigNumber = ethers.BigNumber;
const MaxUint256 = ethers.constants.MaxUint256;

async function getShortStr(
  slot: BytesLike,
  contractAddress: string | Promise<string>,
) {
  const paddedSlot = utils.hexZeroPad(slot, 32);
  const storageLocation = await ethers.provider.getStorageAt(
    contractAddress,
    paddedSlot,
  );
  const storageValue = BigNumber.from(storageLocation);

  const stringData = utils.toUtf8String(
    storageValue.and(MaxUint256.sub(255)).toHexString(),
  );
  return stringData.replace(/\x00/g, '');
}

async function getLongStr(
  slot: BytesLike,
  contractAddress: string | Promise<string>,
) {
  const paddedSlot = utils.hexZeroPad(slot, 32);
  const storageReference = await ethers.provider.getStorageAt(
    contractAddress,
    paddedSlot,
  );

  const baseSlot = utils.keccak256(paddedSlot);
  const sLength = BigNumber.from(storageReference).shr(1).toNumber();
  const totalSlots = Math.ceil(sLength / 32);

  let storageLocation = BigNumber.from(baseSlot).toHexString();
  let str = '';

  for (let i = 1; i <= totalSlots; i++) {
    const stringDataPerSlot = await ethers.provider.getStorageAt(
      contractAddress,
      storageLocation,
    );
    str = str.concat(utils.toUtf8String(stringDataPerSlot));
    storageLocation = BigNumber.from(baseSlot).add(i).toHexString();
  }
  return str.replace(/\x00/g, '');
}

export async function getUint256(
  slot: BytesLike,
  contractAddress: string | Promise<string>,
) {
  const paddedSlot = utils.hexZeroPad(slot, 32);
  const storageLocation = await ethers.provider.getStorageAt(
    contractAddress,
    paddedSlot,
  );
  const storageValue = BigNumber.from(storageLocation);
  return storageValue;
}

async function getBytePackedVar(
  slot: BytesLike,
  contractAddress: string | Promise<string>,
  byteShift: number,
  byteSize: number,
) {
  const paddedSlot = utils.hexZeroPad(slot, 32);
  const storageLocation = await ethers.provider.getStorageAt(
    contractAddress,
    paddedSlot,
  );
  let result = '';
  let altByteSize = 0;
  let altByteShift = 0;
  let check = false;

  if (byteSize <= 6) {
    return BigNumber.from(storageLocation)
      .shr(byteShift * 4)
      .mask(byteSize * 4 * 2)
      .toNumber()
      .toString(16);
  } else {
    altByteSize = byteSize - 6;
    altByteShift = byteShift + 12;
    check = true;
    result += await getBytePackedVar(
      slot,
      contractAddress,
      altByteShift,
      altByteSize,
    );
  }

  if (check) {
    result += await getBytePackedVar(slot, contractAddress, byteShift, 6);
  }
  return result;
}

async function getArrayItem(
  slot: BytesLike,
  contractAddress: any,
  item: number,
  byteSize: number,
) {
  const hashedSlot = utils.keccak256(utils.hexZeroPad(slot, 32));
  const itemsPerSlot = 32 / byteSize;
  const itemPos = item;

  for (let s = 1; s < item; s++) {
    if (item >= itemsPerSlot) {
      itemPos - itemsPerSlot;
    }
  }

  let byteShift = (itemPos / itemsPerSlot) * 64;
  while (byteShift >= 64) {
    byteShift -= 64;
  }
  const hashedSlotByItem = BigNumber.from(hashedSlot)
    .add(Math.floor(item / itemsPerSlot))
    .toHexString();

  return getBytePackedVar(
    hashedSlotByItem,
    contractAddress,
    byteShift,
    byteSize,
  );
}

export async function getMappingItem(
  slot: BytesLike,
  contractAddress: any,
  key: BytesLike,
) {
  const paddedSlot = utils.hexZeroPad(slot, 32);
  const paddedKey = utils.hexZeroPad(key, 32);
  const itemSlot = utils.keccak256(paddedKey + paddedSlot.slice(2));
  return await getUint256(itemSlot, contractAddress);
}

export async function getMappingStruct(
  slot: BytesLike,
  contractAddress: any,
  key: BytesLike,
  item: BigNumberish,
  type: any,
) {
  const paddedSlot = utils.hexZeroPad(slot, 32);
  const paddedKey = utils.hexZeroPad(key, 32);
  const itemSlot1 = utils.keccak256(paddedKey + paddedSlot.slice(2));
  const itemSlot = BigNumber.from(itemSlot1).add(item).toHexString();
  switch (type) {
    case 'string':
      return await getShortStr(itemSlot, contractAddress);
    case 'bytes':
      return getBytePackedVar(itemSlot, contractAddress, 0, 32);
    case 'number':
      return getUint256(itemSlot, contractAddress);
  }
}

export async function getMappingStructXSlot(
  _slot: BytesLike,
  contractAddress: any,
  key: BytesLike,
  item: BigNumberish,
  type: any,
) {
  const paddedSlot = utils.hexZeroPad(_slot, 32);
  const paddedKey = utils.hexZeroPad(key, 32);
  const itemSlot1 = utils.keccak256(paddedKey + paddedSlot.slice(2));
  const itemSlot = BigNumber.from(itemSlot1).add(item).toHexString();
  const slot = BigNumber.from(itemSlot1).toHexString();
  let value;
  switch (type) {
    case 'string':
      value = await getShortStr(itemSlot, contractAddress);
    case 'bytes':
      value = getBytePackedVar(itemSlot, contractAddress, 0, 32);
    case 'number':
      value = getUint256(itemSlot, contractAddress);
  }

  return {
    slot,
    itemSlot,
    value,
  };
}

async function getNestedMappingStruct(
  slot: BytesLike,
  contractAddress: any,
  key: BytesLike,
  item: BigNumberish,
  nestedKey: BytesLike,
) {
  const paddedSlot = utils.hexZeroPad(slot, 32);
  const paddedKey = utils.hexZeroPad(key, 32);
  const itemSlot1 = utils.keccak256(paddedKey + paddedSlot.slice(2));
  const itemSlot = BigNumber.from(itemSlot1).add(item).toHexString();
  const paddednestedKey = utils.hexZeroPad(nestedKey, 32);
  const itemNestedSlot = utils.keccak256(paddednestedKey + itemSlot.slice(2));

  return getUint256(itemNestedSlot, contractAddress);
}
