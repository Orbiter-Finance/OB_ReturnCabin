/* eslint-disable prettier/prettier */
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumber, utils } from 'ethers';
import { ethers } from 'hardhat';
import fs from 'fs';
import { defaultAbiCoder, keccak256 } from 'ethers/lib/utils';
import {
  ORFeeManager,
  ORFeeManager__factory,
  ORManager,
  ORManager__factory,
  TestToken,
  TestToken__factory,
  Verifier,
  Verifier__factory,
} from '../typechain-types';
import { log } from 'console';

import {
  MergeValue,
  SMTLeaf,
  SubmitInfo,
  SubmitInfoMock,
  callDataCost,
  dealersSignersMock,
  initTestToken,
  mineXMinutes,
  stateTransTreeRootMock,
  submitterMock,
  submitter_getProfitProof,
} from './lib/mockData';


const tokensRequestList: string[] = [
  '0xa0321efEb50c46C17A7D72A52024eeA7221b215A',
  '0xA3a8A6b323E3d38f5284db9337e7c6d74Af3366a',
  '0x29B6a77911c1ce3B3849f28721C65DadA015c768'];
const userAddress = '0xc3C7A782dda00a8E61Cb9Ba0ea8680bb3f3B9d10';

enum MergeValueType {
  VALUE = 0,
  MERGE_WITH_ZERO,
  SHORT_CUT,
}

// interface ISiblings {
//   mergeType: number;
//   mergeValue: object;
// }
type Bitmaps = string[];

type WithdrawAmount = BigNumber[];

type StartIndex = number[];

type FirstZeroBits = string[];

interface IMergeWithZero {
  MergeWithZero: {
    base_node: string;
    zero_bits: string;
    zero_count: number;
  };
}

interface IValue {
  Value: string;
}

interface IShortCut {
  height: string;
  key: string;
  value: string;
}

export interface IProofItem {
  leave_bitmap: string;
  no1_merge_value: [number, string];
  path: string;
  siblings: Array<IMergeWithZero & IValue & IShortCut>;
  root: string;
  token: {
    balance: string;
    debt: string;
    token: string;
    token_chain_id: number;
  };
}

interface withdrawVerification {
  smtLeaf: SMTLeaf[];
  siblings: MergeValue[][];
  startIndex: number[];
  firstZeroBits: string[];
  bitmaps: string[];
  withdrawAmount: BigNumber[];
}

const getWithDrawParams = (result: IProofItem[]) => {
  const smtLeaves: SMTLeaf[] = [];
  const siblings: MergeValue[][] = [];
  const bitmaps: Bitmaps = [];
  const withdrawAmount: WithdrawAmount = [];
  const startIndex: StartIndex = [];
  const firstZeroBits: FirstZeroBits = [];
  const root: string[] = [];

  result.forEach((v) => {
    const cSiblings = v.siblings;
    const cToken = v.token;
    const cBitmap = v.leave_bitmap;
    const cRoot = v.root;
    smtLeaves.push({
      key: {
        chainId: BigNumber.from(cToken.token_chain_id),
        token: cToken.token,
        user: userAddress,
      },
      value: {
        token: cToken.token,
        chainId: BigNumber.from(cToken.token_chain_id),
        amount: BigNumber.from(cToken.balance),
        debt: BigNumber.from(cToken.debt),
      },
    });
    const vSiblings: MergeValue[] = [];
    cSiblings.forEach((s) => {
      const mergeType = !!s.MergeWithZero
        ? MergeValueType.MERGE_WITH_ZERO
        : !!s.Value
          ? MergeValueType.VALUE
          : MergeValueType.SHORT_CUT;
      const mergeValue = !!s.MergeWithZero
        ? {
          value1: s.MergeWithZero.zero_count,
          value2: '0x' + s.MergeWithZero.base_node,
          value3: '0x' + s.MergeWithZero.zero_bits,
        }
        : {
          value1: 0,
          value2: '0x' + s.Value,
          value3:
            '0x0000000000000000000000000000000000000000000000000000000000000000',
        };
      vSiblings.push({
        mergeType: mergeType,
        mergeValue: {
          value1: mergeValue.value1,
          value2: utils.arrayify(mergeValue.value2),
          value3: utils.arrayify(mergeValue.value3),
        },
      });
    });
    siblings.push(vSiblings);
    startIndex.push(v.no1_merge_value[0]);
    firstZeroBits.push('0x' + v.no1_merge_value[1]);
    bitmaps.push('0x' + cBitmap);
    root.push('0x' + cRoot);
    withdrawAmount.push(BigNumber.from(cToken.balance));
  });

  return {
    smtLeaves,
    siblings,
    startIndex,
    firstZeroBits,
    bitmaps,
    root,
    withdrawAmount,
  };
};

describe('Test RPC', () => {
  it('should communicate with the external RPC and parse JSON data', async () => {
    if (process.env['SUBMITTER_RPC'] != undefined) {
      const tokenArray: [number, string][] = [];
      for (let i = 0; i < tokensRequestList.length; i++) {
        tokenArray.push([5, tokensRequestList[i]]);
      }
      await submitter_getProfitProof(tokenArray, userAddress);
    }
  });
});

describe.skip('format RPC json data', () => {
  let proof: withdrawVerification;
  let profitRoot: string;
  before(async function () {
    const fileData = fs.readFileSync('test/RPC_DATA/response.json', 'utf-8');
    const parsedData = JSON.parse(fileData);
    console.log(parsedData.result);
    try {
      const {
        smtLeaves,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        root,
        withdrawAmount,
      } = getWithDrawParams(parsedData.result);
      proof = {
        smtLeaf: smtLeaves,
        siblings: siblings,
        startIndex: startIndex,
        firstZeroBits: firstZeroBits,
        bitmaps: bitmaps,
        withdrawAmount: withdrawAmount,
      };
      profitRoot = root[0];
    } catch (err) {
      const fileData = fs.readFileSync('test/RPC_DATA/test.json', 'utf-8');
      const parsedData = JSON.parse(fileData);
      console.log(`use test data: ${parsedData.result}`);
      const {
        smtLeaves,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        root,
        withdrawAmount,
      } = getWithDrawParams(parsedData.result);
      proof = {
        smtLeaf: smtLeaves,
        siblings: siblings,
        startIndex: startIndex,
        firstZeroBits: firstZeroBits,
        bitmaps: bitmaps,
        withdrawAmount: withdrawAmount,
      };
      profitRoot = root[0];
    }



  });

  it('should format JSON data', async () => {
    // console.log(`proof: ${JSON.stringify(proof)}`);
    console.log(proof, profitRoot);
  });
});

describe('test ORFeeManager MerkleVerify', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orFeeManager: ORFeeManager;
  // let dealerSinger: SignerWithAddress;
  let verifier: Verifier;
  // let feeMangerOwner: string;
  let DEALER_WITHDRAW_DELAY: number;
  let WITHDRAW_DURATION: number;
  let LOCK_DURATION: number;
  const secondsInMinute = 60;
  let challengeTime: number;
  let withdrawTime: number;
  let lockTime: number;
  // let testRootIndex: number;
  let proof: withdrawVerification;
  let profitRoot: string;

  before(async function () {
    initTestToken();
    signers = await ethers.getSigners();
    // dealerSinger = signers[2];
    // feeMangerOwner = signers[0].address;
    DEALER_WITHDRAW_DELAY = 3600;
    WITHDRAW_DURATION = 3360;
    LOCK_DURATION = 240;
    // testRootIndex = 4;

    challengeTime = DEALER_WITHDRAW_DELAY / secondsInMinute;
    withdrawTime = WITHDRAW_DURATION / secondsInMinute;
    lockTime = LOCK_DURATION / secondsInMinute;

    const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
    assert(
      !!envORManagerAddress,
      'Env miss [OR_MANAGER_ADDRESS]. You may need to test ORManager.test.ts first. Example: npx hardhat test test/ORManager.test test/ORFeeManager.test.ts',
    );

    const envSubmitterRpc = process.env['SUBMITTER_RPC'];
    assert(
      !!envSubmitterRpc,
      'Env miss [SUBMITTER_RPC]. You may need to add a RPC node in .env file. Example: SUBMITTER_RPC= http://127.0.0.1:8545',
    );

    const envOFeeRManagerAddress = process.env['OR_FEE_MANAGER_ADDRESS'];
    assert(
      !!envOFeeRManagerAddress,
      'Env miss [OR_FEE_MANAGER_ADDRESS]. You may need to test ORManager.test.ts first. Example: npx hardhat test --bail test/ORManager.test test/ORFeeManager.test test/ORFeeManagerMerkleVerify.test.ts',
    );

    orManager = new ORManager__factory(signers[0]).attach(envORManagerAddress);
    await orManager.deployed();

    verifier = await new Verifier__factory(signers[0]).deploy();

    if (process.env['OR_FEE_MANAGER_ADDRESS'] != undefined) {
      orFeeManager = new ORFeeManager__factory(signers[0]).attach(
        process.env['OR_FEE_MANAGER_ADDRESS'],
      );
      console.log('connected to orFeeManager:', orFeeManager.address);
    } else {
      orFeeManager = await new ORFeeManager__factory(signers[0]).deploy(
        signers[1].address,
        orManager.address,
        verifier.address,
      );
      console.log('Address of orFeeManager:', orFeeManager.address);
      await orFeeManager.deployed();
    }

    const testToken: TestToken = await new TestToken__factory(
      signers[0],
    ).deploy('TestToken', 'OTT');
    console.log('Address of testToken:', testToken.address);

    const fileData = fs.readFileSync('test/RPC_DATA/response.json', 'utf-8');
    const parsedData = JSON.parse(fileData);

    try {
      const {
        smtLeaves,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        root,
        withdrawAmount,
      } = getWithDrawParams(parsedData.result);
      proof = {
        smtLeaf: smtLeaves,
        siblings: siblings,
        startIndex: startIndex,
        firstZeroBits: firstZeroBits,
        bitmaps: bitmaps,
        withdrawAmount: withdrawAmount,
      };
      profitRoot = root[0];
      console.log(`use RPC data: ${parsedData.result}`);
    } catch (err) {
      const fileData = fs.readFileSync('test/RPC_DATA/test.json', 'utf-8');
      const parsedData = JSON.parse(fileData);

      const {
        smtLeaves,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        root,
        withdrawAmount,
      } = getWithDrawParams(parsedData.result);
      proof = {
        smtLeaf: smtLeaves,
        siblings: siblings,
        startIndex: startIndex,
        firstZeroBits: firstZeroBits,
        bitmaps: bitmaps,
        withdrawAmount: withdrawAmount,
      };
      profitRoot = root[0];
      console.log(`use test data: ${parsedData.result}`);
    }
  });

  it('should format JSON data', async () => {
    // console.log(`proof: ${JSON.stringify(proof)}`);
    console.log(proof);
  });

  it("ORFeeManager's functions prefixed with _ should be private", async function () {
    for (const key in orFeeManager.functions) {
      expect(key.replace(/^_/, '')).eq(key);
    }
  });

  it('withdraw during initail state', async function () {
    const smtLeaf = proof.smtLeaf;
    const siblings = proof.siblings;
    const bitmaps = proof.bitmaps;
    const withdrawAmount: BigNumber[] = [];
    for (let i = 0; i < smtLeaf.length; i++) {
      withdrawAmount.push(smtLeaf[i].value.amount);
    }
    const startIndex = proof.startIndex;
    const firstZeroBits = proof.firstZeroBits;
    await gotoDuration(durationStatusEnum['lock']);
    await expect(orFeeManager
      .withdrawVerification(
        smtLeaf,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        withdrawAmount,
        {
          gasLimit: 10000000,
        },
      )).to.revertedWith('WE')
    await gotoDuration(durationStatusEnum['withdraw']);
    const submissions = await orFeeManager.submissions();
    // console.log(submissions);
    await expect(orFeeManager
      .withdrawVerification(
        smtLeaf,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        withdrawAmount,
        {
          gasLimit: 10000000,
        },
      )).to.revertedWith('WL')


  });

  it('Function updateDealer should emit events and update dealerInfo', async function () {
    const feeRatio = BigNumber.from(1000);
    const extraInfoTypes = ['string', 'string'];
    const extraInfoValues = ['https://orbiter.finance/', '@Orbiter_Finance'];
    const extraInfo = defaultAbiCoder.encode(extraInfoTypes, extraInfoValues);

    const dealersigners: SignerWithAddress[] = await dealersSignersMock();

    await Promise.all(
      dealersigners.map(async (dealersigner) => {
        const { events } = await orFeeManager
          .connect(dealersigner)
          .updateDealer(feeRatio, extraInfo)
          .then((t) => t.wait());

        const args = events?.[0].args;
        expect(args?.dealer).eq(dealersigner.address);
        expect(args?.feeRatio).eq(feeRatio);
        expect(args?.extraInfo).eq(extraInfo);

        const dealerInfo = await orFeeManager.getDealerInfo(
          dealersigner.address,
        );
        log('Address of dealer:', dealersigner.address);
        expect(dealerInfo.feeRatio).eq(feeRatio);
        expect(dealerInfo.extraInfoHash).eq(keccak256(extraInfo));
      }),
    );
  });

  async function registerSubmitter(marginAmount: BigNumber) {
    const submitter = await submitterMock();
    // const marginAmount = BigNumber.from(1000);
    await orFeeManager.registerSubmitter(marginAmount, submitter);
  }

  async function submit(profitRoot: string) {
    const submitInfo: SubmitInfo = await SubmitInfoMock();
    const submissions = await orFeeManager.submissions();
    submitInfo.profitRoot = profitRoot;
    submitInfo.stratBlock = submissions.endBlock.toNumber();
    submitInfo.endBlock = submitInfo.stratBlock + 1;

    const events = await orFeeManager
      .submit(
        submitInfo.stratBlock,
        submitInfo.endBlock,
        submitInfo.profitRoot,
        submitInfo.stateTransTreeRoot,
      )
      .then((t) => t.wait());
    return events;
  }

  // const durationStatus: { [key: number]: string } = {
  //   0: 'lock',
  //   1: 'challenge',
  //   2: 'withdraw',
  // };

  enum durationStatusEnum {
    lock = 0,
    challenge = 1,
    withdraw = 2,
  }

  async function durationCheck() {
    const feeMnagerDuration = await orFeeManager.durationCheck();
    // console.log(
    //   'Current Duration:',
    //   durationStatus[feeMnagerDuration],
    //   ', Current time:',
    //   await getCurrentTime(),
    // );
    return feeMnagerDuration;
  }

  async function withdraw(
    smtLeaf: SMTLeaf[],
    siblings: MergeValue[][],
    startIndex: StartIndex,
    firstZeroBits: string[],
    bitmaps: string[],
    withdrawAmount: WithdrawAmount,
    loop: number,
  ) {
    const tx = await orFeeManager
      .withdrawVerification(
        smtLeaf,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        withdrawAmount,
        {
          gasLimit: 10000000,
        },
      )
      .then((t) => t.wait());
    // const gasPrice = 20;
    // const ethused = tx.gasUsed.mul(gasPrice);
    // const ethAmount = ethers.utils.formatEther(ethused);
    const txrc = await ethers.provider.getTransaction(tx.transactionHash);
    const inpudataGas = callDataCost(txrc.data);
    console.log(
      `loop: [${loop + 1}]-withdraw gas used: ${tx.gasUsed}, input data gas: ${inpudataGas}`,
    );
  }

  async function gotoDuration(
    duration: durationStatusEnum,
  ) {
    if ((await durationCheck()) != duration) {
      while (1) {
        await mineXMinutes(3);
        if ((await durationCheck()) == duration) {
          break;
        }
      }
    }
  }

  it('submitter register statues should manually set by feeManager owner', async function () {
    const marginAmount = BigNumber.from(1000);

    await registerSubmitter(marginAmount);
    expect(await orFeeManager.submitter(await submitterMock())).eq(
      marginAmount,
    )
    await gotoDuration(durationStatusEnum['lock']);
    expect(orFeeManager
      .submit(
        0,
        1,
        keccak256(orFeeManager.address),
        keccak256(orFeeManager.address),
      )
    ).to.be.satisfy
    await gotoDuration(durationStatusEnum['withdraw']);
    await expect(orFeeManager
      .submit(
        10000,
        1,
        keccak256(orFeeManager.address),
        keccak256(orFeeManager.address),
      )
    ).to.revertedWith('NL2')

    await gotoDuration(durationStatusEnum['withdraw']);
    await gotoDuration(durationStatusEnum['lock']);
    await expect(orFeeManager
      .submit(
        10000,
        1,
        keccak256(orFeeManager.address),
        keccak256(orFeeManager.address),
      )
    ).to.revertedWith('EB')
    await gotoDuration(durationStatusEnum['withdraw']);
    await gotoDuration(durationStatusEnum['lock']);
    await expect(orFeeManager
      .submit(
        0,
        1,
        keccak256(orFeeManager.address),
        keccak256(orFeeManager.address),
      )
    ).to.revertedWith('BE')

    const unregisterMarginAmount = BigNumber.from(0);
    await registerSubmitter(unregisterMarginAmount);
    expect(await orFeeManager.submitter(await submitterMock())).eq(
      unregisterMarginAmount,
    )
    await gotoDuration(durationStatusEnum['lock']);
    await expect(orFeeManager
      .submit(
        0,
        1,
        keccak256(orFeeManager.address),
        keccak256(orFeeManager.address),
      )
    ).to.revertedWith('NS')
  })

  it('mine to test should succeed', async function () {
    await registerSubmitter(BigNumber.from(1000));
    await gotoDuration(durationStatusEnum['lock']);

    await submit(profitRoot);
    // const events = receipt.events ?? [];
    // const args = events[0]?.args ?? {};
    // console.log(args);
    const submissions = await orFeeManager.submissions();
    // console.log(submissions);
    // const withdrawArg: withdrawVerification = withdrawArgSetting[testRootIndex];
    expect(submissions.profitRoot).eq(profitRoot);
    expect(submissions.stateTransTreeRoot).eq(stateTransTreeRootMock);

    expect(await durationCheck()).eq(durationStatusEnum['challenge']);
    await mineXMinutes(challengeTime + 1);
    expect(await durationCheck()).eq(durationStatusEnum['withdraw']);
    await mineXMinutes(withdrawTime);
    expect(await durationCheck()).eq(durationStatusEnum['lock']);
    await mineXMinutes(lockTime);
    expect(await durationCheck()).eq(durationStatusEnum['withdraw']);
    await mineXMinutes(withdrawTime);
    expect(await durationCheck()).eq(durationStatusEnum['lock']);
    await mineXMinutes(lockTime);
    expect(await durationCheck()).eq(durationStatusEnum['withdraw']);
    await mineXMinutes(withdrawTime);
    expect(await durationCheck()).eq(durationStatusEnum['lock']);
    await mineXMinutes(lockTime);
    expect(await durationCheck()).eq(durationStatusEnum['withdraw']);
    await mineXMinutes(withdrawTime);
    expect(await durationCheck()).eq(durationStatusEnum['lock']);
    await mineXMinutes(lockTime);
    expect(await durationCheck()).eq(durationStatusEnum['withdraw']);
    await mineXMinutes(withdrawTime);
    expect(await durationCheck()).eq(durationStatusEnum['lock']);
    await mineXMinutes(lockTime);
    expect(await durationCheck()).eq(durationStatusEnum['withdraw']);
  });

  it('verify should succeed', async function () {
    if ((await durationCheck()) != durationStatusEnum['withdraw']) {
      while (1) {
        await mineXMinutes(2);
        if ((await durationCheck()) == durationStatusEnum['withdraw']) {
          break;
        }
      }
    }

    const smtLeaf = proof.smtLeaf;
    const siblings = proof.siblings;
    const bitmaps = proof.bitmaps;
    const withdrawAmount: BigNumber[] = [];
    for (let i = 0; i < smtLeaf.length; i++) {
      withdrawAmount.push(smtLeaf[i].value.amount);
    }
    const startIndex = proof.startIndex;
    const firstZeroBits = proof.firstZeroBits;

    await gotoDuration(durationStatusEnum['withdraw']);
    console.log("estimateGas-withdrawVerification =",
      await orFeeManager
        .estimateGas
        .withdrawVerification(
          smtLeaf,
          siblings,
          startIndex,
          firstZeroBits,
          bitmaps,
          withdrawAmount,
          {
            gasLimit: 10000000,
          },
        ))

    // loop to test
    for (let i = 0; i < 5; i++) {
      await gotoDuration(durationStatusEnum['lock']);
      await expect(orFeeManager
        .withdrawVerification(
          smtLeaf,
          siblings,
          startIndex,
          firstZeroBits,
          bitmaps,
          withdrawAmount,
          {
            gasLimit: 10000000,
          },
        )).to.revertedWith('WE')
      await submit(profitRoot);
      await gotoDuration(durationStatusEnum['challenge']);
      await expect(orFeeManager
        .withdrawVerification(
          smtLeaf,
          siblings,
          startIndex,
          firstZeroBits,
          bitmaps,
          withdrawAmount,
          {
            gasLimit: 10000000,
          },
        )).to.revertedWith('WE')
      await gotoDuration(durationStatusEnum['withdraw']);
      await withdraw(
        smtLeaf,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        withdrawAmount,
        i
      )
      await expect(orFeeManager
        .withdrawVerification(
          smtLeaf,
          siblings,
          startIndex,
          firstZeroBits,
          bitmaps,
          withdrawAmount,
          {
            gasLimit: 10000000,
          },
        )).to.revertedWith('WL')
    }

    await gotoDuration(durationStatusEnum['withdraw']);
    await expect(orFeeManager
      .withdrawVerification(
        smtLeaf,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        withdrawAmount,
        {
          gasLimit: 10000000,
        },
      )).to.revertedWith('WL')
    await gotoDuration(durationStatusEnum['lock']);
    await expect(orFeeManager
      .withdrawVerification(
        smtLeaf,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        withdrawAmount,
        {
          gasLimit: 10000000,
        },
      )).to.revertedWith('WE')
    await gotoDuration(durationStatusEnum['withdraw']);
    await expect(orFeeManager
      .withdrawVerification(
        smtLeaf,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        withdrawAmount,
        {
          gasLimit: 10000000,
        },
      )).to.revertedWith('WL')

    await gotoDuration(durationStatusEnum['lock']);
    await submit(profitRoot);
    await gotoDuration(durationStatusEnum['withdraw']);
    expect(orFeeManager
      .withdrawVerification(
        smtLeaf,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        withdrawAmount,
        {
          gasLimit: 10000000,
        },
      )).to.be.satisfy

    await expect(orFeeManager
      .withdrawVerification(
        smtLeaf,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        withdrawAmount,
        {
          gasLimit: 10000000,
        },
      )).to.revertedWith('WL')

    await gotoDuration(durationStatusEnum['lock']);
    await submit(profitRoot);
    await gotoDuration(durationStatusEnum['withdraw']);
    smtLeaf[0].key.user = '0xA00000000000000000000000000000000000000A';
    await expect(orFeeManager
      .withdrawVerification(
        smtLeaf,
        siblings,
        startIndex,
        firstZeroBits,
        bitmaps,
        withdrawAmount,
        {
          gasLimit: 10000000,
        },
      )).to.revertedWith("NU")

  });
});
