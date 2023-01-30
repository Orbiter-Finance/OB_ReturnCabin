import { DataInit, getORSPVContract } from './utils.test';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import {
  getManagerContract,
  getORMakerV1FactoryContract,
  getORProtocalV1Contract,
} from './utils.test';
import { printAddress } from '../scripts/utils';
describe('init.test.ts', () => {
  it('Create EBC', async () => {
    await getORProtocalV1Contract();
    expect(process.env['ORProtocalV1']).not.empty;
  });
  it('Create Manager', async () => {
    await getManagerContract();
    expect(process.env['ORManager']).not.empty;
  });
  it('Create Manager Factory', async () => {
    await getORMakerV1FactoryContract();
    expect(process.env['ORMakerV1Factory']).not.empty;
  });
  it('Create SPV', async () => {
    await getORSPVContract();
    expect(process.env['IProventh']).not.empty;
  });

  it('Create Maker', async () => {
    const [_, makerAccount] = await ethers.getSigners();
    const contract = await getORMakerV1FactoryContract();
    const response = await contract.connect(makerAccount).createMaker();
    const tx = await response.wait();
    const makerMapEvent = tx.events?.find((row) => row.event == 'MakerCreated');
    if (makerMapEvent && makerMapEvent.args) {
      process.env['MAKER:POOL'] = makerMapEvent.args[1].toLowerCase();
      process.env['MAKER:OWNER'] = makerAccount.address;
      process.env['ORMakerDeposit'] = makerMapEvent.args[1].toLowerCase();
      printAddress('First Maker Pool:', process.env['MAKER:POOL']);
    }
  });
  it('init Data', async () => {
    await DataInit.init();
  });
});
