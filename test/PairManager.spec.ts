import { ethers } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import * as _ from 'lodash';
import { expect } from 'chai';
import { ORPairManager } from '../typechain-types/contracts/ORPairManager';
import { getLpID } from './lib/PairManager';
import { pairList } from './lib/Config';
const { keccak256 } = ethers.utils;
describe('PairManager.spec', () => {
  let pairManagerContrct: ORPairManager;
  async function deployPairManagerFixture() {
    const PairManager = await ethers.getContractFactory('ORPairManager');
    pairManagerContrct = await PairManager.deploy();
  }
  const leafs = pairList.map(getLpID);
  const tree = new MerkleTree(leafs, keccak256, {
    sort: true,
  });
  before(deployPairManagerFixture);
  it('initialize Pair', async () => {
    const tx = await pairManagerContrct.initializePair(
      tree.getHexRoot(),
      pairList,
    );
    await expect(tx)
      .to.emit(pairManagerContrct, 'PairLogEvent')
      .withArgs(0, anyValue);
  });
  it('Verify root hash', async () => {
    expect(await pairManagerContrct.pairsRoot()).to.equal(tree.getHexRoot());
  });

  it('Update Pair', async () => {
    const leafs = [getLpID(pairList[0])];
    // const allLeaves = tree.getLeaves();
    // const leaves = leafs.map((row) => {
    //   return allLeaves[tree.getLeafIndex(<any>row)];
    // });
    // console.log(tree.getHexLayers(), '===leaves');
    const proof = tree.getHexProof(leafs[0]);
    // console.log('proof:', proof);
    // const proofFlags = tree.getProofFlags(leaves, proof);
    const newPair = [
      {
        sourceChain: 1,
        destChain: 13,
        sourceToken: '0x0000000000000000000000000000000000000000',
        destToken: '0x0000000000000000000000000000000000000000',
        ebcid: '0x0000000000000000000000000000000000000001',
      },
    ];
    const result = await pairManagerContrct.updatePair(
      leafs[0],
      proof,
      newPair[0],
    );
    await expect(result)
      .to.emit(pairManagerContrct, 'PairLogEvent')
      .withArgs(2, anyValue);
    const newPairList = _.clone(pairList);
    newPairList[0] = newPair[0];
    const newTree = new MerkleTree(newPairList.map(getLpID), keccak256, {
      sort: true,
    });

    expect(await pairManagerContrct.pairsRoot()).to.equal(newTree.getHexRoot());
  });

  it('Create New Pair', async () => {
    // new pair
    const newPairList = _.clone(pairList);
    const newPair = [
      {
        sourceChain: 1,
        destChain: 13,
        sourceToken: '0x0000000000000000000000000000000000000000',
        destToken: '0x0000000000000000000000000000000000000000',
        ebcid: '0x0000000000000000000000000000000000000001',
      },
    ];
    const newTree = new MerkleTree(newPairList.map(getLpID), keccak256);
    newTree.addLeaves(<any>newPair.map(getLpID));
    const localNewRoot = tree.getHexRoot();
    const result = await pairManagerContrct.createPair(
      localNewRoot,
      <any>newPair,
    );
    await expect(result)
      .to.emit(pairManagerContrct, 'PairLogEvent')
      .withArgs(1, anyValue);
    expect(await pairManagerContrct.pairsRoot()).to.equal(localNewRoot);
  });
  it('isSupportPair(True)', async () => {
    const lpId = getLpID(pairList[0]);
    const proof = tree.getHexProof(lpId);
    const isSupport = await pairManagerContrct.isSupportPair(lpId, proof);
    expect(isSupport).true;
  });
  it('isSupportPair(False)', async () => {
    const lpId = getLpID({
      sourceChain: 99,
      destChain: 99,
      sourceToken: '0x0000000000000000000000000000000000000000',
      destToken: '0x0000000000000000000000000000000000000000',
      ebcid: '0x0000000000000000000000000000000000000000',
    });
    const proof = tree.getHexProof(lpId);
    const isSupport = await pairManagerContrct.isSupportPair(lpId, proof);
    expect(isSupport).false;
  });
});
//
