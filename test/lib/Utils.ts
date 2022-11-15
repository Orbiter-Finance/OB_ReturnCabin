import { ethers } from 'ethers';
import { PairStruct, LpInfoStruct, USER_TX_LIST } from './Config';
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
  if (!process.env['MDC'] || lp.startTime <= 0) {
    return '';
  }
  const lpId = solidityKeccak256(
    [
      'bytes32',
      'address',
      // 'uint256',
      // 'uint256',
      // 'uint256',
      // 'uint256',
      'uint256',
      'uint256',
      'uint256',
      // 'uint256',
    ],
    [
      `0x${lp.pairId}`,
      process.env['MDC'],
      ethers.BigNumber.from(lp.startTime),
      ethers.BigNumber.from(lp.minPrice),
      ethers.BigNumber.from(lp.maxPrice),
    ],
  );
  return lpId.replace('0x', '');
  // return Buffer.from(lpId.replace('0x', ''), 'hex');
};
/**
 *
 * @param tx
 * @param status true:UserTxList false:MakerTxList
 * @returns
 */
export const getLeaf = (tx: typeof USER_TX_LIST[0], status: boolean) => {
  // const mdcContractAddress = process.env['MDC'] || '';
  // status === true
  //   ? (tx.to = mdcContractAddress)
  //   : (tx.from = mdcContractAddress);
  const lpid = tx.lpid.toLowerCase();
  const txHash = tx.id.toLowerCase();
  const sourceAddress = tx.from.toLowerCase();
  const destAddress = tx.to.toLowerCase();
  const nonce = tx.nonce;
  const amount = tx.value;
  const chainID = tx.chainId;
  const tokenAddress = tx.token;
  const timestamp = tx.timestamp;
  const responseAmount = tx.responseAmount;
  const responseSafetyCode = tx.responseSafetyCode;
  const ebcid = tx.ebcid;
  const hex = ethers.utils.solidityKeccak256(
    [
      'bytes32',
      'uint256',
      'bytes32',
      'address',
      'address',
      'uint256',
      'uint256',
      'address',
      'uint256',
      'uint256',
      'uint256',
      'uint256',
    ],
    [
      lpid,
      chainID,
      txHash,
      sourceAddress,
      destAddress,
      nonce,
      amount,
      tokenAddress,
      timestamp,
      responseAmount,
      responseSafetyCode,
      ebcid,
    ],
  );
  const leaf = {
    lpid,
    chainID,
    txHash,
    sourceAddress,
    destAddress,
    nonce,
    amount,
    tokenAddress,
    timestamp,
    responseAmount,
    responseSafetyCode,
    ebcid,
  };
  return { hex, leaf };
};
