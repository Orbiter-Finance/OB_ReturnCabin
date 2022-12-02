import { expect } from 'chai';
import { ethers } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { getTxLeaf } from './index.test';
import { DataInit, getORSPVContract } from './index.test';
const dataInit = new DataInit();
const { keccak256 } = ethers.utils;
const userTxList: Array<any> = dataInit.userTxList;
const makerTxList: Array<any> = dataInit.makerTxList;
export function getUserTxTree(txList: Array<typeof userTxList[0]>) {
  const leafs = txList.map((tx) => {
    // from , to, value, nonce
    const { hex } = getTxLeaf(tx);
    return hex;
  });
  const tree = new MerkleTree(leafs, keccak256, {
    sort: true,
  });
  return tree;
}
export function getMakerTxTree(txList: Array<typeof userTxList[0]>) {
  const leafs = txList.map((tx) => {
    // from , to, value, nonce
    const { hex } = getTxLeaf(tx);
    return hex;
  });
  const tree = new MerkleTree(leafs, keccak256, {
    sort: true,
  });
  return tree;
}
describe('ORSpv.spec.ts', () => {
  let spv: any;
  const fromChainId = 5;
  const toChainId = 599;
  let userTxTree: MerkleTree;
  let makerTxTree: MerkleTree;
  async function deploySpvFixture() {
    spv = await getORSPVContract();
    userTxTree = getUserTxTree(userTxList);
    makerTxTree = getMakerTxTree(makerTxList);
    console.log(`UserTree：\n`, userTxTree.toString());
    console.log(`MakerTree：\n`, makerTxTree.toString());
  }

  before(deploySpvFixture);
  describe('SPV User Test', () => {
    it('SetMerkleRoot', async () => {
      const root = userTxTree.getHexRoot();
      const tx = await spv.setUserTxTreeRoot(fromChainId, root);
      expect(tx.blockNumber).gt(0);
    });
    it('Get Root', async () => {
      const root = userTxTree.getHexRoot();
      const chainRoot = await spv.getUserTxHash(fromChainId);
      expect(chainRoot).equals(root);
    });
    it('Local VerifyProof', () => {
      const root = userTxTree.getHexRoot();
      const { hex: leafHash } = getTxLeaf(userTxList[0]);
      const proof = userTxTree.getHexProof(leafHash);
      const result = userTxTree.verify(proof, leafHash, root);
      expect(result).true;
    });
    it('Local VerifyProof non-existent', () => {
      const root = userTxTree.getHexRoot();
      const leaf = 'A';
      const proof = userTxTree.getProof(leaf);
      const result = userTxTree.verify(proof, leaf, root);
      expect(result).false;
    });

    it('Contract VerifyProof', async () => {
      const { hex: leafHash, leaf }: any = getTxLeaf(userTxList[0]);
      const proof = userTxTree.getHexProof(leafHash);
      const result = await spv.verifyUserTxProof(leaf, proof);
      expect(result).true;
    });
    it('Contract VerifyProof non-existent', async () => {
      const { hex: leafHash, leaf } = getTxLeaf(userTxList[0]);
      leaf.chainID = '2';
      const proof = userTxTree.getHexProof(leafHash);
      const result = await spv.verifyUserTxProof(<any>leaf, proof);
      expect(result).false;
    });
  });
  describe('SPV Maker Test', () => {
    it('SetMerkleRoot', async () => {
      const root = makerTxTree.getHexRoot();
      const tx = await spv.setMakerTxTreeRoot(toChainId, root);
      expect(tx.blockNumber).gt(0);
    });
    it('Get Root', async () => {
      const root = makerTxTree.getHexRoot();
      const chainRoot = await spv.getMakerTxHash(toChainId);
      expect(chainRoot).equals(root);
    });
    it('Local VerifyProof', () => {
      const root = makerTxTree.getHexRoot();
      const { hex: leafHash } = getTxLeaf(makerTxList[0]);
      const proof = makerTxTree.getHexProof(leafHash);
      const result = makerTxTree.verify(proof, leafHash, root);
      expect(result).true;
    });
    it('Local VerifyProof non-existent', () => {
      const root = makerTxTree.getHexRoot();
      const leaf = 'A';
      const proof = makerTxTree.getProof(leaf);
      const result = makerTxTree.verify(proof, leaf, root);
      expect(result).false;
    });

    it('Contract VerifyProof', async () => {
      const { hex: leafHash, leaf }: any = getTxLeaf(makerTxList[0]);
      const proof = makerTxTree.getHexProof(leafHash);
      const result = await spv.verifyMakerTxProof(leaf, proof);
      expect(result).true;
    });
    it('Contract VerifyProof non-existent', async () => {
      const { hex: leafHash, leaf } = getTxLeaf(makerTxList[0]);
      leaf.chainID = '2';
      const proof = makerTxTree.getHexProof(leafHash);
      const result = await spv.verifyMakerTxProof(<any>leaf, proof);
      expect(result).false;
    });
  });
});
