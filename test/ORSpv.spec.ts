import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { MAKER_TX_LIST, USER_TX_LIST } from './lib/Config';
import { getLeaf } from './lib/Utils';
const { keccak256 } = ethers.utils;
describe('ORSpv.spec.ts', () => {
  let spv: any;
  const chainId = '1';
  let userTxTree: MerkleTree;
  let makerTxTree: MerkleTree;
  async function deploySpvFixture() {
    const ORSpv = await ethers.getContractFactory('ORSpv', {
      libraries: {},
    });
    spv = await upgrades.deployProxy(ORSpv);
    await spv.deployed();
    console.log('spv address', spv.address);
    process.env['SPV'] = spv.address;
    const { tree: tree1 } = generateMerkleTree(USER_TX_LIST, true);
    userTxTree = tree1;
    const { tree: tree2 } = generateMerkleTree(MAKER_TX_LIST, false);
    makerTxTree = tree2;
    // console.log(`UserTree：\n`, tree1.toString());
    // console.log(`MakerTree：\n`, tree2.toString());
  }

  before(deploySpvFixture);
  function generateMerkleTree(
    txList: Array<typeof USER_TX_LIST[0]>,
    status: boolean,
  ) {
    const leafs = txList.map((tx) => {
      // from , to, value, nonce
      const { hex } = getLeaf(tx, status);
      return hex;
    });
    const tree = new MerkleTree(leafs, keccak256, {
      sort: true,
    });
    return { tree };
  }
  describe('SPV User Test', () => {
    it('SetMerkleRoot', async () => {
      const root = userTxTree.getHexRoot();
      const tx = await spv.setUserTxTreeRoot(chainId, root);
      expect(tx.blockNumber).gt(0);
    });
    it('Get Root', async () => {
      const root = userTxTree.getHexRoot();
      const chainRoot = await spv.userTxTree(chainId);
      expect(chainRoot).equals(root);
    });
    it('Local VerifyProof', () => {
      const root = userTxTree.getHexRoot();
      const { hex: leafHash } = getLeaf(USER_TX_LIST[0], true);
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
      const { hex: leafHash, leaf }: any = getLeaf(USER_TX_LIST[0], true);
      const proof = userTxTree.getHexProof(leafHash);
      const result = await spv.verifyUserTxProof(leaf, proof);
      expect(result).true;
    });
    it('Contract VerifyProof non-existent', async () => {
      const { hex: leafHash, leaf } = getLeaf(USER_TX_LIST[0], true);
      leaf.chainID = '2';
      const proof = userTxTree.getHexProof(leafHash);
      const result = await spv.verifyUserTxProof(<any>leaf, proof);
      expect(result).false;
    });

    // it('Set validation record', async () => {
    //   const { hex: leafHash }: any = getLeaf(USER_TX_LIST[0]);
    //   const tx = await spv.setVerifyRecordsee(leafHash);
    //   expect(tx.blockNumber).gt(0);
    // });
    // it('Set validation record:(Txid Verified)', async () => {
    //   const { hex: leafHash }: any = getLeaf(USER_TX_LIST[0]);
    //   await expect(spv.setVerifyRecordsee(leafHash)).to.be.rejectedWith(
    //     'Txid Verified',
    //   );
    // });

    // it('Verified records', async () => {
    //   const { hex: leafHash }: any = getLeaf(USER_TX_LIST[0]);
    //   const result = await spv.isVerify(leafHash);
    //   expect(result).true;
    // });
    // it('Unverified records', async () => {
    //   const { hex: leafHash }: any = getLeaf(USER_TX_LIST[1]);
    //   const result = await spv.isVerify(leafHash);
    //   expect(result).false;
    // });
  });
  describe('SPV Maker Test', () => {
    const chainId = 7;
    it('SetMerkleRoot', async () => {
      const root = makerTxTree.getHexRoot();
      const tx = await spv.setMakerTxTreeRoot(chainId, root);
      expect(tx.blockNumber).gt(0);
    });
    it('Get Root', async () => {
      const root = makerTxTree.getHexRoot();
      const chainRoot = await spv.makerTxTree(chainId);
      expect(chainRoot).equals(root);
    });
    it('Local VerifyProof', () => {
      const root = makerTxTree.getHexRoot();
      const { hex: leafHash } = getLeaf(MAKER_TX_LIST[0], false);
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
      const { hex: leafHash, leaf }: any = getLeaf(MAKER_TX_LIST[0], false);
      const proof = makerTxTree.getHexProof(leafHash);
      const result = await spv.verifyMakerTxProof(leaf, proof);
      expect(result).true;
    });
    it('Contract VerifyProof non-existent', async () => {
      const { hex: leafHash, leaf } = getLeaf(MAKER_TX_LIST[0], false);
      leaf.chainID = '2';
      const proof = makerTxTree.getHexProof(leafHash);
      const result = await spv.verifyMakerTxProof(<any>leaf, proof);
      expect(result).false;
    });
  });
});
