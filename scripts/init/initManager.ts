import { ethers } from 'hardhat';
import { ORManager } from '../../typechain-types';
import { MerkleTree } from 'merkletreejs';
import keccak256 from 'keccak256';
import { PAIR_LIST } from '../../test/lib/Config';
const leafs = PAIR_LIST.map((row) => {
  return Buffer.from(row.id, 'hex');
});
export const pairTree = new MerkleTree(leafs, keccak256, {
  sort: true,
});
async function main() {
  const managerContract: ORManager = await ethers.getContractAt(
    'ORManager',
    String(process.env['ManagerContract']),
  );
  // create Pair
  const proof = await pairTree.getMultiProof(leafs);
  const proofFlags = pairTree.getProofFlags(leafs, proof);
  const addPairObj = leafs.map((hashBuf) => {
    const leaf = PAIR_LIST.find((pair) => {
      return pair.id.toString() === hashBuf.toString('hex');
    });
    return leaf;
  });
  const tx = await managerContract.createPair(
    <any>addPairObj,
    pairTree.getHexRoot(),
    proof,
    proofFlags,
  );
  console.log('Create Pair tx:', tx.hash);
  console.log(`\n${pairTree.toString()}\n`);
  // set chain
  // for (const row of chainInfoList) {
  //   await managerContract.setChainInfo(
  //     row.chainID,
  //     row.batchLimit,
  //     row.maxDisputeTime,
  //     row.tokenList,
  //   );
  // }
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
