import { ethers } from 'hardhat';
import { ORMakerDeposit } from '../typechain-types/contracts/ORMakerDeposit';

let mdc: ORMakerDeposit;
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
  }

  before(getFactoryInfo);

  it('LPAction', () => {
    console.log('test', mdc.address);
    // mdc.LPAction({});
  });
});
