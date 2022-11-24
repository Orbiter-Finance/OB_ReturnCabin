/* eslint-disable @typescript-eslint/ban-ts-comment */
import { ethers } from 'hardhat';
import { ORMakerDeposit, ORMakerV1Factory } from '../typechain-types';
import { MerkleTree } from 'merkletreejs';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { getTxLeaf } from './index.test';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import {
  DataInit,
  getORMakerDepositContract,
  getORMakerV1FactoryContract,
  getUserAccount,
} from './index.test';
import { getPairTree } from './ORManager.test';
import { BigNumber } from 'ethers';
import { getMakerTxTree, getUserTxTree } from './ORSpv.spec';
const dataInit = new DataInit();
const USER_TX_LIST = dataInit.userTxList;
const MAKER_TX_LIST = dataInit.makerTxList;
let supportPairTree: MerkleTree;
let owner: SignerWithAddress;
let makerAccount: SignerWithAddress;
let UserTx1Account: SignerWithAddress;
let UserTx3Account: SignerWithAddress;
let lpInfoTree: MerkleTree;
let userTxTree: MerkleTree;
let makerTxTree: MerkleTree;
const { keccak256 } = ethers.utils;
let makerDeposit: ORMakerDeposit;
let makerV1Factory: ORMakerV1Factory;
let testLPList: Array<any> = [];
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    // init lp list
    makerDeposit = await getORMakerDepositContract();
    dataInit.initLps(makerDeposit.address);
    testLPList = dataInit.lps.map((row) => {
      const pair = dataInit.pairs.find((p) => p.id === row.pairId);
      row.sourceChain = pair.sourceChain;
      row.destChain = pair.destChain;
      row.sourceTAddress = pair.sourceTAddress;
      row.destTAddress = pair.destTAddress;
      row.ebcid = pair.ebcid;
      return row;
    });
    makerV1Factory = await getORMakerV1FactoryContract();
    [owner, makerAccount, UserTx1Account, UserTx3Account] =
      await ethers.getSigners();
    // tree
    const result = getPairTree();
    supportPairTree = result.tree;
    lpInfoTree = new MerkleTree([], keccak256, {
      sort: true,
    });
    userTxTree = getUserTxTree(USER_TX_LIST);
    makerTxTree = getMakerTxTree(MAKER_TX_LIST);
  }

  before(getFactoryInfo);
  // function getLpInfo(LPLIST: typeof LP_LIST[0]): typeof LP_LIST[0] {
  //   let lpInfo: any = LPLIST;
  //   const lpId = getPairLPID(lpInfo);
  //   const pairInfo = PAIR_LIST.find((item) => item.id == lpInfo.pairId);
  //   if (pairInfo !== undefined) {
  //     lpInfo = Object.assign(lpInfo, pairInfo);
  //     lpInfo.id = lpId;
  //   }
  //   return lpInfo;
  // }
  async function speedUpTime(ms: number) {
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    await ethers.provider.send('evm_mine', [timestampBefore + ms]);
  }
  it('Get MakerFactory', async () => {
    const result = await makerDeposit.makerFactory();
    expect(result).equal(makerV1Factory.address);
  });
  it('Calculation of pledge quantity', async () => {
    const contract = await getORMakerDepositContract();
    const { lps } = new DataInit().initLps(contract.address);
    const data = lps.map((lp: any) => {
      lp.sourceChain = 5;
      lp.destChain = 33;
      lp.sourceTAddress = '0x0000000000000000000000000000000000000000';
      lp.destTAddress = '0x0000000000000000000000000000000000000000';
      lp.ebcid = 1;
      return lp;
    });
    const amount = await contract.calcLpNeedPledgeAmount(lps);
    console.log(amount, '===amount');
  });
  it('LPAction pledge ETH', async () => {
    const addLpInfo = testLPList[0];
    const addPair = dataInit.pairs.find((row) => row.id == addLpInfo.pairId);
    const pairProof = supportPairTree.getHexProof(addPair.id);
    const overrides = {
      value: ethers.utils.parseEther('2'),
    };
    const response = await makerDeposit
      .connect(makerAccount)
      .LPAction([addLpInfo], [pairProof], overrides);
    await expect(response)
      .to.emit(makerDeposit, 'LogLpAction')
      .withArgs(anyValue, anyValue, anyValue);
    const { events } = await response.wait();
    const LogLpInfo: any = events?.find((ev) => ev.event == 'LogLpAction');
    if (LogLpInfo) {
      const args = LogLpInfo.args[2];
      const lpId = LogLpInfo.args[1];
      addLpInfo.id = lpId;
      addLpInfo.startTime = Number(args.startTime);
    }
    const chainDeposit = await makerDeposit.chainDeposit(
      addLpInfo.sourceChain,
      addLpInfo.sourceTAddress,
    );
    const contractBalance = await ethers.provider.getBalance(
      makerDeposit.address,
      'latest',
    );
    expect(contractBalance).equal(ethers.BigNumber.from(overrides.value));
    expect(chainDeposit.useLimit).equal(ethers.BigNumber.from(1));
    expect(chainDeposit.tokenAddress).equal(addLpInfo.sourceTAddress);
  });
  it('LPPause', async () => {
    const pauseLpInfo = testLPList[0];
    const response = await makerDeposit
      .connect(makerAccount)
      .LPPause([pauseLpInfo]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLPPause')
      .withArgs(anyValue, anyValue, anyValue);
  });
  it('LPUpdate', async () => {
    const changeLpInfo = testLPList[0];
    const updateData = {
      tradingFee: BigNumber.from(0.0005 * 10 ** 18),
      gasFee: changeLpInfo.gasFee,
    };
    const response = await makerDeposit.connect(makerAccount).LPUpdate([
      {
        pid: changeLpInfo.pairId,
        lpid: changeLpInfo.id,
        ...updateData,
      },
    ]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLpUpdate')
      .withArgs(
        changeLpInfo.pairId,
        changeLpInfo.id,
        updateData.gasFee,
        updateData.tradingFee,
      );
  });
  it('LPRestart', async () => {
    const restartLpInfo = testLPList[0];
    const response = await makerDeposit
      .connect(makerAccount)
      .LPRestart([{ pid: restartLpInfo.pairId, lpid: restartLpInfo.id }]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLpRestart')
      .withArgs(restartLpInfo.pairId, restartLpInfo.id);
  });
  it('LPRestart After Pause', async () => {
    const restartLpInfo = testLPList[0];
    const response = await makerDeposit
      .connect(makerAccount)
      .LPPause([restartLpInfo]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLPPause')
      .withArgs(anyValue, anyValue, anyValue);
  });
  it('LPStop not time', async () => {
    const lpInfo = testLPList[0];
    const response = makerDeposit.connect(makerAccount).LPStop([lpInfo]);
    await expect(response).to.be.revertedWith('LPSTOP_LPID_TIMEUNABLE');
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('LPStop is time', async () => {
    const lpInfo = testLPList[0];
    const response = await makerDeposit.connect(makerAccount).LPStop([lpInfo]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLPStop')
      .withArgs(anyValue, anyValue, anyValue);
  });
  it('Maker withDraw is time and no chanllenge', async () => {
    const lpInfo = testLPList[0];
    const chain = dataInit.chains.find(
      (row) => row.chainID === lpInfo['sourceChain'],
    );
    expect(chain.chainID).eq(lpInfo.sourceChain);
    expect(chain.tokenList).length.gt(0);
    const token = chain.tokenList.find(
      (t) => t.address === lpInfo.sourceTAddress,
    );
    expect(token).not.empty;
    const beforeAmount = await makerAccount.getBalance();
    const withDrawMax = await makerDeposit
      .connect(makerAccount)
      .idleAmount(token.pledgeToken);
    const response = await makerDeposit
      .connect(makerAccount)
      .withDrawAssert(withDrawMax, token.pledgeToken);
    const tx = await response.wait();
    const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    const afterAmount = await makerAccount.getBalance();
    const nowWithDraw = await makerDeposit
      .connect(makerAccount)
      .idleAmount(token.pledgeToken);
    expect(beforeAmount.add(withDrawMax).sub(gasUsed)).eq(afterAmount);
    expect(nowWithDraw).eq(0);
  });
  it('LPAction pledge ETH(again)', async () => {
    const addLpInfo = testLPList[0];
    const addPair = dataInit.pairs.find((row) => row.id == addLpInfo.pairId);
    const pairProof = supportPairTree.getHexProof(addPair.id);
    const overrides = {
      value: ethers.utils.parseEther('2.1'),
    };
    const response = await makerDeposit
      .connect(makerAccount)
      .LPAction([addLpInfo], [pairProof], overrides);
    await expect(response)
      .to.emit(makerDeposit, 'LogLpAction')
      .withArgs(anyValue, anyValue, anyValue);
    const { events } = await response.wait();
    const LogLpInfo: any = events?.find((ev) => ev.event == 'LogLpAction');
    if (LogLpInfo) {
      const args = LogLpInfo.args[2];
      const lpId = LogLpInfo.args[1];
      addLpInfo.id = lpId;
      addLpInfo.startTime = Number(args.startTime);
    }
    const chainDeposit = await makerDeposit.chainDeposit(
      addLpInfo.sourceChain,
      addLpInfo.sourceTAddress,
    );
    const contractBalance = await ethers.provider.getBalance(
      makerDeposit.address,
      'latest',
    );
    expect(contractBalance).equal(ethers.BigNumber.from(overrides.value));
    expect(chainDeposit.useLimit).equal(ethers.BigNumber.from(1));
    expect(chainDeposit.tokenAddress).equal(addLpInfo.sourceTAddress);
  });
  it('userChanllenge for maker not send', async () => {
    const { leaf, hex } = getTxLeaf(USER_TX_LIST[0], true);
    const txProof = userTxTree.getHexProof(hex);
    const overrides = {
      value: ethers.utils.parseEther('1'),
    };
    const response = await makerDeposit
      .connect(UserTx1Account)
      .userChanllenge(leaf, txProof, overrides);
    await expect(response)
      .to.emit(makerDeposit, 'LogChanllengeInfo')
      .withArgs(anyValue, 0, anyValue, anyValue, anyValue);
  });
  it('userChanllenge for maker already send', async () => {
    // User
    const { leaf: userLeaf, hex: userHex } = getTxLeaf(USER_TX_LIST[4], true);
    const userProof = userTxTree.getHexProof(userHex);
    const overrides = {
      value: ethers.utils.parseEther('1'),
    };
    const userResponse = await makerDeposit
      .connect(UserTx1Account)
      .userChanllenge(userLeaf, userProof, overrides);
    await expect(userResponse)
      .to.emit(makerDeposit, 'LogChanllengeInfo')
      .withArgs(anyValue, 0, anyValue, anyValue, anyValue);
    // Maker
    const { leaf: makerLeaf, hex: makerHex } = getTxLeaf(
      MAKER_TX_LIST[2],
      false,
    );
    const makerProof = makerTxTree.getHexProof(makerHex);

    const makerResponce = await makerDeposit
      .connect(makerAccount)
      .makerChanllenger(userLeaf, makerLeaf, makerProof);
    await expect(makerResponce)
      .to.emit(makerDeposit, 'LogChanllengeInfo')
      .withArgs(anyValue, 1, anyValue, anyValue, anyValue);
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('User Withdrawal under successful UserChallenge', async () => {
    const lpInfo = dataInit.lps[0];
    const { leaf: userLeaf } = getTxLeaf(USER_TX_LIST[0]);
    const beforeAmount = await UserTx1Account.getBalance();
    const response = await makerDeposit
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
    const lpInfo = dataInit.lps[0];
    const userAccount = await getUserAccount();
    const { leaf: userLeaf } = getTxLeaf(USER_TX_LIST[4]);
    const response = makerDeposit
      .connect(userAccount)
      .userWithDraw(userLeaf, lpInfo);
    await expect(response).to.be.revertedWith('UW_WITHDRAW');
  });
  it('LPAction again (Second time)', async () => {
    const lpInfo = dataInit.lps[1];
    const value = ethers.utils.parseEther('0.9');
    const pairProofLeavesHash = [dataInit.pairs[1]].map((row) => {
      return row.id;
    });
    const pairProof = pairProofLeavesHash.map((row) => {
      return supportPairTree.getHexProof(row);
    });
    const overrides = {
      value,
    };
    const response = await makerDeposit
      .connect(makerAccount)
      .LPAction([lpInfo], pairProof, overrides);
    await expect(response)
      .to.emit(makerDeposit, 'LogLpAction')
      .withArgs(anyValue, anyValue, anyValue);
    const chainDeposit = await makerDeposit.chainDeposit(
      lpInfo.sourceChain,
      lpInfo.sourceTAddress,
    );
    expect(chainDeposit.useLimit).equal(ethers.BigNumber.from(2));
    expect(chainDeposit.tokenAddress).equal(lpInfo.sourceTAddress);
  });
  it('userChanllenge for maker not send (Second time)', async () => {
    const { leaf, hex } = getTxLeaf(USER_TX_LIST[1]);
    const txProof = userTxTree.getHexProof(hex);
    const overrides = {
      value: ethers.utils.parseEther('1'),
    };
    const response = await makerDeposit
      .connect(UserTx1Account)
      .userChanllenge(leaf, txProof, overrides);
    await expect(response)
      .to.emit(makerDeposit, 'LogChanllengeInfo')
      .withArgs(anyValue, 0, anyValue, anyValue, anyValue);
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('User Withdrawal under successful UserChallenge (Second time and USER_LP_STOP)', async () => {
    const lpInfo = dataInit.lps[0];
    const { leaf: userLeaf } = getTxLeaf(USER_TX_LIST[1]);
    const beforeAmount = await UserTx1Account.getBalance();
    const response = await makerDeposit
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
    expect(tx.blockNumber).gt(0);
    if (tx.events !== undefined) {
      expect(
        tx.events?.findIndex(
          (row: { event: string }) => row.event === 'LogLPUserStop',
        ) >= 0,
      ).true;
      expect(
        tx.events?.findIndex(
          (row: { event: string }) => row.event === 'LogChanllengeInfo',
        ) >= 0,
      ).true;
    }
  });
  it('Maker withDraw not time', async () => {
    const lpInfo = testLPList[0];
    const chain = dataInit.chains.find(
      (row) => row.chainID === lpInfo['sourceChain'],
    );
    expect(chain.chainID).eq(lpInfo.sourceChain);
    expect(chain.tokenList).length.gt(0);
    const token = chain.tokenList.find(
      (t) => t.address === lpInfo.sourceTAddress,
    );
    const withDrawMax = await makerDeposit
      .connect(makerAccount)
      .idleAmount(token.pledgeToken);
    const response = makerDeposit
      .connect(makerAccount)
      .withDrawAssert(withDrawMax, token.pledgeToken);
    await expect(response).to.be.revertedWith('WITHDRAW_NOTIME');
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('Maker withDraw in time', async () => {
    const lpInfo = testLPList[0];
    const chain = dataInit.chains.find(
      (row) => row.chainID === lpInfo['sourceChain'],
    );
    expect(chain.chainID).eq(lpInfo.sourceChain);
    expect(chain.tokenList).length.gt(0);
    const token = chain.tokenList.find(
      (t) => t.address === lpInfo.sourceTAddress,
    );
    const beforeAmount = await makerAccount.getBalance();
    const withDrawMax = await makerDeposit
      .connect(makerAccount)
      .idleAmount(token.pledgeToken);
    const response = await makerDeposit
      .connect(makerAccount)
      .withDrawAssert(withDrawMax, token.pledgeToken);
    const tx = await response.wait();
    const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    const afterAmount = await makerAccount.getBalance();
    const nowWithDraw = await makerDeposit
      .connect(makerAccount)
      .idleAmount(token.pledgeToken);
    expect(beforeAmount.add(withDrawMax).sub(gasUsed)).eq(afterAmount);
    expect(nowWithDraw).eq(0);
  });
});
