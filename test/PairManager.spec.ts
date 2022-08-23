import { ethers } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import * as _ from 'lodash';
import { expect } from 'chai';
import { ORPairManager } from '../typechain-types/contracts/ORPairManager';
import { getLpID } from './lib/PairManager';
const { keccak256 } = ethers.utils;
describe('PairManager.spec', () => {
  let pairManagerContrct: ORPairManager;
  async function deployPairManagerFixture() {
    const PairManager = await ethers.getContractFactory('ORPairManager');
    pairManagerContrct = await PairManager.deploy();
  }
  const pairList = [
    {
      sourceChain: 1,
      destChain: 7,
      sourceToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
      destToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
      ebcid: '0x0000000000000000000000000000000000000000',
    },
    {
      sourceChain: 2,
      destChain: 7,
      sourceToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
      destToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
      ebcid: '0x0000000000000000000000000000000000000000',
    },
    {
      sourceChain: 3,
      destChain: 7,
      sourceToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
      destToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
      ebcid: '0x0000000000000000000000000000000000000000',
    },
  ];
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
      .to.emit(pairManagerContrct, 'InitializePair')
      .withArgs(anyValue);
  });
  it('Verify root hash', async () => {
    expect(await pairManagerContrct.pairsHash()).to.equal(tree.getHexRoot());
  });

  it('Update root hash', async () => {
    const leafs = [getLpID(pairList[0])];
    const allLeaves = tree.getLeaves();
    const leaves = leafs.map((row) => {
      return allLeaves[tree.getLeafIndex(<any>row)];
    });
    const proof = tree.getMultiProof(leaves);
    const proofFlags = tree.getProofFlags(leaves, proof);
    const newPair = [
      {
        sourceChain: 1,
        destChain: 6,
        sourceToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
        destToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
        ebcid: '0x0000000000000000000000000000000000000000',
      },
    ];
    const result = await pairManagerContrct.updatePair(
      leafs,
      proof,
      proofFlags,
      <any>newPair,
    );
    await expect(result)
      .to.emit(pairManagerContrct, 'ChangePair')
      .withArgs('Update', anyValue);
  });
  it('Update After Verify RootHash', async () => {
    // new pair
    const newPairList = _.clone(pairList);
    newPairList[0] = {
      sourceChain: 1,
      destChain: 6,
      sourceToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
      destToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
      ebcid: '0x0000000000000000000000000000000000000000',
    };
    const newTree = new MerkleTree(newPairList.map(getLpID), keccak256, {
      sort: true,
    });
    expect(await pairManagerContrct.pairsHash()).to.equal(newTree.getHexRoot());
  });
  it('Add New Pair', async () => {
    // new pair
    const newPairList = _.clone(pairList);
    const newPair = [
      {
        sourceChain: 1,
        destChain: 13,
        sourceToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
        destToken: '0xdac17f958d2ee523a2206206994597c13d831ec7',
        ebcid: '0x0000000000000000000000000000000000000000',
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
      .to.emit(pairManagerContrct, 'ChangePair')
      .withArgs('Create', anyValue);
    expect(await pairManagerContrct.pairsHash()).to.equal(localNewRoot);
  });
});
//
