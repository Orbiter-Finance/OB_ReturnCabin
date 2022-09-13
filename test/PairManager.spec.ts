import { ethers } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { getPairID } from './lib/Utils';
import { PAIR_LIST } from './lib/Config';
import { ORManager } from '../typechain-types';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { expect } from 'chai';
import keccak256 from 'keccak256';
let PairTree: MerkleTree;
let allPairLeafList: any[] = [];
describe('PairManager.spec', () => {
  let pairManagerContrct: ORManager;
  async function deployPairManagerFixture() {
    const factoryAddress =
      process.env['factory'] || '0xa5f78a0EA71D09E4C4207819B15FdFA215AB7095';
    !expect(factoryAddress).not.empty;
    pairManagerContrct = await ethers.getContractAt(
      'ORManager',
      factoryAddress,
    );

    // const PairManagerContrct = await ethers.getContractFactory('ORPairManager');
    // pairManagerContrct = await PairManagerContrct.deploy();
  }
  allPairLeafList = PAIR_LIST.map((row: any) => {
    row.leaf = Buffer.from(getPairID(row), 'hex');
    return row;
  });
  PairTree = new MerkleTree([], keccak256, {
    sort: true,
  });
  before(deployPairManagerFixture);
  it('createPair Pair1', async () => {
    PairTree.addLeaves([allPairLeafList[0].leaf, allPairLeafList[1].leaf]);
    const proofLeavesHash = [PAIR_LIST[0], PAIR_LIST[1]].map((row) => {
      return Buffer.from(getPairID(row), 'hex');
    });
    const proof = await PairTree.getMultiProof(proofLeavesHash);
    const proofFlags = PairTree.getProofFlags(proofLeavesHash, proof);
    const addPairObj = proofLeavesHash.map((hashBuf) => {
      const leaf = allPairLeafList.find(
        (pair) => pair.leaf.toString('hex') === hashBuf.toString('hex'),
      );
      return leaf;
    });
    const tx = await pairManagerContrct.createPair(
      addPairObj,
      PairTree.getHexRoot(),
      proof,
      proofFlags,
    );
    await expect(tx)
      .to.emit(pairManagerContrct, 'PairLogEvent')
      .withArgs(0, anyValue);
  });
  // it('createPair Pair2', async () => {
  //   PairTree.addLeaves([allPairLeafList[3].leaf, allPairLeafList[2].leaf]);
  //   const proofLeavesHash = [PAIR_LIST[2], PAIR_LIST[3]].map((row) => {
  //     return Buffer.from(getPairID(row), 'hex');
  //   });
  //   const proof = await PairTree.getMultiProof(proofLeavesHash);
  //   const proofFlags = PairTree.getProofFlags(proofLeavesHash, proof);
  //   const tx = await pairManagerContrct.createPair(
  //     proofLeavesHash.map((hashBuf) => {
  //       const leaf = allPairLeafList.find(
  //         (pair) => pair.leaf.toString('hex') === hashBuf.toString('hex'),
  //       );
  //       return leaf;
  //     }),
  //     PairTree.getHexRoot(),
  //     proof,
  //     proofFlags,
  //   );
  //   await expect(tx)
  //     .to.emit(pairManagerContrct, 'PairLogEvent')
  //     .withArgs(0, anyValue);
  // });
  // it('Delete Pair', async () => {
  //   // PairTree.addLeaves([allPairLeafList[3].leaf, allPairLeafList[2].leaf]);
  //   const proofLeavesHash = [PAIR_LIST[3]].map((row) => {
  //     return Buffer.from(getPairID(row), 'hex');
  //   });

  //   const proof = await PairTree.getMultiProof(proofLeavesHash);
  //   const proofFlags = PairTree.getProofFlags(proofLeavesHash, proof);
  //   // new root hash
  //   const newLevels = PairTree.getLeaves().filter(
  //     (row) => row.toString('hex') !== allPairLeafList[3].leaf.toString('hex'),
  //   );
  //   const newTree = new MerkleTree(newLevels, keccak256, {
  //     sort: true,
  //   });
  //   const tx = await pairManagerContrct.deletePair(
  //     proofLeavesHash.map((hashBuf) => {
  //       const leaf = allPairLeafList.find(
  //         (pair) => pair.leaf.toString('hex') === hashBuf.toString('hex'),
  //       );
  //       return leaf;
  //     }),
  //     <any>proof,
  //     proofFlags,
  //     newTree.getHexRoot(),
  //   );
  //   await expect(tx)
  //     .to.emit(pairManagerContrct, 'PairLogEvent')
  //     .withArgs(1, anyValue);
  // });
});
//
