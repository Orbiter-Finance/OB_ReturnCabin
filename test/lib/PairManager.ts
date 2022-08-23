import { ethers } from 'ethers';
export const getLpID = (pair: any) => {
  return ethers.utils.solidityKeccak256(
    ['uint256', 'uint256', 'address', 'address', 'uint256'],
    [
      pair.sourceChain,
      pair.destChain,
      pair.sourceToken,
      pair.destToken,
      pair.ebcid,
    ],
  );
};
