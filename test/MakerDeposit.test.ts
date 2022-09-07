/* eslint-disable @typescript-eslint/ban-ts-comment */
import { ethers, web3 } from 'hardhat';
import { ORMakerDeposit } from '../typechain-types/contracts/ORMakerDeposit';
import { MerkleTree } from 'merkletreejs';
import { LP_LIST } from './lib/Config';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { PAIR_LIST } from './lib/Config';
import { expect } from 'chai';
import { getPairID, getPairLPID } from './lib/Utils';
let mdc: ORMakerDeposit;
let supportPairTree: MerkleTree;
let owner: SignerWithAddress;
let lpInfoTree: MerkleTree;
let allPairLeafList: any[] = [];
const { keccak256 } = ethers.utils;
const UserTxList = [
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b91',
    id: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b91',
    from: '0x188DD5b655E2fe78f5ede164d37170FB1B941c9e',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '1',
    fee: '46810453281384',
    value: '998798000000009003',
    nonce: 0,
    timestamp: 111111111,
    responseAmount: 10000,
  },
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b94',
    id: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b92',
    from: '0xAec1379dc4BDe48245F75f9726239cEC2E0C8DDa',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    chainId: '1',
    token: '0x0000000000000000000000000000000000000000',
    fee: '46810453281384',
    value: '998798000000009003',
    nonce: 1,
    timestamp: 111111111,
    responseAmount: 10000,
  },
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b93',
    id: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b93',
    from: '0xE879e54Ab4893953773C0b41304A05C2D49cc612',
    chainId: '1',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    fee: '46810453281384',
    value: '998798000000009003',
    nonce: 3,
    timestamp: 111111111,
    responseAmount: 10000,
  },
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b92',
    id: '0xfd123fe2054b7f2140ebc9be98dc8638d17f7eae74887894d220d160dc188c1b',
    from: '0xbf28bce31463a3a023c2c324aecbd5689ffa06ee',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '3',
    fee: '20969931642240',
    value: '276866090070000000',
    nonce: 9,
    timestamp: 111111111,
    responseAmount: 10000,
  },
];
const MakerTxList = [
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b95',
    id: '0x6f1308d493d20956ef2806439e095451ba859c02211b60595d6469858161c9bd',
    from: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    to: '0xbf28bce31463a3a023c2c324aecbd5689ffa06ee',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '7',
    fee: '378000000000000',
    value: '276016000000000009',
    nonce: 62374,
    timestamp: 111111111,
    responseAmount: 10000,
  },

  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b96',
    id: '0xd615805a657aa2fae3172ca6f6fdbd1c0036f29c233eb2a94b408f7ef2b29a02',
    from: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    to: '0xac9facad1c42986520bd7df5ded1d30d94a13095',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '7',
    fee: '378000000000000',
    value: '389667000000000007',
    nonce: 62373,
    timestamp: 111111111,
    responseAmount: 10000,
  },
];
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    const mdcContractAddress = process.env['MDC'] || '';
    [owner] = await ethers.getSigners();
    mdc = await ethers.getContractAt(
      'ORMakerDeposit',
      mdcContractAddress,
      owner,
    );
    console.log('MDC Address:', mdc.address);
    // tree
    allPairLeafList = PAIR_LIST.map((row: any) => {
      row.leaf = Buffer.from(getPairID(row), 'hex');
      return row;
    });
    supportPairTree = new MerkleTree(
      [allPairLeafList[0].leaf, allPairLeafList[1].leaf],
      keccak256,
      {
        sort: true,
      },
    );
    lpInfoTree = new MerkleTree([], keccak256, {
      sort: true,
    });
  }

  before(getFactoryInfo);
  function getLeaf(tx: typeof UserTxList[0]) {
    const lpid = tx.lpid.toLowerCase();
    const txHash = tx.id.toLowerCase();
    const sourceAddress = tx.from.toLowerCase();
    const destAddress = tx.to.toLowerCase();
    const nonce = tx.nonce;
    const amount = tx.value;
    const chainID = tx.chainId;
    const tokenAddress = tx.token;
    const timestamp = tx.timestamp;
    const responseAmount = tx.responseAmount;
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
    };
    return { hex, leaf };
  }
  function getLpInfo(LPLIST: typeof LP_LIST[0]) {
    let lpInfo: any = LPLIST;
    const lpId = getPairLPID(lpInfo);
    const pairInfo = Object.entries(PAIR_LIST).find(
      (item) => item[1].id == lpInfo.pairId,
    );
    if (pairInfo !== undefined) {
      lpInfo = Object.assign(lpInfo, pairInfo[1]);
      lpInfo.id = lpId;
    } else {
      return;
    }
    return lpInfo;
  }
  it('Get MakerFactory', async () => {
    const result = await mdc.makerFactory();
    expect(result).equal(process.env['MDCFactory']);
  });
  it('LPAction Pledge ETH', async () => {
    lpInfoTree.addLeaf(Buffer.from(LP_LIST[0].id, 'hex'));
    lpInfoTree.addLeaf(Buffer.from(LP_LIST[1].id, 'hex'));

    const lpInfo = getLpInfo(LP_LIST[0]);
    const proof = lpInfoTree.getHexProof(lpInfo.id);
    const value = ethers.utils.parseEther('2');
    const pairProofLeavesHash = [PAIR_LIST[0]].map((row) => {
      return Buffer.from(getPairID(row), 'hex');
    });
    const pairProof = pairProofLeavesHash.map((row) => {
      return supportPairTree.getHexProof(row);
    });
    const overrides = {
      value,
    };
    const response = await mdc.LPAction(
      [lpInfo],
      [proof],
      pairProof,
      overrides,
    );
    const tx = await response.wait();
    expect(tx.blockNumber).gt(0);
    if (tx.events !== undefined) {
      expect(tx.events?.findIndex((row) => row.event === 'LogLpInfo') >= 0)
        .true;
    }
    const chainDeposit = await mdc.chainDeposit(
      lpInfo.sourceChain,
      lpInfo.sourceTAddress,
    );
    expect(chainDeposit.useLimit).equal(ethers.BigNumber.from(1));
    expect(chainDeposit.tokenAddress).equal(lpInfo.sourceTAddress);
    console.log(chainDeposit, '==chainDeposit');
    const result2 = await mdc.usedDeposit(owner.address);
    console.log(result2, '==user usedDeposit');
    const contractBalance = await web3.eth.getBalance(mdc.address);
    console.log('contractBalance:', contractBalance);
    expect(chainDeposit.tokenAddress).equal(lpInfo.sourceTAddress);
  });
  it('LPPause', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const proof = lpInfoTree.getHexProof(lpInfo.id);
    const response = await mdc.LPPause([lpInfo], [proof]);
    const tx = await response.wait();
    expect(tx.blockNumber).gt(0);
    if (tx.events !== undefined) {
      expect(tx.events?.findIndex((row) => row.event === 'LogLpInfo') >= 0)
        .true;
    }
  });
  it('LPStop Not Time', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    await expect(mdc.LPStop(lpInfo)).to.be.revertedWith(
      'LPSTOP_LPID_TIMEUNABLE',
    );
  });
  // it('LPWith Draw', async () => {
  //   const { leaf } = getLeaf(UserTxList[0]);
  //   const owner = await mdc.owner();
  //   console.log('owner: ', owner);
  //   const response = await mdc.withDrawAssert(leaf.amount, leaf.tokenAddress);
  //   const tx = await response.wait();
  //   console.log(tx.events);
  // });
  it('userChanllenge for maker not send', async () => {
    const { leaf, hex } = getLeaf(UserTxList[0]);
    const txInfoTree = new MerkleTree([hex], keccak256, {
      sort: true,
    });
    const lpInfo = getLpInfo(LP_LIST[0]);
    const contractLpId = '0x' + String(getPairID(lpInfo));
    const realLpInfo = await mdc.lpInfo(contractLpId);
    const stopTime = ethers.BigNumber.from(realLpInfo.stopTime).toNumber();
    const lpProof = lpInfoTree.getHexProof(lpInfo.id);
    console.log(txInfoTree.toString());
    const txProof = txInfoTree.getHexProof(hex);
    console.log('txProof: ', txProof);
    // const response = await mdc.userChanllenge(lpInfo, stopTime, leaf);
  });
});
