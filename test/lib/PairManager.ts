import { ethers } from 'ethers';
export interface PairChainInfoStruct {
  sourceChain: number;
  destChain: number;
  sourceTAddress: string;
  destTAddress: string;
  ebcid: any;
}
export const getLpID = (pair: PairChainInfoStruct) => {
  return ethers.utils.solidityKeccak256(
    ['uint256', 'uint256', 'address', 'address', 'uint256'],
    [
      pair.sourceChain,
      pair.destChain,
      pair.sourceTAddress,
      pair.destTAddress,
      pair.ebcid,
    ],
  );
};
