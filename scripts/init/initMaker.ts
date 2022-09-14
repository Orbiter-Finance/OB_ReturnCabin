import { ethers } from 'hardhat';
import { ORMakerDeposit } from '../../typechain-types';
import { LP_LIST } from '../../test/lib/Config';
import keccak256 from 'keccak256';
import { MerkleTree } from 'merkletreejs';
const lpTree = new MerkleTree([], keccak256, {
  sort: true,
});
async function main() {
  const [ownerAccount, makerAccount] = await ethers.getSigners();
  const makerDeposit: ORMakerDeposit = await ethers.getContractAt(
    'ORMakerDeposit',
    String(process.env['MDC']),
  );
  const lpInfos = [LP_LIST[0]];
  console.log(lpInfos, '==lpInfos');
  // const proof = lpTree.getProof(lpInfos.map)
  // const response = await makerDeposit
  //   .connect(makerAccount)
  //   .LPAction(lpInfos, [proof], pairProof, overrides);
  // const tx = await response.wait();
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
