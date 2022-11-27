import { expect } from 'chai';
import { ethers } from 'hardhat';
import { getORMakerV1FactoryContract } from './index.test';
describe('MakerV1Factory', () => {
  it('Get Factory V1', async () => {
    const contract = await getORMakerV1FactoryContract();
    expect(contract).not.empty;
  });

  it('Veify Contract is Owner', async () => {
    const [owner] = await ethers.getSigners();
    const contract = await getORMakerV1FactoryContract();
    expect(await contract.owner()).equal(owner.address);
    // const tx = await contract.setManager(.address);
    // expect(tx.blockNumber).gt(0);
  });
  it('Veify Contract transferOwnership Owner', async () => {
    const [owner, account2] = await ethers.getSigners();
    const contract = await getORMakerV1FactoryContract();
    await contract.transferOwnership(account2.address);
    expect(await contract.owner()).equal(account2.address);
    // rollback
    await contract.connect(account2).transferOwnership(owner.address);
    expect(await contract.owner()).equal(owner.address);
  });
  it('SetManager', async () => {
    const contract = await getORMakerV1FactoryContract();
    const oldManagerAddress = await contract.manager();
    await contract.setManager('0x0000000000000000000000000000000000000001');
    expect(await contract.manager()).equal(
      '0x0000000000000000000000000000000000000001',
    );
    await contract.setManager(oldManagerAddress);
    expect(await contract.manager()).equal(oldManagerAddress);
  });
  it('Set setMakerLimit', async () => {
    const maxLimit = 4;
    const contract = await getORMakerV1FactoryContract();
    await contract.setMakerMaxLimit(maxLimit);
    const result = await contract.makerMaxLimit();
    expect(result).eq(maxLimit);
  });
  it('Create Maker', async () => {
    // create mdc
    const [_, makerAccount] = await ethers.getSigners();
    const contract = await getORMakerV1FactoryContract();
    const response = await contract.connect(makerAccount).createMaker();
    const tx = await response.wait();
    const makerMapEvent = tx.events?.find((row) => row.event == 'MakerCreated');
    if (makerMapEvent && makerMapEvent.args) {
      process.env['MDC'] = makerMapEvent.args[1].toLowerCase();
      process.env['MAKER:POOL'] = makerMapEvent.args[1].toLowerCase();
      process.env['MAKER:OWNER'] = makerAccount.address;
      process.env['ORMakerDeposit'] = makerMapEvent.args[1].toLowerCase();
    }
  });
});
