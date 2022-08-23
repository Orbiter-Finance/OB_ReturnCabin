import { expect } from 'chai';
import { ethers } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { ORSpv } from '../typechain-types';
const { keccak256 } = ethers.utils;
const UserTxList = [
  {
    id: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b91',
    from: '0x188DD5b655E2fe78f5ede164d37170FB1B941c9e',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '1',
    fee: '46810453281384',
    value: '998798000000009003',
    nonce: 0,
  },
  {
    id: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b92',
    from: '0xAec1379dc4BDe48245F75f9726239cEC2E0C8DDa',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    chainId: '1',
    token: '0x0000000000000000000000000000000000000000',
    fee: '46810453281384',
    value: '998798000000009003',
    nonce: 1,
  },
  {
    id: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b93',
    from: '0xE879e54Ab4893953773C0b41304A05C2D49cc612',
    chainId: '1',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    fee: '46810453281384',
    value: '998798000000009003',
    nonce: 3,
  },
  {
    id: '0xfd123fe2054b7f2140ebc9be98dc8638d17f7eae74887894d220d160dc188c1b',
    from: '0xbf28bce31463a3a023c2c324aecbd5689ffa06ee',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '3',
    fee: '20969931642240',
    value: '276866090070000000',
    nonce: 9,
  },
];
const MakerTxList = [
  {
    id: '0x6f1308d493d20956ef2806439e095451ba859c02211b60595d6469858161c9bd',
    from: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    to: '0xbf28bce31463a3a023c2c324aecbd5689ffa06ee',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '7',
    fee: '378000000000000',
    value: '276016000000000009',
    nonce: 62374,
  },

  {
    id: '0xd615805a657aa2fae3172ca6f6fdbd1c0036f29c233eb2a94b408f7ef2b29a02',
    from: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    to: '0xac9facad1c42986520bd7df5ded1d30d94a13095',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '7',
    fee: '378000000000000',
    value: '389667000000000007',
    nonce: 62373,
  },
];

describe('ORSpv.spec.ts', () => {
  let spv: ORSpv;
  const chainId = '1';
  let userTxTree: MerkleTree;
  let makerTxTree: MerkleTree;
  async function deploySpvFixture() {
    const SpvLib = await ethers.getContractFactory('SpvLib');
    const spvLib = await SpvLib.deploy();
    const ORSpv = await ethers.getContractFactory('ORSpv', {
      libraries: {
        SpvLib: spvLib.address,
      },
    });
    spv = await ORSpv.deploy();
    const { tree: tree1 } = generateMerkleTree(UserTxList);
    userTxTree = tree1;
    const { tree: tree2 } = generateMerkleTree(MakerTxList);
    makerTxTree = tree2;
    console.log(`UserTree：\n`, tree1.toString());
    console.log(`MakerTree：\n`, tree2.toString());
  }

  before(deploySpvFixture);
  function getLeaf(tx: typeof UserTxList[0]) {
    const hash = tx.id.toLowerCase();
    const from = tx.from.toLowerCase();
    const to = tx.to.toLowerCase();
    const nonce = tx.nonce;
    const value = tx.value;
    const chainId = tx.chainId;
    const token = tx.token;
    const hex = ethers.utils.solidityKeccak256(
      [
        'uint256',
        'bytes32',
        'address',
        'address',
        'uint256',
        'uint256',
        'address',
      ],
      [chainId, hash, from, to, nonce, value, token],
    );
    const leaf = {
      chain: chainId,
      id: hash,
      from,
      to,
      nonce,
      value,
      token,
    };
    return { hex, leaf };
  }
  function generateMerkleTree(txList: Array<typeof UserTxList[0]>) {
    const leafs = txList.map((tx) => {
      // from , to, value, nonce
      const { hex } = getLeaf(tx);
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
      const { hex: leafHash } = getLeaf(UserTxList[0]);
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
      const { hex: leafHash, leaf }: any = getLeaf(UserTxList[0]);
      const proof = userTxTree.getHexProof(leafHash);
      const result = await spv.verifyUserTxProof(leaf, proof);
      expect(result).true;
    });
    it('Contract VerifyProof non-existent', async () => {
      const { hex: leafHash, leaf }: any = getLeaf(UserTxList[0]);
      leaf.chain = '2';
      const proof = userTxTree.getHexProof(leafHash);
      const result = await spv.verifyUserTxProof(leaf, proof);
      expect(result).false;
    });

    it('Set validation record', async () => {
      const { hex: leafHash }: any = getLeaf(UserTxList[0]);
      const tx = await spv.setVerifyRecordsee(leafHash);
      expect(tx.blockNumber).gt(0);
    });
    it('Set validation record:(Txid Verified)', async () => {
      const { hex: leafHash }: any = getLeaf(UserTxList[0]);
      await expect(spv.setVerifyRecordsee(leafHash)).to.be.rejectedWith(
        'Txid Verified',
      );
    });

    it('Verified records', async () => {
      const { hex: leafHash }: any = getLeaf(UserTxList[0]);
      const result = await spv.isVerify(leafHash);
      expect(result).true;
    });
    it('Unverified records', async () => {
      const { hex: leafHash }: any = getLeaf(UserTxList[1]);
      const result = await spv.isVerify(leafHash);
      expect(result).false;
    });
  });
  describe('SPV Makerr Test', () => {
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
      const { hex: leafHash } = getLeaf(MakerTxList[0]);
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
      const { hex: leafHash, leaf }: any = getLeaf(MakerTxList[0]);
      const proof = makerTxTree.getHexProof(leafHash);
      const result = await spv.verifyMakerTxProof(leaf, proof);
      expect(result).true;
    });
    it('Contract VerifyProof non-existent', async () => {
      const { hex: leafHash, leaf }: any = getLeaf(MakerTxList[0]);
      leaf.chain = '2';
      const proof = makerTxTree.getHexProof(leafHash);
      const result = await spv.verifyMakerTxProof(leaf, proof);
      expect(result).false;
    });
  });
});
