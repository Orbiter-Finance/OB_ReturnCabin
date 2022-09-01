import { ethers } from 'ethers';
import { PairStruct, LpInfoStruct } from './Config';
const { solidityKeccak256 } = ethers.utils;
export const getPairID = (pair: PairStruct): string => {
  const lpId = solidityKeccak256(
    ['uint256', 'uint256', 'address', 'address', 'uint256'],
    [
      pair.sourceChain,
      pair.destChain,
      pair.sourceTAddress,
      pair.destTAddress,
      pair.ebcid,
    ],
  );
  return lpId.replace('0x', '');
  // return Buffer.from(lpId.replace('0x', ''), 'hex');
};
export const getPairLPID = (lp: LpInfoStruct): string => {
  const lpId = solidityKeccak256(
    [
      'bytes32',
      'uint256',
      'uint256',
      'uint256',
      'uint256',
      'uint256',
      'uint256',
      'uint256',
      'uint256',
    ],
    [
      `0x${lp.pairId}`,
      ethers.BigNumber.from(lp.maxPrice),
      ethers.BigNumber.from(lp.minPrice),
      ethers.BigNumber.from(lp.gasFee),
      ethers.BigNumber.from(lp.tradingFee),
      ethers.BigNumber.from(lp.startTime),
      ethers.BigNumber.from(lp.stopTime || 0),
      ethers.BigNumber.from(lp.sourcePresion),
      ethers.BigNumber.from(lp.destPresion),
    ],
  );

  return lpId.replace('0x', '');
  // return Buffer.from(lpId.replace('0x', ''), 'hex');
};
