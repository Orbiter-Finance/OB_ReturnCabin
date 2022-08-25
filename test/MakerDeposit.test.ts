import { ethers } from 'hardhat';
import { ORMakerDeposit } from '../typechain-types/contracts/ORMakerDeposit';
import { getLpID } from './lib/PairManager';
import { MerkleTree } from 'merkletreejs';
import { pairList, lpInfoList } from './lib/Config';
let mdc: ORMakerDeposit;
let supportPairTree: MerkleTree;
const { keccak256 } = ethers.utils;
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    const mdcContractAddress =
      process.env['MDC'] || '0xc8b335273449ec29644c5433cec7383ca4d2ea62';
    const [owner] = await ethers.getSigners();
    mdc = await ethers.getContractAt(
      'ORMakerDeposit',
      mdcContractAddress,
      owner,
    );
    console.log('MDC Address：', mdc.address);
    // tree
    supportPairTree = new MerkleTree(pairList.map(getLpID), keccak256, {
      sort: true,
    });
  }

  before(getFactoryInfo);

  it('LPAction', async () => {
    const lpInfo = lpInfoList[0];
    console.log(lpInfo);
    const lpId = getLpID(lpInfo);
    const proof = supportPairTree.getHexProof(lpId);
    const overrides = {
      value: ethers.utils.parseEther('1.0'),
    };
    const response = await mdc.LPAction(
      <any>lpInfo,
      proof,
      supportPairTree.getHexRoot(),
      overrides,
    );
    console.log(response, '==response');
  });
});
