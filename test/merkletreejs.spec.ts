import { ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';
const { keccak256 } = ethers.utils;

const tree = new MerkleTree([1, 5, 4, 2, 3], keccak256, {
  sort: true,
});

console.log('getHexLayers:', tree.getHexLayers());
