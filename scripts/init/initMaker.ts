import { ethers } from 'hardhat';
import { ORMakerDeposit } from '../../typechain-types';
import { LP_LIST, PAIR_LIST } from '../../test/lib/Config';
import { MerkleTree } from 'merkletreejs';
import keccak256 from 'keccak256';
const leafs = PAIR_LIST.map((row) => {
  return Buffer.from(row.id, 'hex');
});
const pairTree = new MerkleTree(leafs, keccak256, {
  sort: true,
});
async function main() {
  const [ownerAccount, makerAccount] = await ethers.getSigners();
  const makerContractAddr = String(process.env['MDC']);
  const makerDeposit: ORMakerDeposit = await ethers.getContractAt(
    'ORMakerDeposit',
    makerContractAddr,
  );
  const value = ethers.utils.parseEther('2');
  const lpInfos = [LP_LIST[0]].map((row) => {
    const pair = PAIR_LIST.find((p) => p.id === row.pairId);
    return {
      sourceChain: pair?.sourceChain,
      destChain: pair?.destChain,
      sourceTAddress: pair?.sourceTAddress,
      destTAddress: pair?.destTAddress,
      ebcid: pair?.ebcid,
      sourcePresion: row.sourcePresion,
      destPresion: row.destPresion,
      minPrice: row.minPrice,
      maxPrice: row.maxPrice,
      gasFee: row.gasFee,
      tradingFee: row.tradingFee,
      startTime: row.startTime,
    };
  });
  console.log(lpInfos, '==lpInfos');
  const overrides = {
    value,
  };
  const pairProof = [LP_LIST[0]].map((row) => {
    return pairTree.getHexProof(Buffer.from(row.pairId, 'hex'));
  });
  console.log(pairProof, '===pairProof');
  const response = await makerDeposit
    .connect(makerAccount)
    .LPAction(<any>lpInfos, pairProof);
  console.log(response, '==response');
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
