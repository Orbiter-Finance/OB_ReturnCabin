/* eslint-disable @typescript-eslint/ban-ts-comment */
import { ethers } from 'hardhat';
import { ORMakerDeposit } from '../typechain-types';
import { expect } from 'chai';
import {
  DataInit,
  getORMakerDepositContract,
  getORMakerV1FactoryContract,
} from './utils.test';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
let MDC: ORMakerDeposit;
let makerAccount: SignerWithAddress;
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    // init lp list
    MDC = await getORMakerDepositContract();
    const accounts = await ethers.getSigners();
    makerAccount = accounts[1];
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
  it('Calculation of pledge quantity', async () => {
    const result = await MDC.calculatePledgeAmount(DataInit.lps);
    const totalPledgeValue = result.totalPledgeValue;
    await expect(totalPledgeValue).gt(0);
  });
  // it('Test1', async () => {
  //   const lps = DataInit.lps;
  //   console.log('test1--------------------------------');
  //   for (const lp of [lps[0], lps[1], lps[2]]) {
  //     const lpId = await MDC.getLpId({
  //       pairId: lp.pairId,
  //       minPrice: lp.minPrice,
  //       maxPrice: lp.maxPrice,
  //       gasFee: lp.gasFee,
  //       tradingFee: lp.tradingFee,
  //       startTime: 0,
  //     });
  //     makerLPTree.addLeaf(lpId);
  //   }
  //   const leaves = makerLPTree.getHexLeaves();
  //   console.log(leaves, '===leaves')
  //   const lastLeaf = leaves[leaves.length - 1];
  //   console.log(lastLeaf, '==lastLeaf')
  //   const proof = makerLPTree.getHexProof(lastLeaf);
  //   console.log(proof, '==getHexProof');
  //   const isVeify = makerLPTree.verify(
  //     proof,
  //     lastLeaf,
  //     makerLPTree.getHexRoot(),
  //   );
  //   console.log(makerLPTree.toString(), '===makerLPTree', isVeify);
  // });
  // it('Test2', async () => {
  describe('Action LP', () => {
    let calcResult: any;
    // let totalPledgeValue = ethers.BigNumber.from(0);
    it('LPAction pledge ETH', async () => {
      const lps = DataInit.lps;
      // const result = await MDC.calculatePledgeAmount(DataInit.lps);
      const addLps = [lps[0], lps[1]].map((row) => {
        return {
          pairId: row.pairId,
          minPrice: row.minPrice,
          maxPrice: row.maxPrice,
          gasFee: row.gasFee,
          tradingFee: row.tradingFee,
        };
      });
      // calculatePledgeAmount
      calcResult = await MDC.calculatePledgeAmount(addLps);
      await expect(
        MDC.connect(makerAccount).lpAction(addLps),
      ).to.be.revertedWith('Insufficient pledge quantity');
      const tx = await MDC.connect(makerAccount).lpAction(addLps, {
        value: calcResult.totalPledgeValue,
      });
      await tx.wait();
    });
    it('getPairsByPledgeToken', async () => {
      const result = await MDC.getPairsByPledgeToken(
        '0x0000000000000000000000000000000000000000',
      );
      const lps = DataInit.lps;
      expect(result.length).eq(2);
      expect(result[0]).eq(lps[0].pairId);
      expect(result[1]).eq(lps[1].pairId);
    });
    it('getPledgeBalance', async () => {
      const result = await MDC.getPledgeBalance(
        '0x0000000000000000000000000000000000000000',
      );
      const mdcETHBalance = await ethers.provider.getBalance(MDC.address);
      expect(mdcETHBalance).eq(calcResult.totalPledgeValue);
      expect(result).eq(calcResult.totalPledgeValue);
    });

    it('getPledgeBalanceByChainToken', async () => {
      for (const item of calcResult.pledgeListData) {
        const result = await MDC.getPledgeBalanceByChainToken(
          item.chainId,
          '0x0000000000000000000000000000000000000000',
        );
        expect(item.pledgeValue).eq(result);
      }
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
    it('idleAmount', async () => {
      const result = await MDC.idleAmount(
        '0x0000000000000000000000000000000000000000',
      );
      expect(result).eq(0);
    });
    it('LPAction pledge ETH（Pair already exists）', async () => {
      const lps = DataInit.lps;
      await expect(
        MDC.connect(makerAccount).lpAction(
          [
            {
              pairId: lps[0].pairId,
              minPrice: lps[0].minPrice,
              maxPrice: lps[0].maxPrice,
              gasFee: lps[0].gasFee,
              tradingFee: lps[0].tradingFee,
            },
          ],
          {
            value: calcResult.totalPledgeValue,
          },
        ),
      ).to.be.revertedWith('Pair already exists');
    });
    it('LP Pause', async () => {
      const lps = DataInit.lps;
      const pause1Tx = await MDC.connect(makerAccount).lpPause([lps[1].pairId]);
      await pause1Tx.wait();
      const effectivePair = await MDC.effectivePair(lps[1].pairId);
      expect(effectivePair.lpId).not.empty;
      expect(effectivePair.startTime).eq(0);
      expect(effectivePair.stopTime).gt(0);
    });
  });
});
