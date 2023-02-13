/* eslint-disable @typescript-eslint/ban-ts-comment */
import { ethers } from 'hardhat';
import { ORMakerDeposit } from '../typechain-types';
import { expect } from 'chai';
import {
  DataInit,
  getORMakerDepositContract,
  getORMakerV1FactoryContract,
  getORProtocalV1Contract,
  getSPVProof,
} from './utils.test';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
let MDC: ORMakerDeposit;
let makerAccount: SignerWithAddress;
let UserTx1Account: SignerWithAddress;
let UserTx2Account: SignerWithAddress;
let UserTx3Account: SignerWithAddress;
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    // init lp list
    MDC = await getORMakerDepositContract();
    const accounts = await ethers.getSigners();
    makerAccount = accounts[1];
    UserTx1Account = accounts[accounts.length - 1];
    UserTx2Account = accounts[accounts.length - 2];
    UserTx3Account = accounts[accounts.length - 3];
  }

  before(getFactoryInfo);
  async function speedUpTime(ms: number) {
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    await ethers.provider.send('evm_mine', [timestampBefore + ms]);
  }
  it('Get MakerFactory', async () => {
    const makerV1Factory = await getORMakerV1FactoryContract();
    const result = await MDC.getMakerFactory();
    expect(result).equal(makerV1Factory.address);
  });
  describe('Action LP', () => {
    let totalPledgeValue = ethers.BigNumber.from(0);
    it('LPAction pledge ETH', async () => {
      const lps = DataInit.lps;
      const result = await MDC.calculatePairPledgeAmount([lps[0], lps[1]]);
      totalPledgeValue = result[0].pledgedValue;
      console.log('totalPledgeValue: ', totalPledgeValue);
      totalPledgeValue = totalPledgeValue.mul(2);
      await expect(MDC.connect(makerAccount).lpAction(lps)).to.be.revertedWith(
        'Insufficient pledge quantity',
      );
      const tx = await MDC.connect(makerAccount).lpAction([lps[1]], {
        value: totalPledgeValue,
      });
      await tx.wait();
      const idleAmount = await MDC.idleAmount(
        '0x0000000000000000000000000000000000000000',
      );
      console.log('idleAmount', idleAmount);
      await MDC.connect(makerAccount).lpAction([lps[0]], {
        value: '0',
      });
    });
    // it('Calculation of pledge quantity', async () => {
    //   console.log(DataInit.lps, '===DataInit.lps');
    //   const result1 = await MDC.calculatePledgeAmount([DataInit.lps[0]]);
    //   console.log(result1, '====result1');
    //   const result2 = await MDC.calculatePledgeAmount([DataInit.lps[1]]);
    //   console.log(result2, '====result2');
    //   // const totalPledgeValue = result.totalPledgeValue;
    //   // await expect(totalPledgeValue).gt(0);
    // });
    it('getPairsByPledgeToken', async () => {
      // const result = await MDC.getPairsByPledgeToken(
      //   '0x0000000000000000000000000000000000000000',
      // );
      // const lps = DataInit.lps;
      // expect(result.length).eq(2);
      // expect(result[0]).eq(lps[0].pairId);
      // expect(result[1]).eq(lps[1].pairId);
    });
    it('get MDC Balance', async () => {
      const result = await MDC.getPledgeBalance(
        '0x0000000000000000000000000000000000000000',
      );
      const mdcETHBalance = await ethers.provider.getBalance(MDC.address);
      console.log('mdcETHBalance: ', mdcETHBalance);
      expect(mdcETHBalance).eq(totalPledgeValue);
      expect(result).eq(totalPledgeValue.div(2));
    });
    it('idleAmount', async () => {
      const result = await MDC.idleAmount(
        '0x0000000000000000000000000000000000000000',
      );
      console.log('idleAmount', result);
      expect(result).eq(totalPledgeValue.div(2));
    });

    it('getPledgeBalanceByChainToken', async () => {
      const lps = DataInit.lps;
      const pairInfo = DataInit.pairs.find((p) => p.id === lps[0].pairId);
      const result = await MDC.getPledgeBalanceByChainToken(
        pairInfo.sourceChain,
        '0x0000000000000000000000000000000000000000',
      );
      expect(result).eq(totalPledgeValue.div(2));
    });
    it('effectivePairLP', async () => {
      const lps = DataInit.lps;
      for (const lp of [lps[0], lps[1]]) {
        const pairInfo = await MDC.effectivePair(lp.pairId);
        expect(pairInfo).not.empty;
        expect(pairInfo.startTime).gt(0);
        expect(pairInfo.stopTime).eq(0);
        const lpData = await MDC.lpData(pairInfo.lpId);
        expect(lpData).not.empty;
        expect(lpData.maxPrice).eq(ethers.BigNumber.from(lp.maxPrice));
        expect(lpData.gasFee).eq(ethers.BigNumber.from(lp.gasFee));
        expect(lpData.minPrice).eq(ethers.BigNumber.from(lp.minPrice));
        expect(lpData.tradingFee).eq(ethers.BigNumber.from(lp.tradingFee));
      }
    });

    it('LPAction pledge ETH(Pair already exists)', async () => {
      const lps = DataInit.lps;
      await expect(
        MDC.connect(makerAccount).lpAction([lps[0]], {
          value: totalPledgeValue,
        }),
      ).to.be.revertedWith('Pair already exists');
    });
    it('LP Pause', async () => {
      const lps = DataInit.lps;
      const pause1Tx = await MDC.connect(makerAccount).lpPause(lps[0].pairId);
      await pause1Tx.wait();
      const effectivePair = await MDC.effectivePair(lps[0].pairId);
      expect(effectivePair.lpId).not.empty;
      expect(effectivePair.startTime).eq(0);
      expect(effectivePair.stopTime).gt(0);
    });
    it('LP Pause(LP not started)', async () => {
      const lps = DataInit.lps;
      await expect(
        MDC.connect(makerAccount).lpPause(lps[0].pairId),
      ).to.be.revertedWith('LP not started');
    });
    it('LP Update', async () => {
      const lps = DataInit.lps;
      const startLP = lps[0];
      const oldDataPair = await MDC.effectivePair(startLP.pairId);
      const oldDataLp = await MDC.lpData(oldDataPair.lpId);
      startLP.gasFee = '20000000000000000';
      const pause1Tx = await MDC.connect(makerAccount).lpUpdate(startLP);
      await pause1Tx.wait();
      const newDataPair = await MDC.effectivePair(startLP.pairId);
      const newDataLp = await MDC.lpData(newDataPair.lpId);
      expect(newDataPair.lpId).not.eq(oldDataPair.lpId);
      expect(newDataLp.gasFee).eq('20000000000000000');
    });
    it('LP Restart', async () => {
      const lps = DataInit.lps;
      const startLP = lps[0];
      const pauseTx = await MDC.connect(makerAccount).lpPause(startLP.pairId);
      await pauseTx.wait();
      const restartTx = await MDC.connect(makerAccount).lpRestart(
        startLP.pairId,
      );
      await restartTx.wait();
    });
    it('LP Restart(LP not paused)', async () => {
      const lps = DataInit.lps;
      const startLP = lps[0];
      // startLP.gasFee = '20000000000000000';
      await expect(
        MDC.connect(makerAccount).lpRestart(startLP.pairId),
      ).to.be.revertedWith('LP not paused');
    });
    it('LP Stop', async () => {
      const lps = DataInit.lps;
      await MDC.connect(makerAccount).lpAction([lps[2]]);
      const pauseCodes = [lps[0].pairId, lps[1].pairId, lps[2].pairId].map(
        (row) => {
          return MDC.interface.encodeFunctionData('lpPause', [row]);
        },
      );
      const idleAmountBefore = await MDC.idleAmount(
        '0x0000000000000000000000000000000000000000',
      );

      const pause1Tx = await MDC.connect(makerAccount).multicall(pauseCodes);
      await pause1Tx.wait();

      const effectivePair = await MDC.effectivePair(lps[0].pairId);
      expect(effectivePair.lpId).not.empty;
      expect(effectivePair.startTime).eq(0);
      expect(effectivePair.stopTime).gt(0);
      // stop
      await speedUpTime(3600);
      const stopCodes = [lps[0], lps[2], lps[1]].map((row) => {
        return MDC.interface.encodeFunctionData('lpStop', [row.pairId]);
      });
      const stop1Tx = await MDC.connect(makerAccount).multicall(stopCodes);
      await stop1Tx.wait();
      const idleAmountAfter = await MDC.idleAmount(
        '0x0000000000000000000000000000000000000000',
      );
      expect(idleAmountAfter).gt(idleAmountBefore);

      expect(idleAmountAfter).eq(totalPledgeValue);
    });
    it('Maker withDraw is time and no challenge', async () => {
      let beforeAmount = await makerAccount.getBalance();
      const response = await MDC.connect(makerAccount).withDrawAssert(
        totalPledgeValue,
        '0x0000000000000000000000000000000000000000',
      );
      const tx = await response.wait();
      const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
      const afterAmount = await makerAccount.getBalance();
      const idleAmountAfter = await MDC.idleAmount(
        '0x0000000000000000000000000000000000000000',
      );
      beforeAmount = beforeAmount.add(totalPledgeValue).sub(gasUsed);
      expect(beforeAmount).eq(afterAmount);
      expect(idleAmountAfter).eq(0);
    });
    it('LPAction pledge ETH Again', async () => {
      const lps = DataInit.lps;
      const result = await MDC.calculatePairPledgeAmount([lps[0], lps[1]]);
      totalPledgeValue = result[0].pledgedValue;
      totalPledgeValue = totalPledgeValue.mul(2);
      await expect(MDC.connect(makerAccount).lpAction(lps)).to.be.revertedWith(
        'Insufficient pledge quantity',
      );
      const tx = await MDC.connect(makerAccount).lpAction([lps[1]], {
        value: totalPledgeValue,
      });
      await tx.wait();
      await MDC.connect(makerAccount).lpAction([lps[0]], {
        value: '0',
      });
    });
    it('maker send amount => userChallenge failure => user Withdraw failed', async () => {
      // user Challenge
      const userTx = DataInit.userTxList[0];
      const userTxBytes = await getSPVProof(userTx.chainId, userTx.txHash);
      const beforeAmount = await UserTx1Account.getBalance();
      const overrides = {
        value: ethers.utils.parseEther('1'), //>=0.05 ether
      };
      const userChallengeResponse = await MDC.connect(
        UserTx1Account,
      ).userChallenge(userTxBytes as Buffer, overrides);
      const tx = await userChallengeResponse.wait();
      const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
      const afterAmount = await UserTx1Account.getBalance();
      expect(afterAmount).eq(beforeAmount.sub(overrides.value).sub(gasUsed));
      await expect(userChallengeResponse)
        .to.emit(MDC, 'LogChallengeInfo')
        .withArgs(anyValue, anyValue, anyValue, anyValue);

      // maker Challenge
      const makerTx = DataInit.makerTxList[0];
      const l1Sub =
        '0x41080ea8df1841a67745f3d9a5315f8242c003ae3a1f0f8f610f0608008efdb5';
      const makerTxBytes = await getSPVProof(
        makerTx.chainId,
        l1Sub,
        makerTx.txHash,
      );
      const makerChallengeResponse = await MDC.connect(
        makerAccount,
      ).makerChallenge(userTx, makerTxBytes as Buffer, { gasLimit: 29000000 });
      await makerChallengeResponse.wait();
      await expect(makerChallengeResponse)
        .to.emit(MDC, 'LogChallengeInfo')
        .withArgs(anyValue, anyValue, anyValue, anyValue);

      // user Withdraw
      await speedUpTime(3600 * 24);
      const lpInfo = DataInit.lps[0];
      const response = MDC.connect(UserTx1Account).userWithDraw(userTx, lpInfo);
      await expect(response).to.be.revertedWith('UW_WITHDRAW');
    });
    it('maker no send => userChallenge successful => user Withdraw success', async () => {
      // user Challenge
      const userTx = DataInit.userTxList[1];
      const userTxBytes = await getSPVProof(userTx.chainId, userTx.txHash);
      const userChallengeBeforeAmount = await UserTx2Account.getBalance();
      const overrides = {
        value: ethers.utils.parseEther('1'), //>=0.05 ether
      };
      const userChallengeResponse = await MDC.connect(
        UserTx2Account,
      ).userChallenge(userTxBytes as Buffer, overrides);
      const userChallengeTx = await userChallengeResponse.wait();
      const userChallengeGasUsed = userChallengeTx.cumulativeGasUsed.mul(
        userChallengeTx.effectiveGasPrice,
      );
      const userChallengeAfterAmount = await UserTx2Account.getBalance();
      expect(userChallengeAfterAmount).eq(
        userChallengeBeforeAmount
          .sub(overrides.value)
          .sub(userChallengeGasUsed),
      );
      await expect(userChallengeResponse)
        .to.emit(MDC, 'LogChallengeInfo')
        .withArgs(anyValue, anyValue, anyValue, anyValue);

      // maker don't response Challenge

      // user withdraw
      await speedUpTime(3600 * 24);
      const lpInfo = DataInit.lps[0];
      const userWithdrawBeforeAmount = await UserTx2Account.getBalance();
      const userWithdrawResponse = await MDC.connect(
        UserTx2Account,
      ).userWithDraw(userTx, lpInfo);
      const userWithdrawAfterAmount = await UserTx2Account.getBalance();
      const userWithdrawTx = await userWithdrawResponse.wait();
      const gasUsed = userWithdrawTx.cumulativeGasUsed.mul(
        userWithdrawTx.effectiveGasPrice,
      );
      const pledgeAmount = ethers.utils.parseEther('1');
      const ebc = await getORProtocalV1Contract();
      const ETHPunishAmount = await ebc.calculateCompensation(
        '0x0000000000000000000000000000000000000000',
        userTx.value,
      );
      const amount = ETHPunishAmount.baseValue
        .add(ETHPunishAmount.additiveValue)
        .add(pledgeAmount)
        .sub(gasUsed);
      expect(amount).eq(userWithdrawAfterAmount.sub(userWithdrawBeforeAmount));
    });
    it('maker no send => userChallenge successful => challengerMakeGood', async () => {
      // user Challenge
      const userTx = DataInit.userTxList[2];
      const userTxBytes = await getSPVProof(userTx.chainId, userTx.txHash);
      const userChallengeBeforeAmount = await UserTx3Account.getBalance();
      const overrides = {
        value: ethers.utils.parseEther('1'), //>=0.05 ether
      };
      const userChallengeResponse = await MDC.connect(
        UserTx3Account,
      ).userChallenge(userTxBytes as Buffer, overrides);
      const userChallengeTx = await userChallengeResponse.wait();
      const userChallengeGasUsed = userChallengeTx.cumulativeGasUsed.mul(
        userChallengeTx.effectiveGasPrice,
      );
      const userChallengeAfterAmount = await UserTx3Account.getBalance();
      expect(userChallengeAfterAmount).eq(
        userChallengeBeforeAmount
          .sub(overrides.value)
          .sub(userChallengeGasUsed),
      );
      await expect(userChallengeResponse)
        .to.emit(MDC, 'LogChallengeInfo')
        .withArgs(anyValue, anyValue, anyValue, anyValue);

      // maker don't response challenge

      // challengerMakeGood
      await speedUpTime(3600 * 24);
      const challengerMakeGoodBeforeAmount = await ethers.provider.getBalance(
        userTx.from,
      );
      const challengerMakeGoodResponse = await MDC.connect(
        makerAccount,
      ).challengerMakeGood(userTx);

      await expect(challengerMakeGoodResponse)
        .to.emit(MDC, 'LogChallengerCompensation')
        .withArgs(anyValue, anyValue, anyValue, anyValue, anyValue);

      const challengerMakeGoodAfterAmount = await ethers.provider.getBalance(
        userTx.from,
      );

      const pledgeAmount = ethers.utils.parseEther('1');
      const ebc = await getORProtocalV1Contract();
      const ETHPunishAmount = await ebc.calculateCompensation(
        '0x0000000000000000000000000000000000000000',
        userTx.value,
      );
      const amount = ETHPunishAmount.baseValue
        .add(ETHPunishAmount.additiveValue)
        .add(pledgeAmount);
      expect(amount).eq(
        challengerMakeGoodAfterAmount.sub(challengerMakeGoodBeforeAmount),
      );
    });
    it('Maker withDraw and remain 0.0001ether', async () => {
      let beforeAmount = await makerAccount.getBalance();
      const idleAmountBefore = await MDC.idleAmount(
        '0x0000000000000000000000000000000000000000',
      );
      const remainIdleAmount = ethers.utils.parseEther('0.0001');
      const response = await MDC.connect(makerAccount).withDrawAssert(
        idleAmountBefore.sub(remainIdleAmount),
        '0x0000000000000000000000000000000000000000',
      );
      const tx = await response.wait();
      const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
      const afterAmount = await makerAccount.getBalance();
      const idleAmountAfter = await MDC.idleAmount(
        '0x0000000000000000000000000000000000000000',
      );
      beforeAmount = beforeAmount
        .add(idleAmountBefore.sub(remainIdleAmount))
        .sub(gasUsed);
      expect(beforeAmount).eq(afterAmount);
      expect(idleAmountAfter).eq(remainIdleAmount);
    });
    it('maker no send => userChallenge successful => userLpStop', async () => {
      // user Challenge
      const userTx = DataInit.userTxList[3];
      const userTxBytes = await getSPVProof(userTx.chainId, userTx.txHash);
      const userChallengeBeforeAmount = await UserTx3Account.getBalance();
      const overrides = {
        value: ethers.utils.parseEther('1'), //>=0.05 ether
      };
      const userChallengeResponse = await MDC.connect(
        UserTx3Account,
      ).userChallenge(userTxBytes as Buffer, overrides);
      const userChallengeTx = await userChallengeResponse.wait();
      const userChallengeGasUsed = userChallengeTx.cumulativeGasUsed.mul(
        userChallengeTx.effectiveGasPrice,
      );
      const userChallengeAfterAmount = await UserTx3Account.getBalance();
      expect(userChallengeAfterAmount).eq(
        userChallengeBeforeAmount
          .sub(overrides.value)
          .sub(userChallengeGasUsed),
      );
      await expect(userChallengeResponse)
        .to.emit(MDC, 'LogChallengeInfo')
        .withArgs(anyValue, anyValue, anyValue, anyValue);

      // maker don't response challenge

      // user withdraw
      await speedUpTime(3600 * 24);
      const lpInfo = DataInit.lps[0];
      const userWithdrawBeforeAmount = await UserTx2Account.getBalance();
      const userWithdrawResponse = await MDC.connect(
        UserTx2Account,
      ).userWithDraw(userTx, lpInfo);
      const userWithdrawAfterAmount = await UserTx2Account.getBalance();
      const userWithdrawTx = await userWithdrawResponse.wait();
      const gasUsed = userWithdrawTx.cumulativeGasUsed.mul(
        userWithdrawTx.effectiveGasPrice,
      );
      const pledgeAmount = ethers.utils.parseEther('1');
      const ebc = await getORProtocalV1Contract();
      const ETHPunishAmount = await ebc.calculateCompensation(
        '0x0000000000000000000000000000000000000000',
        userTx.value,
      );
      const amount = ETHPunishAmount.baseValue
        .add(ETHPunishAmount.additiveValue)
        .add(pledgeAmount)
        .sub(gasUsed);
      expect(amount).eq(userWithdrawAfterAmount.sub(userWithdrawBeforeAmount));
      if (userWithdrawTx.events !== undefined) {
        const events = userWithdrawTx.events || [];
        const eventNames = events.map((e) => e.event);
        expect(eventNames).includes('LogLPUserStop');
        expect(eventNames).includes('LogChallengerCompensation');
      }
    });
    it('zero PledgeBalance', async () => {
      const result = await MDC.getPledgeBalance(
        '0x0000000000000000000000000000000000000000',
      );
      expect(result).eq(0);
    });
    it('zero effectivePairLP', async () => {
      const lps = DataInit.lps;
      for (const lp of [lps[0], lps[1]]) {
        const pairInfo = await MDC.effectivePair(lp.pairId);
        expect(pairInfo.lpId).eq(ethers.constants.HashZero);
      }
    });
    it('Maker withDraw all amount', async () => {
      await speedUpTime(3600 * 24);
      let beforeAmount = await makerAccount.getBalance();
      const idleAmountBefore = await MDC.idleAmount(
        '0x0000000000000000000000000000000000000000',
      );
      const response = await MDC.connect(makerAccount).withDrawAssert(
        idleAmountBefore,
        '0x0000000000000000000000000000000000000000',
      );
      const tx = await response.wait();
      const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
      const afterAmount = await makerAccount.getBalance();
      const idleAmountAfter = await MDC.idleAmount(
        '0x0000000000000000000000000000000000000000',
      );
      const mdcETHBalance = await ethers.provider.getBalance(MDC.address);
      beforeAmount = beforeAmount.add(idleAmountBefore).sub(gasUsed);
      expect(beforeAmount).eq(afterAmount);
      expect(idleAmountAfter).eq(0);
      expect(mdcETHBalance).eq(0);
    });
  });
});
