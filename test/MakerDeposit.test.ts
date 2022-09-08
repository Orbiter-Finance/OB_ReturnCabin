/* eslint-disable @typescript-eslint/ban-ts-comment */
import { ethers, web3 } from 'hardhat';
import { ORMakerDeposit } from '../typechain-types';
import { MerkleTree } from 'merkletreejs';
import { LP_LIST, MAKER_TX_LIST, USER_TX_LIST } from './lib/Config';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { PAIR_LIST } from './lib/Config';
import { expect } from 'chai';
import { getPairID, getPairLPID, getLeaf } from './lib/Utils';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
// import { time } from '@openzeppelin/test-helpers';
let mdc: ORMakerDeposit;
let supportPairTree: MerkleTree;
let owner: SignerWithAddress;
let UserTx1Account: SignerWithAddress;
let UserTx3Account: SignerWithAddress;
let lpInfoTree: MerkleTree;
let allPairLeafList: any[] = [];
let userTxTree: MerkleTree;
let makerTxTree: MerkleTree;

const { keccak256 } = ethers.utils;
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    const mdcContractAddress = process.env['MDC'] || '';
    [owner, , UserTx1Account, UserTx3Account] = await ethers.getSigners();
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

    const { tree: tree1 } = generateMerkleTree(USER_TX_LIST, true);
    userTxTree = tree1;
    const { tree: tree2 } = generateMerkleTree(MAKER_TX_LIST, false);
    makerTxTree = tree2;
  }

  before(getFactoryInfo);
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
  function generateMerkleTree(
    txList: Array<typeof USER_TX_LIST[0]>,
    status: boolean,
  ) {
    const leafs = txList.map((tx) => {
      // from , to, value, nonce
      const { hex } = getLeaf(tx, status);
      return hex;
    });
    const tree = new MerkleTree(leafs, keccak256, {
      sort: true,
    });
    return { tree };
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
  it('userChanllenge for maker not send', async () => {
    const { leaf, hex } = getLeaf(USER_TX_LIST[0], true);
    const txProof = userTxTree.getHexProof(hex);
    const overrides = {
      value: ethers.utils.parseEther('1'),
    };
    const response = await mdc
      .connect(UserTx1Account)
      .userChanllenge(leaf, txProof, overrides);
    await expect(response)
      .to.emit(mdc, 'LogChanllengeInfo')
      .withArgs(anyValue, 0);
  });
  it('userChanllenge for maker already send', async () => {
    // User
    const { leaf: userLeaf, hex: userHex } = getLeaf(USER_TX_LIST[4], true);
    const userProof = userTxTree.getHexProof(userHex);
    const overrides = {
      value: ethers.utils.parseEther('1'),
    };
    const userResponse = await mdc
      .connect(UserTx3Account)
      .userChanllenge(userLeaf, userProof, overrides);
    await expect(userResponse)
      .to.emit(mdc, 'LogChanllengeInfo')
      .withArgs(anyValue, 0);
    // Maker
    const { leaf: makerLeaf, hex: makerHex } = getLeaf(MAKER_TX_LIST[2], false);
    const makerProof = makerTxTree.getHexProof(makerHex);
    const makerResponce = await mdc.makerChanllenger(
      userLeaf,
      makerLeaf,
      makerProof,
    );
    await expect(makerResponce)
      .to.emit(mdc, 'LogChanllengeInfo')
      .withArgs(anyValue, 1);
  });
  // it('test time ', async () => {
  //   let duration = time.duration.seconds(3);
  // });
});
