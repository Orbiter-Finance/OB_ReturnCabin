/* eslint-disable @typescript-eslint/ban-ts-comment */
import { ethers } from 'hardhat';
import { ORMakerDeposit, ORMakerV1Factory } from '../typechain-types';
import { MerkleTree } from 'merkletreejs';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import {
  DataInit,
  getORMakerDepositContract,
  getORMakerV1FactoryContract,
  getORProtocalV1Contract,
  getTxLeaf,
  getUserAccount,
} from './utils.test';
import { BigNumber } from 'ethers';
const dataInit = new DataInit();
// const USER_TX_LIST = dataInit.userTxList;
// const MAKER_TX_LIST = dataInit.makerTxList;
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
// let testLPList: Array<any> = [];
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    // init lp list
    makerDeposit = await getORMakerDepositContract();
    makerV1Factory = await getORMakerV1FactoryContract();
    [owner, makerAccount, UserTx1Account, UserTx3Account] =
      await ethers.getSigners();
    // tree
    lpInfoTree = new MerkleTree([], keccak256, {
      sort: true,
    });
  }

  before(getFactoryInfo);
  async function speedUpTime(ms: number) {
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    await ethers.provider.send('evm_mine', [timestampBefore + ms]);
  }
  it('Get MakerFactory', async () => {
    const result = await makerDeposit.getMakerFactory();
    expect(result).equal(makerV1Factory.address);
  });
  it('Calculation of pledge quantity', async () => {
    const data = DataInit.lps.map((lp: any) => {
      const pair = DataInit.pairs.find((row) => row.id === lp.pairId);
      lp.sourceChain = pair.sourceChain;
      lp.destChain = pair.destChain;
      lp.sourceToken = pair.sourceToken;
      lp.destToken = pair.destToken;
      lp.ebc = pair.ebc;
      return lp;
    });
    const calcLpList = data.map((row) => {
      return {
        pairId: row.pairId,
        fromChain: row.sourceChain,
        maxPrice: row.maxPrice,
        fromToken: row.sourceToken,
        ebc: row.ebc,
      };
    });
    const result = await makerDeposit.calcLpPledgeAmount([
      calcLpList[0],
      calcLpList[3],
    ]);
    const totalPledgeValue = result.totalPledgeValue;
    await expect(totalPledgeValue).gt(0);
  });
  it('LPAction pledge ETH', async () => {
    const addLpInfo1 = DataInit.lps[0];
    const addLpInfo2 = DataInit.lps[3];
    // calc calcLpNeedPledgeAmount
    const pledgeResult = await makerDeposit.calcLpPledgeAmount([
      {
        pairId: addLpInfo1.pairId,
        fromChain: addLpInfo1.sourceChain,
        fromToken: addLpInfo1.sourceToken,
        maxPrice: addLpInfo1.maxPrice,
        ebc: addLpInfo1.ebc,
      },
      {
        pairId: addLpInfo2.pairId,
        fromChain: addLpInfo2.sourceChain,
        fromToken: addLpInfo2.sourceToken,
        maxPrice: addLpInfo2.maxPrice,
        ebc: addLpInfo2.ebc,
      },
    ]);
    const needPledgeQuantity = pledgeResult.totalPledgeValue;
    const addIdleFundsValue = ethers.BigNumber.from(
      (2 * Math.pow(10, 18)).toString(),
    );
    const overrides = {
      // value: ethers.BigNumber.from(0),
      value: needPledgeQuantity.add(addIdleFundsValue),
    };
    const actionLps = [addLpInfo1, addLpInfo2];
    const response = await makerDeposit
      .connect(makerAccount)
      .lpAction(actionLps, overrides);

    await expect(response)
      .to.emit(makerDeposit, 'LogLPAction')
      .withArgs(anyValue, anyValue, anyValue);
    const { events } = await response.wait();
    for (const event of events?.filter((e) => e.event === 'LogLPAction')) {
      const pairId = event.args[0];
      const lpId = event.args[1];
      const args = event.args[2];
      for (const row of DataInit.lps) {
        if (row.pairId === pairId) {
          row.id = lpId;
          row.startTime = Number(args.startTime);
          break;
        }
      }
    }
    for (const lp of actionLps) {
      const token = DataInit.getChainToken(lp.sourceChain, lp.sourceToken);
      const amount = await makerDeposit.getPledgeBalanceByChainToken(
        lp.sourceChain,
        token.address,
      );
      const row = pledgeResult.pledgeListData.find(
        (row) => Number(row.chainId) == Number(lp.sourceChain),
      );
      expect(row).not.empty;
      expect(row?.pledgeValue).eq(amount);
    }
    const contractBalance = await ethers.provider.getBalance(
      makerDeposit.address,
      'latest',
    );
    const token = DataInit.getChainToken(
      addLpInfo1.sourceChain,
      addLpInfo1.sourceToken,
    );
    const idleAmount = await makerDeposit.idleAmount(token.pledgeToken);
    expect(contractBalance).gte(needPledgeQuantity);
  });
  it('LPAction OK (Check Pairs)', async () => {
    const addLpInfo1 = DataInit.lps[0];
    const pairs1 = await makerDeposit.getPairsByChain(addLpInfo1.sourceChain);
    const addPair1 = DataInit.pairs.find((row) => row.id == addLpInfo1.pairId);

    expect(pairs1).includes(addPair1.id);
    const addLpInfo2 = DataInit.lps[3];
    const pairs2 = await makerDeposit.getPairsByChain(addLpInfo2.sourceChain);
    const addPair2 = DataInit.pairs.find((row) => row.id == addLpInfo2.pairId);
    expect(pairs2).includes(addPair2.id);
  });
  it('Check idleFunds', async () => {
    const addLpInfo1 = DataInit.lps[0];
    const addPair1 = DataInit.pairs.find((row) => row.id == addLpInfo1.pairId);
    const token = DataInit.getChainToken(
      addPair1.sourceChain,
      addPair1.sourceToken,
    );
    const addIdleFundsValue = ethers.BigNumber.from(
      (2 * Math.pow(10, 18)).toString(),
    );
    const idleAmount = await makerDeposit.idleAmount(token.pledgeToken);
    expect(idleAmount).eq(addIdleFundsValue);
  });
  it('Calculation of pledge quantity 2', async () => {
    const data = DataInit.lps.map((lp: any) => {
      const pair = DataInit.pairs.find((row) => row.id === lp.pairId);
      lp.sourceChain = pair.sourceChain;
      lp.destChain = pair.destChain;
      lp.sourceToken = pair.sourceToken;
      lp.destToken = pair.destToken;
      lp.ebc = pair.ebc;
      return lp;
    });
    const calcLpList = data.map((row) => {
      return {
        pairId: row.pairId,
        fromChain: row.sourceChain,
        fromToken: row.sourceToken,
        maxPrice: row.maxPrice,
        ebc: row.ebc,
      };
    });
    const result = await makerDeposit.calcLpPledgeAmount([calcLpList[1]]);
    const totalPledgeValue = result.totalPledgeValue;
    await expect(totalPledgeValue).eq(0);
  });
  it('LPAction pledge ETH（No pledge required）', async () => {
    const addLpInfo1 = DataInit.lps[1];
    const addLpInfo2 = DataInit.lps[4];
    // calc calcLpNeedPledgeAmount
    const pledgeResult = await makerDeposit.calcLpPledgeAmount([
      {
        pairId: addLpInfo1.pairId,
        fromChain: addLpInfo1.sourceChain,
        maxPrice: addLpInfo1.maxPrice,
        fromToken: addLpInfo1.sourceToken,
        ebc: addLpInfo1.ebc,
      },
      {
        pairId: addLpInfo2.pairId,
        fromChain: addLpInfo2.sourceChain,
        maxPrice: addLpInfo2.maxPrice,
        fromToken: addLpInfo2.sourceToken,
        ebc: addLpInfo2.ebc,
      },
    ]);
    const needPledgeQuantity = pledgeResult.totalPledgeValue;
    const addIdleFundsValue = ethers.BigNumber.from(0);
    const overrides = {
      value: needPledgeQuantity.add(addIdleFundsValue),
    };
    const actionLps = [addLpInfo1, addLpInfo2];
    const response = await makerDeposit
      .connect(makerAccount)
      .lpAction(actionLps, overrides);
    await expect(response)
      .to.emit(makerDeposit, 'LogLPAction')
      .withArgs(anyValue, anyValue, anyValue);
    const { events } = await response.wait();
    for (const event of events?.filter((e) => e.event === 'LogLPAction')) {
      const pairId = event.args[0];
      const lpId = event.args[1];
      const args = event.args[2];
      for (const row of DataInit.lps) {
        if (row.pairId === pairId) {
          row.id = lpId;
          row.startTime = Number(args.startTime);
          break;
        }
      }
    }
    for (const lp of actionLps) {
      // const amount = await makerDeposit.getPledgeBalanceByChainToken(
      //   lp.sourceChain,
      //   lp.sourceToken,
      // );
      const row = pledgeResult.pledgeListData.find(
        (row) => Number(row.chainId) == Number(lp.sourceChain),
      );
      expect(row).not.empty;
      expect(row?.pledgeValue.sub(row.pledged)).eq(needPledgeQuantity);
    }
    const contractBalance = await ethers.provider.getBalance(
      makerDeposit.address,
      'latest',
    );
    expect(contractBalance).gte(needPledgeQuantity);
  });
  it('LPPause', async () => {
    const response = await makerDeposit
      .connect(makerAccount)
      .lpPause([DataInit.lps[0], DataInit.lps[1]]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLPPause')
      .withArgs(anyValue, anyValue, anyValue);
  });
  it('LPUpdate', async () => {
    const changeLpInfo = DataInit.lps[0];
    const updateData = {
      tradingFee: BigNumber.from(0.0005 * 10 ** 18),
      gasFee: changeLpInfo.gasFee,
    };
    const response = await makerDeposit.connect(makerAccount).lpUpdate([
      {
        pid: changeLpInfo.pairId,
        lpid: changeLpInfo.id,
        ...updateData,
      },
    ]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLPUpdate')
      .withArgs(
        changeLpInfo.pairId,
        changeLpInfo.id,
        updateData.gasFee,
        updateData.tradingFee,
      );
  });
  it('LPRestart', async () => {
    const restartLpInfo = DataInit.lps[0];
    const response = await makerDeposit.connect(makerAccount).lpRestart([
      {
        pid: restartLpInfo.pairId,
        lpid: restartLpInfo.id,
        gasFee: restartLpInfo.gasFee,
        tradingFee: restartLpInfo.tradingFee,
      },
    ]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLPRestart')
      .withArgs(
        restartLpInfo.pairId,
        restartLpInfo.id,
        restartLpInfo.gasFee,
        restartLpInfo.tradingFee,
      );
  });
  it('LPRestart After Pause', async () => {
    const restartLpInfo = DataInit.lps[0];
    const response = await makerDeposit
      .connect(makerAccount)
      .lpPause([restartLpInfo]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLPPause')
      .withArgs(anyValue, anyValue, anyValue);
  });
  it('LPStop not time', async () => {
    const lpInfo = DataInit.lps[0];
    const response = makerDeposit.connect(makerAccount).lpStop([lpInfo]);
    await expect(response).to.be.revertedWith('LPSTOP_LPID_TIMEUNABLE');
  });

  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('LPStop is time(1)', async () => {
    const lpInfo = DataInit.lps[0];
    const pairs1 = await makerDeposit.getPairsByChain(lpInfo.sourceChain);
    expect(pairs1).includes(lpInfo.pairId);
    const response = await makerDeposit.connect(makerAccount).lpStop([lpInfo]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLPStop')
      .withArgs(anyValue, anyValue, anyValue);
    const pairs2 = await makerDeposit.getPairsByChain(lpInfo.sourceChain);
    expect(pairs2).not.includes(lpInfo.pairId);
  });
  it('LPStop is time(2)', async () => {
    const lpInfo = DataInit.lps[1];
    const pairs1 = await makerDeposit.getPairsByChain(lpInfo.sourceChain);
    expect(pairs1).includes(lpInfo.pairId);
    const response = await makerDeposit.connect(makerAccount).lpStop([lpInfo]);
    await expect(response)
      .to.emit(makerDeposit, 'LogLPStop')
      .withArgs(anyValue, anyValue, anyValue);
    const pairs2 = await makerDeposit.getPairsByChain(lpInfo.sourceChain);
    expect(pairs2).not.includes(lpInfo.pairId);
  });
  it('LPStop After Check PledgeBalance', async () => {
    const lpInfo1 = DataInit.lps[0];
    const pairs1 = await makerDeposit.getPairsByChain(lpInfo1.sourceChain);
    expect(pairs1.length).eq(0);
    const addPair1 = DataInit.pairs.find((row) => row.id == lpInfo1.pairId);
    const token = DataInit.getChainToken(
      addPair1.sourceChain,
      addPair1.sourceToken,
    );

    const addLpInfo1 = DataInit.lps[0];
    const addLpInfo2 = DataInit.lps[3];
    const addIdleFundsValue = ethers.BigNumber.from(
      (2 * Math.pow(10, 18)).toString(),
    );
    const pledgeResult = await makerDeposit.calcLpPledgeAmount([
      {
        pairId: addLpInfo1.pairId,
        fromChain: addLpInfo1.sourceChain,
        fromToken: addLpInfo1.sourceToken,
        maxPrice: addLpInfo1.maxPrice,
        ebc: addLpInfo1.ebc,
      },
      {
        pairId: addLpInfo2.pairId,
        fromChain: addLpInfo2.sourceChain,
        fromToken: addLpInfo2.sourceToken,
        maxPrice: addLpInfo2.maxPrice,
        ebc: addLpInfo2.ebc,
      },
    ]);
    // check idleAmount
    const idleAmount = await makerDeposit.idleAmount(token.pledgeToken);
    expect(idleAmount).eq(addIdleFundsValue.add(pledgeResult.totalPledgeValue));

    // check pledageValue
    const pledgeValue = await makerDeposit.getPledgeBalance(token.pledgeToken);
    const chainTokenPledgeValue =
      await makerDeposit.getPledgeBalanceByChainToken(33, token.pledgeToken);
    expect(pledgeValue).eq(chainTokenPledgeValue);
  });
  it('Maker withDraw is time and no challenge', async () => {
    const lpInfo = DataInit.lps[0];
    const chain = DataInit.chains.find(
      (row) => row.chainID === lpInfo['sourceChain'],
    );
    expect(chain.chainID).eq(lpInfo.sourceChain);
    expect(chain.tokenList).length.gt(0);
    const token = chain.tokenList.find((t) => t.address === lpInfo.sourceToken);
    expect(token).not.empty;
    let beforeAmount = await makerAccount.getBalance();
    const withDrawMax = await makerDeposit
      .connect(makerAccount)
      .idleAmount(token.pledgeToken);
    const firstWithDraw = withDrawMax.div(2);
    let response = await makerDeposit
      .connect(makerAccount)
      .withDrawAssert(firstWithDraw, token.pledgeToken);
    let tx = await response.wait();
    let gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    let afterAmount = await makerAccount.getBalance();
    let nowWithDraw = await makerDeposit
      .connect(makerAccount)
      .idleAmount(token.pledgeToken);
    beforeAmount = beforeAmount.add(firstWithDraw).sub(gasUsed);
    expect(beforeAmount).eq(afterAmount);
    expect(nowWithDraw).eq(firstWithDraw);
    const withDrawMax2 = await makerDeposit
      .connect(makerAccount)
      .idleAmount(token.pledgeToken);
    expect(withDrawMax2).eq(firstWithDraw);
    response = await makerDeposit
      .connect(makerAccount)
      .withDrawAssert(firstWithDraw, token.pledgeToken);
    tx = await response.wait();
    gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    beforeAmount = beforeAmount.add(firstWithDraw).sub(gasUsed);
    nowWithDraw = await makerDeposit
      .connect(makerAccount)
      .idleAmount(token.pledgeToken);
    afterAmount = await makerAccount.getBalance();
    expect(beforeAmount).eq(afterAmount);
    expect(nowWithDraw).eq(0);
  });
  it('LPAction pledge ETH (again)', async () => {
    const addLpInfo1 = DataInit.lps[0];
    // calc calcLpNeedPledgeAmount
    const pledgeResult = await makerDeposit.calcLpPledgeAmount([
      {
        pairId: addLpInfo1.pairId,
        fromChain: addLpInfo1.sourceChain,
        fromToken: addLpInfo1.sourceToken,
        maxPrice: addLpInfo1.maxPrice,
        ebc: addLpInfo1.ebc,
      },
    ]);
    const needPledgeQuantity = pledgeResult.totalPledgeValue;
    const addIdleFundsValue = ethers.BigNumber.from(
      (2 * Math.pow(10, 18)).toString(),
    );
    const overrides = {
      value: needPledgeQuantity.add(addIdleFundsValue),
    };
    const actionLps = [addLpInfo1];
    const response = await makerDeposit
      .connect(makerAccount)
      .lpAction(actionLps, overrides);

    await expect(response)
      .to.emit(makerDeposit, 'LogLPAction')
      .withArgs(anyValue, anyValue, anyValue);
    const { events } = await response.wait();
    for (const event of events?.filter((e) => e.event === 'LogLPAction')) {
      const pairId = event.args[0];
      const lpId = event.args[1];
      const args = event.args[2];
      for (const row of DataInit.lps) {
        if (row.pairId === pairId) {
          row.id = lpId;
          row.startTime = Number(args.startTime);
          break;
        }
      }
    }
    for (const lp of actionLps) {
      const token = DataInit.getChainToken(lp.sourceChain, lp.sourceToken);
      const amount = await makerDeposit.getPledgeBalanceByChainToken(
        lp.sourceChain,
        token.address,
      );
      const row = pledgeResult.pledgeListData.find(
        (row) => Number(row.chainId) == Number(lp.sourceChain),
      );
      expect(row).not.empty;
      expect(row?.pledgeValue).eq(amount);
    }
    const contractBalance = await ethers.provider.getBalance(
      makerDeposit.address,
      'latest',
    );
    expect(contractBalance).gte(needPledgeQuantity);
  });
  it('userChallenge for maker not send', async () => {
    const { leaf, hex } = getTxLeaf(DataInit.userTxList[0]);
    const txProof = userTxTree.getHexProof(hex);
    const overrides = {
      value: ethers.utils.parseEther('1'),
    };
    const response = await makerDeposit
      .connect(UserTx1Account)
      .userChallenge(leaf, txProof, overrides);
    await expect(response)
      .to.emit(makerDeposit, 'LogChallengeInfo')
      .withArgs(anyValue, anyValue, anyValue, anyValue);
  });
  it('userChallenge for maker already send', async () => {
    // User
    const { leaf: userLeaf, hex: userHex } = getTxLeaf(DataInit.userTxList[4]);
    const userProof = userTxTree.getHexProof(userHex);
    const overrides = {
      value: ethers.utils.parseEther('1'),
    };
    const userResponse = await makerDeposit
      .connect(UserTx1Account)
      .userChallenge(userLeaf, userProof, overrides);
    await expect(userResponse)
      .to.emit(makerDeposit, 'LogChallengeInfo')
      .withArgs(anyValue, anyValue, anyValue, anyValue);
    // Maker
    DataInit.makerTxList[2].lpid = DataInit.userTxList[4].lpid;
    const { leaf: makerLeaf, hex: makerHex } = getTxLeaf(
      DataInit.makerTxList[2],
    );
    const makerProof = makerTxTree.getHexProof(makerHex);
    const makerResponce = await makerDeposit
      .connect(makerAccount)
      .makerChallenger(userLeaf, makerLeaf, makerProof);
    await expect(makerResponce)
      .to.emit(makerDeposit, 'LogChallengeInfo')
      .withArgs(anyValue, anyValue, anyValue, anyValue);
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('User Withdrawal under successful UserChallenge', async () => {
    const lpInfo = DataInit.lps[0];
    const { leaf: userLeaf } = getTxLeaf(DataInit.userTxList[0]);
    const beforeAmount = await UserTx1Account.getBalance();
    const response = await makerDeposit
      .connect(UserTx1Account)
      .userWithDraw(userLeaf, lpInfo);
    const afterAmount = await UserTx1Account.getBalance();
    expect(afterAmount).gt(beforeAmount);
    const tx = await response.wait();
    const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    const pledgeAmount = ethers.utils.parseEther('1');
    const ebc = await getORProtocalV1Contract();
    const ETHPunishAmount = await ebc.calculateCompensation(
      '0x0000000000000000000000000000000000000000',
      userLeaf.amount,
    );
    const amount = ETHPunishAmount.baseValue
      .add(ETHPunishAmount.additiveValue)
      .add(pledgeAmount)
      .sub(gasUsed);
    expect(amount).eq(afterAmount.sub(beforeAmount));
  });
  it('User Withdrawal in failure of UserChallenge', async () => {
    const lpInfo = DataInit.lps[0];
    const userAccount = await getUserAccount();
    const { leaf: userLeaf } = getTxLeaf(DataInit.userTxList[4]);
    const response = makerDeposit
      .connect(userAccount)
      .userWithDraw(userLeaf, lpInfo);
    await expect(response).to.be.revertedWith('UW_WITHDRAW');
  });
  it('userChallenge for maker not send (Second time)', async () => {
    const { leaf, hex } = getTxLeaf(DataInit.userTxList[1]);
    const txProof = userTxTree.getHexProof(hex);
    const overrides = {
      value: ethers.utils.parseEther('1'),
    };
    const response = await makerDeposit
      .connect(UserTx1Account)
      .userChallenge(leaf, txProof, overrides);
    await expect(response)
      .to.emit(makerDeposit, 'LogChallengeInfo')
      .withArgs(anyValue, anyValue, anyValue, anyValue);
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('User Withdrawal under successful UserChallenge (Second time and USER_LP_STOP)', async () => {
    const lpInfo = DataInit.lps[0];
    const { leaf: userLeaf } = getTxLeaf(DataInit.userTxList[1]);

    const beforeAmount = await UserTx1Account.getBalance();
    const response = await makerDeposit
      .connect(UserTx1Account)
      .userWithDraw(userLeaf, lpInfo);

    const tx = await response.wait();
    const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    const pledgeAmount = ethers.utils.parseEther('1');
    const protocalV1Contract = await getORProtocalV1Contract();
    const result = await protocalV1Contract.calculateCompensation(
      '0x0000000000000000000000000000000000000000',
      userLeaf.amount,
    );
    const ETHPunishAmount = result.baseValue.add(result.additiveValue);
    const realAfterAmount = await UserTx1Account.getBalance();
    const expectAfterAmount = beforeAmount
      .add(pledgeAmount)
      .add(ETHPunishAmount)
      .sub(gasUsed);
    expect(realAfterAmount).eq(expectAfterAmount);
    expect(tx.blockNumber).gt(0);

    if (tx.events !== undefined) {
      const events = tx.events || [];
      const eventNames = events.map((e) => e.event);
      expect(eventNames).includes('LogLPUserStop');
      expect(eventNames).includes('LogChallengerCompensation');
    }
  });
  it('Maker withDraw not time', async () => {
    const lpInfo = DataInit.lps[0];
    const chain = DataInit.chains.find(
      (row) => row.chainID === lpInfo['sourceChain'],
    );
    expect(chain.chainID).eq(lpInfo.sourceChain);
    expect(chain.tokenList).length.gt(0);
    const token = chain.tokenList.find((t) => t.address === lpInfo.sourceToken);
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
    const lpInfo = DataInit.lps[0];
    const chain = DataInit.chains.find(
      (row) => row.chainID === lpInfo['sourceChain'],
    );
    expect(chain.chainID).eq(lpInfo.sourceChain);
    expect(chain.tokenList).length.gt(0);
    const token = chain.tokenList.find((t) => t.address === lpInfo.sourceToken);
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
  it('Check Maker LP List After', async () => {
    const chainPairs2 = await makerDeposit.getPairsByChain(33);
    const pairs2 = await makerDeposit.getPairsByPledgeToken(
      '0x0000000000000000000000000000000000000000',
    );
    chainPairs2.forEach((pairId) => {
      expect(pairs2).includes(pairId);
    });
  });
});
