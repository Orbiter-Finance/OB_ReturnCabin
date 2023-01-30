import { DataInit } from '../../test/utils.test';
import { ethers } from 'hardhat';
import keccak256 from 'keccak256';
import { orderBy } from 'lodash';
import MerkleTree from 'merkletreejs';
import { ORManager } from '../../typechain-types';
import { deploy, printContract, printSuccess } from '../utils';
// import { chains, pairs } from '../../test/georli.data.json';
const dataInit = new DataInit().initChains().initPairs();
import { getPairID } from '../../test/utils.test';
let contractAddress = process.env['ORManager'] || '';
async function getManagerContract(): Promise<ORManager> {
  if (contractAddress) {
    const manager = await ethers.getContractAt('ORManager', contractAddress);
    printContract('load manager contract:', manager.address.toString());
    return manager;
  } else {
    const manager = await deploy<ORManager>(true, 'ORManager');
    contractAddress = manager.address;
    return manager;
  }
}
async function initChain() {
  const contract = await getManagerContract();
  for (const chain of DataInit.chains) {
    const tokenList = chain.tokenList.map((row) => row.address);
    const tx = await contract.setChainInfo(
      chain.chainID,
      chain.batchLimit,
      chain.maxDisputeTime,
      chain.maxReceiptTime,
      chain.stopDelayTime,
      tokenList,
    );
    await tx.wait();
    printSuccess(`Add Chain ${chain.chainID} Hash: ${tx.hash}`);
    for (const token of chain.tokenList) {
      const tx = await contract.setTokenInfo(
        chain.chainID,
        token.decimals,
        token.address,
        token.pledgeToken,
      );
      await tx.wait();
      printSuccess(
        `Add Chain Token ${token.symbol} ${chain.chainID} Token:${token.address} Hash: `,
        tx.hash,
      );
    }
  }
}
async function initPair() {
  const contract = await getManagerContract();
  const newPairs = DataInit.pairs.map((row: any) => {
    row.id = getPairID(row);
    return row;
  });
  const pairTree = new MerkleTree(
    newPairs.map((row) => row.id),
    keccak256,
    {
      sort: true,
    },
  );
  const sortAfter = orderBy(newPairs, ['id'], ['asc']);
  const leaves = pairTree.getLeaves();
  const proof = pairTree.getMultiProof(leaves);
  const proofFlag = pairTree.getProofFlags(leaves, proof);
  const tx = await contract.createPair(
    sortAfter,
    pairTree.getHexRoot(),
    proof,
    proofFlag,
  );
  printSuccess(`Multiple CreatePair Hash:${tx.hash}`);
}
export async function main() {
  await initChain();
  await initPair();
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
