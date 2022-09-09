/* eslint-disable @typescript-eslint/ban-ts-comment */
import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';
import { ORProtocalV1 } from '../typechain-types';
import { USER_TX_LIST } from './lib/Config';
import { getLeaf } from './lib/Utils';
let ebc: ORProtocalV1;
describe('ORProtocalV1.test.ts', () => {
  async function createEbcInfo() {
    const managerAddress = process.env['factory'] || '';
    const ORProtocalV1 = await ethers.getContractFactory('ORProtocalV1', {
      libraries: {},
    });
    const ORProtocalV1Proxy = await upgrades.deployProxy(ORProtocalV1, [
      managerAddress,
    ]);
    await ORProtocalV1Proxy.deployed();
    ebc = ORProtocalV1Proxy as ORProtocalV1;
  }

  before(createEbcInfo);
  it('Create EBC', async () => {
    console.log('EBC address', ebc.address);
  });
  it('Update EBC and SPV factory', async () => {
    const factoryAddress = process.env['factory'] || '';
    const spvAddress = process.env['SPV'] || '';
    !expect(factoryAddress).not.empty;
    !expect(spvAddress).not.empty;
    const factoryContract = await ethers.getContractAt(
      'ORManager',
      factoryAddress,
    );
    await factoryContract.updateEBC(
      (await factoryContract.getEBCids()).toNumber() - 1,
      ebc.address,
    );
    await factoryContract.setSPV(spvAddress);
    expect(await factoryContract.getEBCids()).equal(1);
    expect(await factoryContract.getEBC(0)).equal(ebc.address);
    expect(await factoryContract.getSPV()).equal(spvAddress);
  });
  it('getETHPunish', async () => {
    const value = USER_TX_LIST[0].value;
    const response = await ebc.getETHPunish(value);
    expect(response).gt(ethers.BigNumber.from(value));
  });
  it('getTokenPunish', async () => {
    const value = USER_TX_LIST[0].value;
    const response = await ebc.getTokenPunish(value);
    expect(response).gt(ethers.BigNumber.from(value));
  });
  it('getRespnseHash', async () => {
    const { leaf } = getLeaf(USER_TX_LIST[0], true);
    const expectResponce = ethers.utils.solidityKeccak256(
      ['bytes32', 'uint256', 'address', 'address', 'uint256', 'address'],
      [
        leaf.lpid,
        ethers.BigNumber.from(leaf.amount)
          .mod(ethers.BigNumber.from(10000))
          .sub(ethers.BigNumber.from(9000)),
        leaf.destAddress,
        leaf.sourceAddress,
        leaf.responseAmount,
        leaf.tokenAddress,
      ],
    );
    const realResponse = await ebc.getRespnseHash(leaf);
    expect(expectResponce).equals(realResponse);
  });
});
