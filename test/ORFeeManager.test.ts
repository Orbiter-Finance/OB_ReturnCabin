import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';

import { defaultAbiCoder, keccak256 } from 'ethers/lib/utils';
import {
  ORFeeManager,
  ORFeeManager__factory,
  ORManager,
  ORManager__factory,
  Verifier,
  Verifier__factory,
} from '../typechain-types';
import { log } from 'console';
import {
  SubmitInfo,
  SubmitInfoMock,
  dealersSignersMock,
  getCurrentTime,
  initTestToken,
  submitterMock,
} from './lib/mockData';

describe('ORFeeManger', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orFeeManager: ORFeeManager;
  let dealerSinger: SignerWithAddress;
  let verifier: Verifier;
  let feeMangerOwner: string;
  let DEALER_WITHDRAW_DELAY: number;
  let WITHDRAW_DURATION: number;
  let LOCK_DURATION: number;
  const secondsInMinute = 60;

  before(async function () {
    initTestToken();
    signers = await ethers.getSigners();
    dealerSinger = signers[2];
    feeMangerOwner = signers[0].address;
    DEALER_WITHDRAW_DELAY = 3600;
    WITHDRAW_DURATION = 3360;
    LOCK_DURATION = 240;

    const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
    assert(
      !!envORManagerAddress,
      'Env miss [OR_MANAGER_ADDRESS]. You may need to test ORManager.test.ts first. Example: npx hardhat test test/ORManager.test test/ORFeeManager.test.ts',
    );

    orManager = new ORManager__factory(signers[0]).attach(envORManagerAddress);
    await orManager.deployed();

    verifier = await new Verifier__factory(signers[0]).deploy();

    if (process.env['OR_FEE_MANAGER_ADDRESS'] != undefined) {
      orFeeManager = new ORFeeManager__factory(signers[1]).attach(
        process.env['OR_FEE_MANAGER_ADDRESS'],
      );
    } else {
      orFeeManager = await new ORFeeManager__factory(signers[0]).deploy(
        signers[0].address,
        orManager.address,
        verifier.address,
      );
      process.env['OR_FEE_MANAGER_ADDRESS'] = orFeeManager.address;
    }

    console.log('Address of orFeeManager:', orFeeManager.address);
    // await orFeeManager.deployed();
  });

  // it("transferOwnership should succeed", async function () {
  //   await orFeeManager
  //     .connect(signers[1])
  //     .transferOwnership(feeMangerOwner);

  //   const newOwner = await orFeeManager.owner();
  //   expect(newOwner).eq(feeMangerOwner);

  // });

  it("ORFeeManager's functions prefixed with _ should be private", async function () {
    for (const key in orFeeManager.functions) {
      expect(key.replace(/^_/, '')).eq(key);
    }
  });

  it('Function updateDealer should emit events and update dealerInfo', async function () {
    const feeRatio = BigNumber.from(1000);
    const extraInfoTypes = ['string', 'string'];
    const extraInfoValues = ['https://orbiter.finance/', '@Orbiter_Finance'];
    const extraInfo = defaultAbiCoder.encode(extraInfoTypes, extraInfoValues);

    let dealersigners: SignerWithAddress[];
    dealersigners = await dealersSignersMock();

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

  async function registerSubmitter() {
    const submitter = await submitterMock();
    const marginAmount = BigNumber.from(1000);
    await orFeeManager.registerSubmitter(marginAmount, submitter);
  }

  async function submit() {
    const submitInfo: SubmitInfo = await SubmitInfoMock();
    let events;
    events = await orFeeManager
      .submit(
        submitInfo.stratBlock,
        submitInfo.endBlock,
        submitInfo.profitRoot,
        submitInfo.stateTransTreeRoot,
      )
      .then((t) => t.wait());
    return events;
  }

  const durationStatus: { [key: number]: string } = {
    0: 'lock',
    1: 'challenge',
    2: 'withdraw',
  };

  enum durationStatusEnum {
    lock = 0,
    challenge = 1,
    withdraw = 2,
  }

  async function durationCheck() {
    const feeMnagerDuration = await orFeeManager.durationCheck();
    console.log(
      'Current Duration:',
      durationStatus[feeMnagerDuration],
      ', Current time:',
      await getCurrentTime(),
    );
    return feeMnagerDuration;
  }

  it('registerSubmitter should succeed', async function () {
    await registerSubmitter();
    expect(await orFeeManager.submitter(await submitterMock())).eq(
      BigNumber.from(1000),
    );
  });

  // it("mine to test should succeed", async function () {
  //     expect(await durationCheck()).eq(durationStatusEnum["challenge"]);
  //     await registerSubmitter();
  //     await mineXMinutes(DEALER_WITHDRAW_DELAY/secondsInMinute);
  //     expect(await durationCheck()).eq(durationStatusEnum["withdraw"]);
  //     await mineXMinutes(WITHDRAW_DURATION/secondsInMinute);
  //     expect(await durationCheck()).eq(durationStatusEnum["lock"]);
  //     const receipt = await submit();
  //     const events = receipt.events ?? [];
  //     const args = events[0]?.args ?? {};
  //     const submissions = await orFeeManager.submissions();
  //     // console.log(args);
  //     expect(submissions.profitRoot).eq(profitRootMock);
  //     expect(submissions.stateTransTreeRoot).eq(stateTransTreeRootMock);

  //     expect(await durationCheck()).eq(durationStatusEnum["challenge"]);
  //     await mineXMinutes(DEALER_WITHDRAW_DELAY/secondsInMinute + 1);
  //     expect(await durationCheck()).eq(durationStatusEnum["withdraw"]);
  //     await mineXMinutes(WITHDRAW_DURATION/secondsInMinute);
  //     expect(await durationCheck()).eq(durationStatusEnum["lock"]);
  //     await mineXMinutes(DEALER_WITHDRAW_DELAY/secondsInMinute -10);
  //     expect(await durationCheck()).eq(durationStatusEnum["withdraw"]);
  //   });

  // it("verify should succeed", async function () {
  //   const durationStatus = await durationCheck()

  //   if(durationStatus == durationStatusEnum["withdraw"]){
  //     const submissions = await orFeeManager.submissions();
  //     console.log("submissions:", submissions);

  //     const smtLeaf: SMTLeaf = smtLeavesMock;
  //     const siblings: MergeValue[][] = [[mergeValueMock]];

  //     const bitmap: Bytes = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('bitmap')) as unknown as Bytes

  //     const tx = await orFeeManager.withdrawVerification([smtLeaf], siblings, bitmap);
  //     // console.log("tx:", tx);
  //   }else{
  //     console.warn("not in withdrawDuration")
  //   }

  // });
});
