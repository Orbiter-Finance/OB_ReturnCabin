import { ethers } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { getLpID } from './lib/PairManager';
import { pairList } from './lib/Config';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { expect } from 'chai';
import keccak256 from 'keccak256';
import { ORManagerFactory } from '../typechain-types/contracts/ORManagerFactory';
let PairTree: MerkleTree;
let allPairLeafList: any[] = [];
describe('PairManager.spec', () => {
  let pairManagerContrct: ORManagerFactory;
  async function deployPairManagerFixture() {
    const factoryAddress = process.env['factory'] || '';
    !expect(factoryAddress).not.empty;
    pairManagerContrct = await ethers.getContractAt(
      'ORManagerFactory',
      factoryAddress,
    );

    // const PairManagerContrct = await ethers.getContractFactory('ORPairManager');
    // pairManagerContrct = await PairManagerContrct.deploy();
  }
  allPairLeafList = pairList.map((row: any) => {
    row.leaf = getLpID(row);
    return row;
  });
  PairTree = new MerkleTree([], keccak256, {
    sort: true,
  });
  before(deployPairManagerFixture);
  it('createPair Pair1', async () => {
    PairTree.addLeaves([allPairLeafList[0].leaf, allPairLeafList[1].leaf]);
    const proofLeavesHash = [pairList[0], pairList[1]].map(getLpID);
    const proof = await PairTree.getMultiProof(proofLeavesHash);
    const proofFlags = PairTree.getProofFlags(proofLeavesHash, proof);
    const tx = await pairManagerContrct.createPair(
      proofLeavesHash.map((hashBuf) => {
        const leaf = allPairLeafList.find(
          (pair) => pair.leaf.toString('hex') === hashBuf.toString('hex'),
        );
        return leaf;
      }),
      PairTree.getHexRoot(),
      proof,
      proofFlags,
    );
    await expect(tx)
      .to.emit(pairManagerContrct, 'PairLogEvent')
      .withArgs(0, anyValue);
  });
  it('createPair Pair2', async () => {
    PairTree.addLeaves([allPairLeafList[3].leaf, allPairLeafList[2].leaf]);
    const proofLeavesHash = [pairList[2], pairList[3]].map(getLpID);
    const proof = await PairTree.getMultiProof(proofLeavesHash);
    const proofFlags = PairTree.getProofFlags(proofLeavesHash, proof);
    const tx = await pairManagerContrct.createPair(
      proofLeavesHash.map((hashBuf) => {
        const leaf = allPairLeafList.find(
          (pair) => pair.leaf.toString('hex') === hashBuf.toString('hex'),
        );
        return leaf;
      }),
      PairTree.getHexRoot(),
      proof,
      proofFlags,
    );
    await expect(tx)
      .to.emit(pairManagerContrct, 'PairLogEvent')
      .withArgs(0, anyValue);
  });
  it('Delete Pair', async () => {
    // PairTree.addLeaves([allPairLeafList[3].leaf, allPairLeafList[2].leaf]);
    const proofLeavesHash = [pairList[3]].map(getLpID);

    const proof = await PairTree.getMultiProof(proofLeavesHash);
    const proofFlags = PairTree.getProofFlags(proofLeavesHash, proof);
    // new root hash
    const newLevels = PairTree.getLeaves().filter(
      (row) => row.toString('hex') !== allPairLeafList[3].leaf.toString('hex'),
    );
    const newTree = new MerkleTree(newLevels, keccak256, {
      sort: true,
    });
    const tx = await pairManagerContrct.deletePair(
      proofLeavesHash.map((hashBuf) => {
        const leaf = allPairLeafList.find(
          (pair) => pair.leaf.toString('hex') === hashBuf.toString('hex'),
        );
        return leaf;
      }),
      <any>proof,
      proofFlags,
      newTree.getHexRoot(),
    );
    await expect(tx)
      .to.emit(pairManagerContrct, 'PairLogEvent')
      .withArgs(1, anyValue);
  });
});
//
