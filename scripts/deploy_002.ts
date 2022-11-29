import { ethers } from 'hardhat';

async function main() {
  // deploy spv
  // process.env['ORManager'] = '0xd1B009e671B8d3D32b8757B5c9F348209A9193B2';
  // const ORMakerV1Factory = await ethers.getContractAt('ORMakerV1Factory', "0x6F8d7d54d21d4eE8Fc41b2E4c4Cf45007541eF9D");
  const ebc = await ethers.getContractAt(
    'ORProtocalV1',
    '0x98005b14b1787b8708fd6A65Fc0005fAa6bBEBDE',
  );
  const tx = await ebc.setPledgeAmountSafeRate(1 * 100);
  // const tx = await ORMakerV1Factory.setMakerMaxLimit(5);
  await tx.wait();
  console.log(tx);

  // require('./init/initManager');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
