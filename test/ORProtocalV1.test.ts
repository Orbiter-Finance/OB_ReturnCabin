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
    expect(await factoryContract.ebc(1)).equal(ebc.address);
    expect(await factoryContract.spv()).equal(spvContract.address);
  });
  it('setAndGetChanllengePledgeAmountCoefficient', async () => {
    const value = ethers.utils.parseEther('0.05');
    await ebc.connect(ebcOwner).setChallengePledgedAmount(value);
    const result = await ebc.challengePledgedAmount();
    expect(result).eq(value);
  });
  it('setAndGetDepositAmountCoefficient', async () => {
    const value = 1000;
    await ebc.connect(ebcOwner).setPledgeAmountSafeRate(value);
    const result = await ebc.getPledgeAmountSafeRate();
    console.log(result, 'rate');
    const batchLimit = ethers.BigNumber.from(100),
      maxPrice = ethers.BigNumber.from('100000000000000000');
    const pledgeAmount = await ebc.getPledgeAmount(batchLimit, maxPrice);
    expect(pledgeAmount.baseValue.add(pledgeAmount.additiveValue)).eq(
      ethers.BigNumber.from('11000000000000000000'),
    );
  });
  it('setAndGetETHPunishCoefficient', async () => {
    const value = 100;
    await ebc.connect(ebcOwner).setMainCoinPunishRate(value);
    const result = await ebc.mainCoinPunishRate();
    expect(result).eq(value);
  });
  it('setAndGetTokenPunishCoefficient', async () => {
    const value = 100;
    await ebc.connect(ebcOwner).setTokenPunishRate(value);
    const result = await ebc.tokenPunishRate();
    expect(result).eq(value);
  });
  it('getETHPunish', async () => {
    const value = USER_TX_LIST[0].value;
    const response = await ebc.calculateCompensation(
      USER_TX_LIST[0].token,
      value,
    );
    expect(response.baseValue.add(response.additiveValue)).gt(
      ethers.BigNumber.from(value),
    );
  });
  it('getTokenPunish', async () => {
    const value = USER_TX_LIST[0].value;
    const response = await ebc.calculateCompensation(
      '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
      value,
    );
    expect(response.baseValue.add(response.additiveValue)).gt(
      ethers.BigNumber.from(value),
    );
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
