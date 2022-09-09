/* eslint-disable @typescript-eslint/ban-ts-comment */
import { ethers, web3 } from 'hardhat';
import { ORMakerDeposit } from '../typechain-types';
import { MerkleTree } from 'merkletreejs';
import { LP_LIST, MAKER_TX_LIST, TOKEN_LIST, USER_TX_LIST } from './lib/Config';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { PAIR_LIST } from './lib/Config';
import { expect } from 'chai';
import { getPairID, getPairLPID, getLeaf } from './lib/Utils';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
let mdc: ORMakerDeposit;
let supportPairTree: MerkleTree;
let owner: SignerWithAddress;
let maker: SignerWithAddress;
let UserTx1Account: SignerWithAddress;
let UserTx3Account: SignerWithAddress;
let lpInfoTree: MerkleTree;
let allPairLeafList: any[] = [];
let userTxTree: MerkleTree;
let makerTxTree: MerkleTree;

const { keccak256 } = ethers.utils;
const tokeninfo_eth_main = TOKEN_LIST[0];
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    const mdcContractAddress = process.env['MDC'] || '';
    [owner, maker, UserTx1Account, UserTx3Account] = await ethers.getSigners();
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
      [allPairLeafList[0].leaf, allPairLeafList[2].leaf],
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
  async function speedUpTime(ms: number) {
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    console.log('timestampBefore: ', timestampBefore);
    await ethers.provider.send('evm_mine', [timestampBefore + ms]);
    const blockNumAfter = await ethers.provider.getBlockNumber();
    const blockAfter = await ethers.provider.getBlock(blockNumAfter);
    const timestampAfter = blockAfter.timestamp;
    console.log('timestampAfter: ', timestampAfter);
  }
  it('Get MakerFactory', async () => {
    const result = await mdc.makerFactory();
    expect(result).equal(process.env['MDCFactory']);
  });
  it('LPAction pledge ETH', async () => {
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
    const response = await mdc
      .connect(maker)
      .LPAction([lpInfo], [proof], pairProof, overrides);
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
    const contractBalance = await web3.eth.getBalance(mdc.address);
    console.log('contractBalance: ', contractBalance);
    expect(chainDeposit.tokenAddress).equal(lpInfo.sourceTAddress);
  });
  it('LPPause', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const proof = lpInfoTree.getHexProof(lpInfo.id);
    const response = await mdc.connect(maker).LPPause([lpInfo], [proof]);
    const tx = await response.wait();
    expect(tx.blockNumber).gt(0);
    if (tx.events !== undefined) {
      expect(tx.events?.findIndex((row) => row.event === 'LogLpInfo') >= 0)
        .true;
    }
  });
  it('LPStop not time', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const response = mdc.connect(maker).LPStop(lpInfo);
    await expect(response).to.be.revertedWith('LPSTOP_LPID_TIMEUNABLE');
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('LPStop is time', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const response = await mdc.connect(maker).LPStop(lpInfo);
    const tx = await response.wait();
    expect(tx.blockNumber).gt(0);
    if (tx.events !== undefined) {
      expect(tx.events?.findIndex((row) => row.event === 'LogLpInfo') >= 0)
        .true;
    }
  });
  it('Maker withDraw is time and no chanllenge', async () => {
    const beforeAmount = await maker.getBalance();
    const withDrawMax = await mdc
      .connect(maker)
      .idleAmount(tokeninfo_eth_main.mainAddress);
    const response = await mdc
      .connect(maker)
      .withDrawAssert(withDrawMax, tokeninfo_eth_main.mainAddress);
    const tx = await response.wait();
    const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    const afterAmount = await maker.getBalance();
    const nowWithDraw = await mdc
      .connect(maker)
      .idleAmount(tokeninfo_eth_main.mainAddress);
    expect(beforeAmount.add(withDrawMax).sub(gasUsed)).eq(afterAmount);
    expect(nowWithDraw).eq(0);
  });
  it('LPAction again', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const proof = lpInfoTree.getHexProof(lpInfo.id);
    const value = ethers.utils.parseEther('1.2');
    const pairProofLeavesHash = [PAIR_LIST[0]].map((row) => {
      return Buffer.from(getPairID(row), 'hex');
    });
    const pairProof = pairProofLeavesHash.map((row) => {
      return supportPairTree.getHexProof(row);
    });
    const overrides = {
      value,
    };
    const response = await mdc
      .connect(maker)
      .LPAction([lpInfo], [proof], pairProof, overrides);
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
    const contractBalance = await web3.eth.getBalance(mdc.address);
    console.log('contractBalance: ', contractBalance);
    expect(chainDeposit.tokenAddress).equal(lpInfo.sourceTAddress);
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
    const makerResponce = await mdc
      .connect(maker)
      .makerChanllenger(userLeaf, makerLeaf, makerProof);
    await expect(makerResponce)
      .to.emit(mdc, 'LogChanllengeInfo')
      .withArgs(anyValue, 1);
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('User Withdrawal under successful UserChallenge', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const { leaf: userLeaf } = getLeaf(USER_TX_LIST[0], true);
    const beforeAmount = await UserTx1Account.getBalance();
    const response = await mdc
      .connect(UserTx1Account)
      .userWithDraw(userLeaf, lpInfo);
    const tx = await response.wait();
    const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    const pledgeAmount = ethers.utils.parseEther('1');
    const ETHPunishAmount = ethers.BigNumber.from(userLeaf.amount)
      .sub(
        ethers.BigNumber.from(userLeaf.amount)
          .mod(ethers.BigNumber.from(10000))
          .sub(ethers.BigNumber.from(9000)),
      )
      .mul(ethers.BigNumber.from(11))
      .div(ethers.BigNumber.from(10));
    const realAfterAmount = await UserTx1Account.getBalance();
    const expectAfterAmount = beforeAmount
      .add(pledgeAmount)
      .add(ETHPunishAmount)
      .sub(gasUsed);
    expect(realAfterAmount).eq(expectAfterAmount);
  });
  it('User Withdrawal in failure of UserChallenge', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const { leaf: userLeaf } = getLeaf(USER_TX_LIST[4], true);
    const response = mdc.connect(UserTx3Account).userWithDraw(userLeaf, lpInfo);
    await expect(response).to.be.revertedWith('UW_WITHDRAW');
  });
  it('Maker withDraw in time', async () => {
    const beforeAmount = await maker.getBalance();
    const withDrawMax = await mdc
      .connect(maker)
      .idleAmount(tokeninfo_eth_main.mainAddress);
    const response = await mdc
      .connect(maker)
      .withDrawAssert(withDrawMax, tokeninfo_eth_main.mainAddress);
    const tx = await response.wait();
    const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    const afterAmount = await maker.getBalance();
    const nowWithDraw = await mdc
      .connect(maker)
      .idleAmount(tokeninfo_eth_main.mainAddress);
    expect(beforeAmount.add(withDrawMax).sub(gasUsed)).eq(afterAmount);
    expect(nowWithDraw).eq(0);
  });
});
