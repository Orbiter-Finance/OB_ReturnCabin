/* eslint-disable @typescript-eslint/ban-ts-comment */
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { loadOrDeployContract } from '../scripts/utils';
import { ORManager, ORProtocalV1 } from '../typechain-types';
import { getORProtocalV1Contract, getORSPVContract } from './index.test';
import USER_TX_LIST from '././userTx.data.json';
import { getTxLeaf } from './index.test';
let ebc: ORProtocalV1;
let ebcOwner: SignerWithAddress;
let managerContractAddress: string;
describe('ORProtocalV1.test.ts', () => {
  async function createEbcInfo() {
    [ebcOwner] = await ethers.getSigners();
    const manager = await loadOrDeployContract<ORManager>('ORManager');
    managerContractAddress = manager.address;
    ebc = await getORProtocalV1Contract();
  }

  before(createEbcInfo);
  it('Update EBC and SPV factory', async () => {
    const spvContract = await getORSPVContract();
    !expect(managerContractAddress).not.empty;
    !expect(spvContract.address).not.empty;
    const factoryContract = await ethers.getContractAt(
      'ORManager',
      managerContractAddress,
    );
    await factoryContract.updateEBC(1, ebc.address);
    await factoryContract.setSPV(spvContract.address);
    expect(await factoryContract.getEBCids()).equal(1);
    expect(await factoryContract.getEBC(1)).equal(ebc.address);
    expect(await factoryContract.getSPV()).equal(spvContract.address);
  });
  it('setAndGetChanllengePledgeAmountCoefficient', async () => {
    const value = ethers.utils.parseEther('0.05');
    await ebc.connect(ebcOwner).setChanllengePledgeAmountCoefficient(value);
    const result = await ebc.getChanllengePledgeAmountCoefficient();
    expect(result).eq(value);
  });
  it('setAndGetDepositAmountCoefficient', async () => {
    const value = 110;
    await ebc.connect(ebcOwner).setDepositAmountCoefficient(value);
    const result = await ebc.getDepositAmountCoefficient();
    expect(result).eq(value);
  });
  it('setAndGetETHPunishCoefficient', async () => {
    const value = 110;
    await ebc.connect(ebcOwner).setETHPunishCoefficient(value);
    const result = await ebc.getETHPunishCoefficient();
    expect(result).eq(value);
  });
  it('setAndGetTokenPunishCoefficient', async () => {
    const value = 110;
    await ebc.connect(ebcOwner).setTokenPunishCoefficient(value);
    const result = await ebc.getTokenPunishCoefficient();
    expect(result).eq(value);
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
    const { leaf } = getTxLeaf(USER_TX_LIST[0]);
    const expectResponce = ethers.utils.solidityKeccak256(
      [
        'bytes32',
        'uint256',
        'address',
        'address',
        'uint256',
        'uint256',
        'address',
      ],
      [
        leaf.lpid,
        ethers.BigNumber.from(leaf.amount)
          .mod(ethers.BigNumber.from(10000))
          .sub(ethers.BigNumber.from(9000)),
        leaf.destAddress,
        leaf.sourceAddress,
        leaf.responseAmount,
        leaf.responseSafetyCode,
        leaf.tokenAddress,
      ],
    );
    const realResponse = await ebc.getRespnseHash(leaf);
    expect(expectResponce).equals(realResponse);
  });
});
