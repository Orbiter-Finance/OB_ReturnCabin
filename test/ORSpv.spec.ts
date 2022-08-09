import { expect } from 'chai';
import { ethers } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { ORSpv } from '../typechain-types';
const { keccak256 } = ethers.utils;
const UnreturnedTransactions = [
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
];

describe('SPV Test', function () {
  let spv: ORSpv;
  let tree: MerkleTree;
  let txList: Array<any>;
  async function deploySpvFixture() {
    const SpvLib = await ethers.getContractFactory('SpvLib');
    const spvLib = await SpvLib.deploy();
    const ORSpv = await ethers.getContractFactory('ORSpv', {
      libraries: {
        SpvLib: spvLib.address,
      },
    });
    spv = await ORSpv.deploy();
    const result = generateMerkleTree();
    tree = result.tree;
    txList = UnreturnedTransactions;
    console.log(tree.toString());
  }
  function getLeaf(tx: any) {
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
      // ['uint256', 'bytes32', 'address', 'address', 'uint256', 'uint256'],
      // [chainId, hash, from, to, value, nonce],
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
  function generateMerkleTree() {
    const leafs = UnreturnedTransactions.map((tx) => {
      // from , to, value, nonce
      const { hex } = getLeaf(tx);
      return hex;
    });
    const tree = new MerkleTree(leafs, keccak256, {
      sort: true,
    });
    return { tree };
  }
  before(deploySpvFixture);
  it('SetMerkleRoot', async () => {
    const root = tree.getHexRoot();
    const tx = await spv.setMerkleRoot(1, root);
    expect(tx.blockNumber).gt(0);
  });
  it('Get Root', async () => {
    const root = tree.getHexRoot();
    const chainRoot = await spv.txTree(1);
    expect(chainRoot).equals(root);
  });
  it('Local VerifyProof', () => {
    const root = tree.getHexRoot();
    const { hex: leafHash } = getLeaf(txList[0]);
    const proof = tree.getHexProof(leafHash);
    const result = tree.verify(proof, leafHash, root);
    expect(result).true;
  });
  it('Local VerifyProof non-existent', () => {
    const root = tree.getHexRoot();
    const leaf = 'A';
    const proof = tree.getProof(leaf);
    const result = tree.verify(proof, leaf, root);
    expect(result).false;
  });

  it('Contract VerifyProof', async () => {
    const { hex: leafHash, leaf }: any = getLeaf(txList[0]);
    const proof = tree.getHexProof(leafHash);
    const result = await spv.verifyProof(leaf, proof);
    expect(result).true;
  });
  it('Contract VerifyProof non-existent', async () => {
    const { hex: leafHash, leaf }: any = getLeaf(txList[0]);
    leaf.chain = '2';
    const proof = tree.getHexProof(leafHash);
    const result = await spv.verifyProof(leaf, proof);
    expect(result).false;
  });
});
