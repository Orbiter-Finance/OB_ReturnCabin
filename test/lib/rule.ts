import { BigNumber, Wallet } from 'ethers';

export const ruleTypes = [
  'uint16',
  'uint16',
  'uint8',
  'uint8',
  'uint',
  'uint',
  'uint128',
  'uint128',
  'uint128',
  'uint128',
  'uint16',
  'uint16',
  'uint32',
  'uint32',
  'uint32',
  'uint32',
];

export const createRandomRule = () => {
  return [
    1,
    2,
    0,
    1,
    Wallet.createRandom().address,
    Wallet.createRandom().address,
    BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1),
    BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1),
    BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1),
    BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1),
    1,
    2,
    (2 ^ 32) - 1,
    (2 ^ 31) - 1,
    (2 ^ 30) - 1,
    (2 ^ 29) - 1,
  ];
};
