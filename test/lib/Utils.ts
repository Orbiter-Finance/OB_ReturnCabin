import { ethers } from 'ethers';
const { solidityKeccak256 } = ethers.utils;
export interface PairChainInfoStruct {
  sourceChain: number;
  destChain: number;
  sourceTAddress: string;
  destTAddress: string;
  ebcid: any;
}
export type LpInfoStruct = {
  sourceChain: number;
  destChain: number;
  sourceTAddress: string;
  destTAddress: string;
  sourcePresion: number;
  destPresion: number;
  ebcid: number;
  minPrice: number;
  maxPrice: number;
  gasFee: number;
  tradingFee: number;
  startTime: number;
};
export const getPairID = (pair: PairChainInfoStruct) => {
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
  return Buffer.from(lpId.replace('0x', ''), 'hex');
};
export const getPairLPID = (pair: PairChainInfoStruct) => {
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
  return Buffer.from(lpId.replace('0x', ''), 'hex');
};
