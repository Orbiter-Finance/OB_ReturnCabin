/* eslint-disable @typescript-eslint/ban-ts-comment */
import { ethers } from 'hardhat';
import { ORMakerDeposit } from '../typechain-types';
import { MerkleTree } from 'merkletreejs';
import { LP_LIST, MAKER_TX_LIST, TOKEN_LIST, USER_TX_LIST } from './lib/Config';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { PAIR_LIST } from './lib/Config';
import { expect } from 'chai';
import { getPairID, getPairLPID, getLeaf } from './lib/Utils';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { BigNumber } from 'ethers';
let mdc: ORMakerDeposit;
let supportPairTree: MerkleTree;
let owner: SignerWithAddress;
let maker: SignerWithAddress;
let UserTx1Account: SignerWithAddress;
let UserTx3Account: SignerWithAddress;
let lpInfoTree: MerkleTree;
let userTxTree: MerkleTree;
let makerTxTree: MerkleTree;
const { keccak256 } = ethers.utils;
const tokeninfo_eth_main = TOKEN_LIST[0];
let MakerPoolAddress: string;
let ORMakerV1FactoryAddress: string;
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    MakerPoolAddress = String(process.env['MDC']);
    ORMakerV1FactoryAddress = String(process.env['MDCFactory']);
    [owner, maker, UserTx1Account, UserTx3Account] = await ethers.getSigners();
    mdc = await ethers.getContractAt('ORMakerDeposit', MakerPoolAddress, owner);
    console.log('MDCFactory Address:', ORMakerV1FactoryAddress);
    console.log('MDC Address:', MakerPoolAddress);
    // tree
    supportPairTree = new MerkleTree(
      PAIR_LIST.map((row) => {
        return Buffer.from(row.id, 'hex');
      }),
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
  function getLpInfo(LPLIST: typeof LP_LIST[0]): typeof LP_LIST[0] {
    let lpInfo: any = LPLIST;
    const lpId = getPairLPID(lpInfo);
    const pairInfo = PAIR_LIST.find((item) => item.id == lpInfo.pairId);
    if (pairInfo !== undefined) {
      lpInfo = Object.assign(lpInfo, pairInfo);
      lpInfo.id = lpId;
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
    await ethers.provider.send('evm_mine', [timestampBefore + ms]);
  }
  it('Get MakerFactory', async () => {
    const result = await mdc.makerFactory();
    expect(result).equal(ORMakerV1FactoryAddress);
  });
  it('LPAction pledge ETH', async () => {
    lpInfoTree.addLeaf(Buffer.from(LP_LIST[0].id, 'hex'));
    lpInfoTree.addLeaf(Buffer.from(LP_LIST[1].id, 'hex'));
    const lpInfo = getLpInfo(LP_LIST[0]);
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
      .LPAction([lpInfo] as any, pairProof, overrides);
    await expect(response)
      .to.emit(mdc, 'LogLpAction')
      .withArgs(anyValue, anyValue, anyValue);
    const { events } = await response.wait();
    const LogLpInfo = events?.find((ev) => ev.event == 'LogLpAction');
    if (LogLpInfo) {
      const args = LogLpInfo.args[2];
      lpInfo.startTime = Number(args.startTime);
    }
    const chainDeposit = await mdc.chainDeposit(
      lpInfo.sourceChain,
      lpInfo.sourceTAddress,
    );
    expect(chainDeposit.useLimit).equal(ethers.BigNumber.from(1));
    expect(chainDeposit.tokenAddress).equal(lpInfo.sourceTAddress);
  });
  it('LPPause', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const response = await mdc.connect(maker).LPPause([lpInfo]);
    await expect(response)
      .to.emit(mdc, 'LogLPPause')
      .withArgs(anyValue, anyValue, anyValue);
  });
  it('LPUpdate', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    expect(lpInfo).not.empty;
    const pid = `0x${lpInfo.pairId}`;
    const lpid = `0x${lpInfo.id}`;
    const updateData = {
      tradingFee: BigNumber.from(0.0005 * 10 ** 18),
      gasFee: lpInfo.gasFee,
    };
    const response = await mdc.connect(maker).LPUpdate([
      {
        pid: `0x${lpInfo.pairId}`,
        lpid: `0x${lpInfo.id}`,
        ...updateData,
      },
    ]);
    await expect(response)
      .to.emit(mdc, 'LogLpUpdate')
      .withArgs(pid, lpid, updateData.gasFee, updateData.tradingFee);
  });
  it('LPRestart', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const pid = `0x${lpInfo.pairId}`;
    const lpid = `0x${lpInfo.id}`;
    const response = await mdc.connect(maker).LPRestart([{ pid, lpid }]);
    await expect(response).to.emit(mdc, 'LogLpRestart').withArgs(pid, lpid);
  });
  it('LPRestart After Pause', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const response = await mdc.connect(maker).LPPause([lpInfo]);
    await expect(response)
      .to.emit(mdc, 'LogLPPause')
      .withArgs(anyValue, anyValue, anyValue);
  });
  it('LPStop not time', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const response = mdc.connect(maker).LPStop([lpInfo]);
    await expect(response).to.be.revertedWith('LPSTOP_LPID_TIMEUNABLE');
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('LPStop is time', async () => {
    const lpInfo = getLpInfo(LP_LIST[0]);
    const response = await mdc.connect(maker).LPStop([lpInfo]);
    await expect(response)
      .to.emit(mdc, 'LogLPStop')
      .withArgs(anyValue, anyValue, anyValue);
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
    const value = ethers.utils.parseEther('2.1');
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
      .LPAction([lpInfo], pairProof, overrides);
    await expect(response)
      .to.emit(mdc, 'LogLpAction')
      .withArgs(anyValue, anyValue, anyValue);
    const chainDeposit = await mdc.chainDeposit(
      lpInfo.sourceChain,
      lpInfo.sourceTAddress,
    );
    expect(chainDeposit.useLimit).equal(ethers.BigNumber.from(1));
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
      .withArgs(anyValue, 0, anyValue, anyValue, anyValue);
  });
  it('userChanllenge for maker already send', async () => {
    // User
    const { leaf: userLeaf, hex: userHex } = getLeaf(USER_TX_LIST[4], true);
    const userProof = userTxTree.getHexProof(userHex);
    const overrides = {
      value: ethers.utils.parseEther('1'),
    };
    const userResponse = await mdc
      .connect(UserTx1Account)
      .userChanllenge(userLeaf, userProof, overrides);
    await expect(userResponse)
      .to.emit(mdc, 'LogChanllengeInfo')
      .withArgs(anyValue, 0, anyValue, anyValue, anyValue);
    // Maker
    const { leaf: makerLeaf, hex: makerHex } = getLeaf(MAKER_TX_LIST[2], false);
    const makerProof = makerTxTree.getHexProof(makerHex);
    const makerResponce = await mdc
      .connect(maker)
      .makerChanllenger(userLeaf, makerLeaf, makerProof);
    await expect(makerResponce)
      .to.emit(mdc, 'LogChanllengeInfo')
      .withArgs(anyValue, 1, anyValue, anyValue, anyValue);
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
  // it('User Withdrawal in failure of UserChallenge', async () => {
  //   const lpInfo = getLpInfo(LP_LIST[0]);
  //   const { leaf: userLeaf } = getLeaf(USER_TX_LIST[4], true);
  //   const response = mdc.connect(UserTx3Account).userWithDraw(userLeaf, lpInfo);
  //   await expect(response).to.be.revertedWith('UW_WITHDRAW');
  // });
  it('LPAction again (Second time)', async () => {
    const lpInfo = getLpInfo(LP_LIST[1]);
    const value = ethers.utils.parseEther('0.9');
    const pairProofLeavesHash = [PAIR_LIST[1]].map((row) => {
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
      .LPAction([lpInfo], pairProof, overrides);
    await expect(response)
      .to.emit(mdc, 'LogLpAction')
      .withArgs(anyValue, anyValue, anyValue);
    const chainDeposit = await mdc.chainDeposit(
      lpInfo.sourceChain,
      lpInfo.sourceTAddress,
    );
    expect(chainDeposit.useLimit).equal(ethers.BigNumber.from(2));
    expect(chainDeposit.tokenAddress).equal(lpInfo.sourceTAddress);
  });
  it('userChanllenge for maker not send (Second time)', async () => {
    const { leaf, hex } = getLeaf(USER_TX_LIST[1], true);
    const txProof = userTxTree.getHexProof(hex);
    const overrides = {
      value: ethers.utils.parseEther('1'),
    };
    const response = await mdc
      .connect(UserTx1Account)
      .userChanllenge(leaf, txProof, overrides);
    await expect(response)
      .to.emit(mdc, 'LogChanllengeInfo')
      .withArgs(anyValue, 0, anyValue, anyValue, anyValue);
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
  });
  it('User Withdrawal under successful UserChallenge (Second time and USER_LP_STOP)', async () => {
    const lpInfo = getLpInfo(LP_LIST[1]);
    const { leaf: userLeaf } = getLeaf(USER_TX_LIST[1], true);
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
    const withDrawMax = await mdc
      .connect(maker)
      .idleAmount(tokeninfo_eth_main.mainAddress);
    const response = mdc
      .connect(maker)
      .withDrawAssert(withDrawMax, tokeninfo_eth_main.mainAddress);
    await expect(response).to.be.revertedWith('WITHDRAW_NOTIME');
  });
  it('After a day of simulation', async () => {
    await speedUpTime(3600 * 24);
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
