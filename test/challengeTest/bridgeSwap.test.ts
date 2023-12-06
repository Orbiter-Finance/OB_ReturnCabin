import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumber, BigNumberish, constants, utils } from 'ethers';
import { ethers } from 'hardhat';
import fs from 'fs';

import {
  BytesLike,
  arrayify,
  defaultAbiCoder,
  keccak256,
  solidityPack,
} from 'ethers/lib/utils';
import lodash, { random } from 'lodash';
import { BaseTrie } from 'merkle-patricia-tree';
import {
  OREventBinding,
  OREventBinding__factory,
  ORMDCFactory,
  ORMDCFactory__factory,
  ORMakerDeposit,
  ORMakerDeposit__factory,
  ORManager,
  ORManager__factory,
  TestSpv,
  TestSpv__factory,
  TestToken,
  TestToken__factory,
  ORChallengeSpvMainnet2Era,
  ORChallengeSpvMainnet2Era__factory,
  ORSpvData,
  ORSpvData__factory,
  TestMakerDeposit__factory,
  TestMakerDeposit,
} from '../../typechain-types';
import { defaultChainInfo } from '../defaults';
import {
  RuleStruct,
  calculateRuleKey,
  calculateRulesTree,
  converRule,
  createMakerRule,
  createRandomRule,
  encodeChallengeRawData,
  getRulesRootUpdatedLogs,
} from '../lib/rule';
import {
  challengeInputInfo,
  columnArray,
  embedVersionIncreaseAndEnableTime,
  getEffectiveEbcsFromLogs,
  getMinEnableTime,
  hexToBuffer,
  testReverted,
  testRevertedOwner,
  createChallenge,
  getSecurityCode,
  getVerifyinfo,
  updateSpv,
  VerifyinfoBase,
  calculateTxGas,
  challengeManager,
  liquidateChallenge,
  PublicInputData,
  updateMakerRule,
} from '../utils.test';
import {
  callDataCost,
  chainIdsMock,
  dealersMock,
  defaultChainInfoArray,
  defaultResponseTime,
  getCurrentTime,
  mineXTimes,
} from '../lib/mockData';
import { PromiseOrValue } from '../../typechain-types/common';
import { randomBytes } from 'crypto';
import {
  calculateEnableTime,
  compile_yul,
  deployContracts,
  deployMDC,
  managerUpdateEBC,
  VerifierAbi,
} from '../../scripts/utils';
import { MerkleTree } from 'merkletreejs';
import { mine, mineUpTo } from '@nomicfoundation/hardhat-network-helpers';
import { Console } from 'console';

describe('MDC TEST ON GOERLI', () => {
  let signers: SignerWithAddress[];
  let mdcOwner: SignerWithAddress;
  let orManager: ORManager;
  let orManagerEbcs: string[];
  let ebcs: string[];
  let orMDCFactory: ORMDCFactory;
  let orMakerDeposit: ORMakerDeposit | TestMakerDeposit;
  let implementation: string;
  let testToken: TestToken;
  let columnArray: columnArray;
  let ebc: OREventBinding;
  let spv: ORChallengeSpvMainnet2Era;
  let defaultRule: BigNumberish[];
  let makerRule: RuleStruct;
  let orSpvData: ORSpvData;
  let spvTest: TestSpv;
  let networkId: number;
  let sourceChain: number;
  let destChain: number;

  before(async function () {
    signers = await ethers.getSigners();
    mdcOwner = signers[2];
    networkId = (await ethers.provider.getNetwork()).chainId;
    console.log('networkId:', networkId);

    if (networkId == 31337 || networkId == 5) {
      await deployContracts(signers[0], mdcOwner);
    }

    // assert if OR_MDC is undefined
    assert(
      !!process.env['OR_MDC_TEST'] &&
        !!process.env['OR_MDC'] &&
        !!process.env['EVENT_BINDING_CONTRACT'] &&
        !!process.env['OR_MANAGER_ADDRESS'] &&
        !!process.env['SPV_TEST_ADDRESS'],
      'Env miss [OR_MDC]',
    );
    const orMakerDepositTestAddress = process.env['OR_MDC_TEST'];
    const orMakerDepositAddress = process.env['OR_MDC'];
    const orEBCAddress = process.env['EVENT_BINDING_CONTRACT'];
    const orManagerAddress = process.env['OR_MANAGER_ADDRESS'];
    const spvTestAddress = process.env['SPV_TEST_ADDRESS'];

    orManager = new ORManager__factory(signers[0]).attach(orManagerAddress);
    console.log('connect to orManager', orManager.address);

    // orMakerDeposit = new TestMakerDeposit__factory(mdcOwner).attach(
    //   orMakerDepositTestAddress,
    // );
    // console.log('connect to makerTest', orMakerDeposit.address);

    orMakerDeposit = new ORMakerDeposit__factory(mdcOwner).attach(
      orMakerDepositAddress,
    );

    ebc = new OREventBinding__factory(signers[0]).attach(orEBCAddress);
    console.log('connect to ebc', ebc.address);

    spvTest = new TestSpv__factory(signers[0]).attach(spvTestAddress);
    console.log('connect to spvTest', spvTest.address);

    // await managerUpdateEBC(orManager, ebc.address);

    orManagerEbcs = [ebc.address].concat(
      await getEffectiveEbcsFromLogs(orManager),
    );

    ebcs = lodash.cloneDeep(orManagerEbcs);
    makerRule = {
      chainId0: BigNumber.from(5),
      chainId1: BigNumber.from(280),
      status0: 1,
      status1: 1,
      token0: BigNumber.from(0),
      token1: BigNumber.from(0),
      minPrice0: BigNumber.from(ethers.utils.parseEther('0.00000002')),
      minPrice1: BigNumber.from(ethers.utils.parseEther('0.00000002')),
      maxPrice0: BigNumber.from(ethers.utils.parseEther('100')),
      maxPrice1: BigNumber.from(ethers.utils.parseEther('100')),
      withholdingFee0: BigNumber.from(ethers.utils.parseEther('0.00000000001')),
      withholdingFee1: BigNumber.from(ethers.utils.parseEther('0.00000000002')),
      tradingFee0: 1,
      tradingFee1: 1,
      responseTime0: defaultResponseTime,
      responseTime1: defaultResponseTime,
      compensationRatio0: 42,
      compensationRatio1: 49,
    };

    sourceChain = makerRule.chainId0.toNumber();
    destChain = makerRule.chainId1.toNumber();
    defaultRule = converRule(makerRule);
    columnArray = {
      dealers: [mdcOwner.address],
      ebcs: [process.env['EVENT_BINDING_CONTRACT']!],
      chainIds: [5, 420, 421613, 280, 534351],
    };
  });

  describe.skip('part1 - update maker', function () {
    it(
      'Function updateColumnArray should emit events and update hash',
      embedVersionIncreaseAndEnableTime(
        () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
        async function () {
          const mdcDealers: string[] = columnArray.dealers;
          const chainIds: number[] = columnArray.chainIds;
          const mdcEbcs: string[] = columnArray.ebcs;

          const columnArrayHash = utils.keccak256(
            utils.defaultAbiCoder.encode(
              ['uint256[]', 'uint256[]', 'uint256[]'],
              [mdcDealers, mdcEbcs, chainIds],
            ),
          );
          // columnArray = {
          //   dealers: mdcDealers,
          //   ebcs: mdcEbcs,
          //   chainIds: chainIds,
          // };
          // print columnArray
          console.log('columnArray: ', columnArray);
          const enableTime = await calculateEnableTime(orMakerDeposit);
          const { events } = await orMakerDeposit
            .updateColumnArray(enableTime, mdcDealers, mdcEbcs, chainIds, {
              gasLimit: 10000000,
            })
            .then((t) => t.wait(3));

          // const args = events?.[0].args;
          // expect(args?.impl).eq(implementation);
          // expect(await orMakerDeposit.columnArrayHash()).eq(columnArrayHash);
          // expect(lodash.toPlainObject(args?.ebcs)).to.deep.includes(mdcEbcs);
          // expect(lodash.toPlainObject(args?.dealers)).to.deep.includes(
          //   mdcDealers,
          // );
        },
      ),
    );

    it(
      'Function updateResponseMakers should emit events and update hash',
      embedVersionIncreaseAndEnableTime(
        () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
        async function () {
          const responseSigners = signers.slice(1, 2);
          const responseMakers: BigNumberish[] = [];
          const responseMakerSignatures: BytesLike[] = [];
          const message = arrayify(
            keccak256(
              defaultAbiCoder.encode(['address'], [orMakerDeposit.address]),
            ),
          ); // Convert to byte array to prevent utf-8 decode when signMessage
          // print signer address
          console.log(
            `maker update[responseMakers: ${responseSigners
              .map((s) => s.address)
              .toString()}]`,
          );
          for (const s of responseSigners) {
            const signature = await s.signMessage(message);

            responseMakers.push(BigNumber.from(s.address));
            responseMakerSignatures.push(signature);
          }

          utils.verifyMessage(message, responseMakerSignatures[0]);
          const enableTime = await calculateEnableTime(orMakerDeposit);
          const { events } = await orMakerDeposit
            .updateResponseMakers(enableTime, responseMakerSignatures)
            .then((t) => t.wait(3));

          const args = events?.[0].args;
          expect(args?.responseMakers).to.deep.eq(responseMakers);

          const responseMakersHash = await orMakerDeposit.responseMakersHash();
          expect(responseMakersHash).to.eq(
            keccak256(defaultAbiCoder.encode(['uint[]'], [responseMakers])),
          );
        },
      ),
    );

    it('prepare: update maker rule', async function () {
      await updateMakerRule(orMakerDeposit, ebc.address, makerRule, true);
    });
  });

  describe('part2 - send ETH', function () {
    const sendETH = async function (
      signer: SignerWithAddress,
      to: string,
      amount: BigNumberish,
    ) {
      const statuses = await ethers.provider.getBlock('latest');
      const tx = await signer
        .sendTransaction({
          to: to,
          value: amount,
        })
        .then((t) => t.wait(3));

      console.log(
        `from:${signer.address} send ${utils.formatEther(amount)} ETH to:${to}`,
      );

      console.log(
        'txHash:',
        tx.transactionHash,
        'blockNumber:',
        tx.blockNumber,
        'amount:',
        amount,
      );
    };

    const sendETHFail = async function (
      signer: SignerWithAddress,
      to: string,
      amount: BigNumberish,
      manulfail = false,
    ) {
      try {
        const tx = await signer.sendTransaction({
          to: to,
          value: amount,
          nonce: 99999999999999,
        });
        console.log(
          `fail! user:${signer.address} send ${utils.formatEther(
            amount,
          )} ETH to maker:${to}`,
        );
      } catch (error) {
        console.log(`error: ${error}`);
      }
    };

    it('prepare: update maker rule', async function () {
      return;
      await updateMakerRule(orMakerDeposit, ebc.address, makerRule, true);
    });

    let destAmount: BigNumber = BigNumber.from(39989900000);
    let nonce: number = 115;
    it('case1: sourceChain send to destChain', async function () {
      // return;
      if (networkId != sourceChain) {
        console.log(
          `current networkId: ${networkId}, not sourceChain: ${sourceChain}, skip`,
        );
        if (networkId != 31337) {
          return;
        }
      }
      console.log(`sourceChain: ${sourceChain} --> destChain: ${destChain}`);

      const balanceBefore = await mdcOwner.provider?.getBalance(
        mdcOwner.address,
      );
      const price = makerRule.minPrice0.mul(2).toString().slice(0, -5);
      const testFreezeAmount =
        price +
        getSecurityCode(
          columnArray,
          process.env['EVENT_BINDING_CONTRACT']!,
          mdcOwner.address,
          destChain,
        );
      console.log('testFreezeAmount', testFreezeAmount);
      if (networkId === 5) {
        destAmount = await spvTest.calculateDestAmount(
          makerRule,
          process.env['EVENT_BINDING_CONTRACT']!,
          sourceChain,
          testFreezeAmount,
        );
        console.log('destAmount', destAmount);
      }
      nonce = await mdcOwner.provider?.getTransactionCount(mdcOwner.address)!;
      console.log('nonce:', nonce);
      await sendETH(signers[0], mdcOwner.address, testFreezeAmount);
    });

    it('case2: destChain send ETH to sourceChain', async function () {
      if (networkId != destChain) {
        console.log(
          `current networkId: ${networkId}, not destChain: ${destChain}, skip`,
        );
        if (networkId != 31337) {
          return;
        }
      }
      console.log(`sourceChain: ${sourceChain} <-- destChain: ${destChain}`);
      const returnValue = BigNumber.from(nonce).add(destAmount);
      await sendETH(mdcOwner, signers[0].address, returnValue);
    });
  });
});
