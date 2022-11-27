import { ORSpv } from './../typechain-types/contracts/ORSpv';
import { ethers } from 'hardhat';
import { chains, pairs } from './georli.data.json';
import { printContract, deploy } from '../scripts/utils';
import userListData from '././userTx.data.json';
import makerListData from '././makerTx.data.json';
import {
  ORMakerDeposit,
  ORMakerV1Factory,
  ORManager,
  ORProtocalV1,
} from '../typechain-types';
import { solidityKeccak256 } from 'ethers/lib/utils';

export async function getORMakerDepositContract(): Promise<ORMakerDeposit> {
  const name = 'ORMakerDeposit';
  const contractAddress = process.env['MAKER:POOL'];
  if (!contractAddress) {
    throw new Error('MAKER:POOL Not Found ');
  }
  const contract = await ethers.getContractAt(name, contractAddress);
  printContract(`load ${name} contract:`, contract.address.toString());
  return contract;
}

export async function getORMakerV1FactoryContract(): Promise<ORMakerV1Factory> {
  const managerContract = await getManagerContract();
  const name = 'ORMakerV1Factory';
  const contractAddress = process.env['ORMakerV1Factory'];
  if (contractAddress) {
    const contract = await ethers.getContractAt(name, contractAddress);
    printContract(`load ${name} contract:`, contract.address.toString());
    return contract;
  } else {
    const contract = await deploy<ORMakerV1Factory>(
      true,
      name,
      managerContract.address,
      100,
    );
    process.env[name] = contract.address;
    return contract;
  }
}

export async function getManagerContract(): Promise<ORManager> {
  const name = 'ORManager';
  const contractAddress = process.env[name];
  if (contractAddress) {
    const contract = await ethers.getContractAt(name, contractAddress);
    printContract(`load ${name} contract:`, contract.address.toString());
    return contract;
  } else {
    const contract = await deploy<ORManager>(true, name);
    process.env[name] = contract.address;
    return contract;
  }
}
export async function getORSPVContract(): Promise<ORSpv> {
  const name = 'ORSpv';
  const contractAddress = process.env[name];
  if (contractAddress) {
    const contract = await ethers.getContractAt(name, contractAddress);
    printContract(`load ${name} contract:`, contract.address.toString());
    return contract;
  } else {
    const contract = await deploy<ORSpv>(true, name);
    process.env[name] = contract.address;
    return contract;
  }
}

export async function getORProtocalV1Contract(): Promise<ORProtocalV1> {
  const managerContractAddress = process.env['ORManager'];
  if (!managerContractAddress) {
    throw new Error('Not Find managerContractAddress');
  }
  const name = 'ORProtocalV1';
  const contractAddress = process.env[name];
  if (contractAddress) {
    const contract = await ethers.getContractAt(name, contractAddress);
    printContract(`load ${name} contract:`, contract.address.toString());
    return contract;
  } else {
    const contract = await deploy<ORProtocalV1>(
      true,
      name,
      managerContractAddress,
      ethers.utils.parseEther('0.05'),
      10 * 100,
      10 * 100,
      10 * 100,
    );
    process.env[name] = contract.address;
    return contract;
  }
}

export async function getMakerAccount() {
  const [_, makerAccount] = await ethers.getSigners();
  return makerAccount;
}
export async function getUserAccount() {
  const [_, _1, userAccount] = await ethers.getSigners();
  return userAccount;
}
export const getPairID = (pair: any): string => {
  const lpId = solidityKeccak256(
    ['uint256', 'uint256', 'address', 'address', 'uint256'],
    [
      pair.sourceChain,
      pair.destChain,
      pair.sourceTAddress,
      pair.destTAddress,
      pair.ebcid,
    ],
  );
  return lpId;
};
export const getLpId = (makerPool: string, lp: any): string => {
  if (!makerPool || lp.startTime <= 0) {
    return '';
  }
  const lpId = solidityKeccak256(
    ['bytes32', 'address', 'uint256', 'uint256', 'uint256'],
    [
      lp.pairId,
      makerPool,
      ethers.BigNumber.from(lp.startTime),
      ethers.BigNumber.from(lp.minPrice),
      ethers.BigNumber.from(lp.maxPrice),
    ],
  );
  return lpId;
};
export const getTxLeaf = (tx: any) => {
  const lpid = tx.lpid.toLowerCase();
  const txHash = tx.id.toLowerCase();
  const sourceAddress = tx.from.toLowerCase();
  const destAddress = tx.to.toLowerCase();
  const nonce = tx.nonce;
  const amount = tx.value;
  const chainID = tx.chainId || tx.chainID;

  const tokenAddress = tx.token;
  const timestamp = tx.timestamp;
  const responseAmount = tx.responseAmount;
  const responseSafetyCode = tx.responseSafetyCode;
  const ebcid = tx.ebcid;
  const hex = ethers.utils.solidityKeccak256(
    [
      'bytes32',
      'uint256',
      'bytes32',
      'address',
      'address',
      'uint256',
      'uint256',
      'address',
      'uint256',
      'uint256',
      'uint256',
      'uint256',
    ],
    [
      lpid,
      chainID,
      txHash,
      sourceAddress,
      destAddress,
      nonce,
      amount,
      tokenAddress,
      timestamp,
      responseAmount,
      responseSafetyCode,
      ebcid,
    ],
  );
  const leaf = {
    lpid,
    chainID,
    txHash,
    sourceAddress,
    destAddress,
    nonce,
    amount,
    tokenAddress,
    timestamp,
    responseAmount,
    responseSafetyCode,
    ebcid,
  };
  return { hex, leaf };
};

export class DataInit {
  public chains: Array<any> = [];
  public pairs: Array<any> = [];
  public lps: Array<any> = [];
  public userTxList: Array<any> = [];
  public makerTxList: Array<any> = [];
  constructor() {
    return this.initChains()
      .initPairs()
      .initLps()
      .initUserTxList(
        '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
        '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      )
      .initMakerTxList(
        '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
        '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      );
  }
  getChain(chainId: number) {
    return this.chains.find((row) => row.chainID == chainId);
  }
  getChainToken(chainId: number, token: string) {
    const chain = this.getChain(chainId);
    if (!chain) {
      throw new Error(`${chainId} chain not found`);
    }
    return chain.tokenList.find((t) => t.address == token);
  }
  initChains() {
    this.chains = chains;
    return this;
  }
  initPairs() {
    this.pairs = pairs.map((row: any) => {
      row.id = getPairID(row);
      return row;
    });
    return this;
  }
  initLps(makerPool?: string) {
    makerPool = makerPool || process.env['MAKER:POOL'];
    this.lps = this.pairs.map((pair: any) => {
      const lp = {
        id: '',
        pairId: String(pair.id),
        sourcePresion: 18,
        destPresion: 18,
        minPrice: '5000000000000000',
        maxPrice: '9000000000000000',
        gasFee: '10000000000000000',
        tradingFee: '10000000000000000',
        startTime: 0,
        stopTime: 0,
      };
      lp.id = getLpId(String(makerPool), lp);
      return lp;
    });
    return this;
  }
  initUserTxList(makerAddress?: string, userAddress?: string) {
    this.userTxList = userListData.map((row) => {
      row.from = String(userAddress);
      row.to = String(makerAddress);
      return row;
    });
    return this;
  }
  initMakerTxList(makerAddress?: string, userAddress?: string) {
    this.makerTxList = makerListData.map((row) => {
      row.from = String(makerAddress);
      row.to = String(userAddress);
      return row;
    });
    return this;
  }
}
