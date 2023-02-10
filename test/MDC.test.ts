/* eslint-disable @typescript-eslint/ban-ts-comment */
import { ethers } from 'hardhat';
import { ORMakerDeposit } from '../typechain-types';
import { expect } from 'chai';
import {
  DataInit,
  getORMakerDepositContract,
  getORMakerV1FactoryContract,
  getSPVProof,
} from './utils.test';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
let MDC: ORMakerDeposit;
let makerAccount: SignerWithAddress;
let UserTx1Account: SignerWithAddress;
let UserTx2Account: SignerWithAddress;
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    // init lp list
    MDC = await getORMakerDepositContract();
    const accounts = await ethers.getSigners();
    makerAccount = accounts[1];
    UserTx1Account = accounts[accounts.length - 1];
    UserTx2Account = accounts[accounts.length - 2];
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
      console.log('idleAmountAfter: ', idleAmountAfter);
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
    it('userChallenge for maker already send', async () => {
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
      ).makerChallenger(userTx, makerTxBytes as Buffer, { gasLimit: 29000000 });
      await makerChallengeResponse.wait();
      await expect(makerChallengeResponse)
        .to.emit(MDC, 'LogChallengeInfo')
        .withArgs(anyValue, anyValue, anyValue, anyValue);
    });
    it('userChallenge for maker no send', async () => {
      const userTx = DataInit.userTxList[1];
      const userTxBytes = await getSPVProof(userTx.chainId, userTx.txHash);
      const beforeAmount = await UserTx2Account.getBalance();
      const overrides = {
        value: ethers.utils.parseEther('1'), //>=0.05 ether
      };
      const response = await MDC.connect(UserTx2Account).userChallenge(
        userTxBytes as Buffer,
        overrides,
      );
      const tx = await response.wait();
      const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
      const afterAmount = await UserTx2Account.getBalance();
      expect(afterAmount).eq(beforeAmount.sub(overrides.value).sub(gasUsed));
      await expect(response)
        .to.emit(MDC, 'LogChallengeInfo')
        .withArgs(anyValue, anyValue, anyValue, anyValue);
    });
  });
});
