import { IProventh } from './../typechain-types/contracts/interface/IProventh';
import { ethers } from 'hardhat';
import { chains, pairs } from './goerli.data.json';
import { printContract, deploy } from '../scripts/utils';
import txList from './tx.json';
const ProventhAbi = require('./Proventh.abi.json');
import 'cross-fetch/polyfill';
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
    let makerImplementationAddr = process.env['makerImplementation'];
    if (!makerImplementationAddr) {
      const contract = await ethers.getContractFactory('ORMakerDeposit');
      const makerImplementation = await contract.deploy();
      await makerImplementation.deployed();
      makerImplementationAddr = makerImplementation.address.toString();
    }
    const contract = await deploy<ORMakerV1Factory>(
      true,
      name,
      managerContract.address,
      100,
      makerImplementationAddr,
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
export async function getORSPVContract(): Promise<IProventh> {
  const name = 'IProventh';
  const contractAddress = '0x8aECd2db4cd8b675375ec3aEB81B8BBa49652092';
  const provider = new ethers.providers.JsonRpcProvider(
    'http://ec2-35-73-236-198.ap-northeast-1.compute.amazonaws.com:3002',
  );
  const contract = new ethers.Contract(contractAddress, ProventhAbi, provider);
  printContract(`load ${name} contract:`, contract.address.toString());
  process.env[name] = contract.address;
  return contract as any;
}

export async function getORProtocalV1Contract(): Promise<ORProtocalV1> {
  let managerContractAddress = process.env['ORManager'];
  if (!managerContractAddress) {
    const managerContract = await getManagerContract();
    managerContractAddress = managerContract.address;
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
export const getTxLeaf = (tx: any) => {
  console.log(tx, '===getTxLeaf');
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

  const ebc = tx.ebc;
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
      'address',
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
      ebc,
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
    ebc,
  };
  return { hex, leaf };
};

export class DataInit {
  public static chains: Array<any> = [];
  public static pairs: Array<any> = [];
  public static lps: Array<any> = [];
  public static userTxList: Array<any> = [];
  public static makerTxList: Array<any> = [];
  static async init() {
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
  static getChain(chainId: number) {
    return DataInit.chains.find((row) => row.chainID == chainId);
  }
  static getChainToken(chainId: number, token: string) {
    const chain = DataInit.getChain(chainId);
    if (!chain) {
      throw new Error(`${chainId} chain not found`);
    }
    return chain.tokenList.find((t) => t.address == token);
  }
  static initChains() {
    DataInit.chains = chains;
    return this;
  }
  static initPairs() {
    DataInit.pairs = pairs.map((pair: any) => {
      pair.ebc = process.env['ORProtocalV1'];
      const pairId = solidityKeccak256(
        ['uint256', 'uint256', 'address', 'address', 'address'],
        [
          pair.sourceChain,
          pair.destChain,
          pair.sourceToken,
          pair.destToken,
          pair.ebc,
        ],
      );
      pair.id = pairId;
      return pair;
    });
    return this;
  }
  static initLps(makerPool?: string) {
    makerPool = makerPool || process.env['MAKER:POOL'];
    DataInit.lps = DataInit.pairs.map((pair: any) => {
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
      lp.id = lpId;
      return lp;
    });
    return this;
  }
  static initUserTxList(makerAddress?: string, userAddress?: string) {
    DataInit.userTxList = txList;
    return this;
  }
  static initMakerTxList(makerAddress?: string, userAddress?: string) {
    // DataInit.makerTxList = makerListData.map((row) => {
    //   row.from = String(makerAddress);
    //   row.to = String(userAddress);
    //   row.ebc = process.env['ORProtocalV1'] || '';
    //   return row;
    // });
    // return this;
  }
}
export async function getSPVProof(
  chainId: string,
  l1Hash: string,
  l2Hash?: string,
) {
  let api =
    'http://ec2-35-73-236-198.ap-northeast-1.compute.amazonaws.com:3000/proof/getProof';
  if (l2Hash) {
    api = `${api}?ChainID=${chainId}&L1SubmissionHash=${l1Hash}&L2Hash=${l2Hash}`;
  } else {
    api = `${api}?ChainID=${chainId}&L1SubmissionHash=${l1Hash}`;
  }
  console.log(api, '===api');
  const { code, data } = await fetch(api).then((res) => res.json());
  if (code === 200) {
    const { txInfo, proof, blockInfo, sequence, txTransaction } = data;
    const txInfoBytes = txInfo.map((tx) => Buffer.from(tx, 'base64'));
    const blockInfoBytes = blockInfo.map((item) => Buffer.from(item, 'base64'));
    const proofBytes = proof.map((row) => {
      return row.map((item) => {
        return Buffer.from(item, 'base64');
      });
    });
    return {
      txInfoBytes,
      blockInfoBytes,
      proofBytes,
      sequenceBytes: Buffer.from(sequence, 'base64'),
    };
  }
  return undefined;
}
