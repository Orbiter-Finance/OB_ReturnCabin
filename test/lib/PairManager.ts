import { ethers } from 'ethers';
const { solidityKeccak256 } = ethers.utils;
export interface PairChainInfoStruct {
  sourceChain: number;
  destChain: number;
  sourceTAddress: string;
  destTAddress: string;
  ebcid: any;
}
export const getLpID = (pair: PairChainInfoStruct) => {
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
