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
  ORChallengeSpv,
  ORChallengeSpv__factory,
  ORSpvData,
  ORSpvData__factory,
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
import { compile_yul, VerifierAbi } from '../../scripts/utils';
import { MerkleTree } from 'merkletreejs';
import { mine, mineUpTo } from '@nomicfoundation/hardhat-network-helpers';

describe('MDC TEST ON GOERLI', () => {
  let signers: SignerWithAddress[];
  let mdcOwner: SignerWithAddress;
  let orManager: ORManager;
  let orManagerEbcs: string[];
  let ebcs: string[];
  let orMDCFactory: ORMDCFactory;
  let orMakerDeposit: ORMakerDeposit;
  let implementation: string;
  let testToken: TestToken;
  let columnArray: columnArray;
  let ebc: OREventBinding;
  let spv: ORChallengeSpv;
  let defaultRule: BigNumberish[];
  let makerRule: RuleStruct;
  let orSpvData: ORSpvData;
  let spvTest: TestSpv;
  let networkId: number;

  before(async function () {
    signers = await ethers.getSigners();
    mdcOwner = signers[1];
    networkId = (await ethers.provider.getNetwork()).chainId;
    // network id

    if (networkId == 31337 || 5) {
      const envORMDCFactoryAddress = process.env['OR_MDC_FACTORY_ADDRESS'];
      assert(
        !!envORMDCFactoryAddress,
        'Env miss [OR_MDC_FACTORY_ADDRESS]. You may need to test ORMDCFactory.test.ts first. Example: npx hardhat test test/ORManager.test test/ORFeeManager.test.ts test/ORMDCFactory.test.ts test/ORMakerDeposit.test.ts',
      );

      orMDCFactory = new ORMDCFactory__factory(signers[0]).attach(
        envORMDCFactoryAddress,
      );
      implementation = await orMDCFactory.implementation();

      orManager = new ORManager__factory(signers[0]).attach(
        await orMDCFactory.manager(),
      );

      if (process.env['EVENT_BINDING_CONTRACT'] != undefined) {
        ebc = OREventBinding__factory.connect(
          process.env['EVENT_BINDING_CONTRACT'],
          signers[0],
        );
        console.log('connect to ebc contract', ebc.address);
      } else {
        ebc = await new OREventBinding__factory(signers[0]).deploy();
        process.env['EVENT_BINDING_CONTRACT'] = ebc.address;
        console.log('Address of ebc:', ebc.address);
      }

      if (process.env['SPV_ADDRESS'] != undefined) {
        spv = new ORChallengeSpv__factory(signers[0]).attach(
          process.env['SPV_ADDRESS'],
        );
        console.log('connect to spv contract', spv.address);
      } else {
        const verifyDestBytesCode = await compile_yul(
          'contracts/zkp/goerliDestSpvVerifier.yul',
        );

        const verifierDestFactory = new ethers.ContractFactory(
          VerifierAbi,
          verifyDestBytesCode,
          mdcOwner,
        );

        const verifySourceBytesCode = await compile_yul(
          'contracts/zkp/goerliSourceSpvVerifier.yul',
        );

        const verifierSourceFactory = new ethers.ContractFactory(
          VerifierAbi,
          verifySourceBytesCode,
          mdcOwner,
        );

        const spvSource: { address: PromiseOrValue<string> } =
          await verifierSourceFactory.deploy();

        const spvDest: { address: PromiseOrValue<string> } =
          await verifierDestFactory.deploy();

        spv = await new ORChallengeSpv__factory(signers[0]).deploy(
          spvSource.address,
          spvDest.address,
        );
        await spv.deployed();
        process.env['SPV_ADDRESS'] = spv.address;
        console.log('Address of spv:', spv.address);
      }

      orManagerEbcs = [ebc.address].concat(
        await getEffectiveEbcsFromLogs(orManager),
      );

      ebcs = lodash.cloneDeep(orManagerEbcs);

      const predictMDCAddress = await orMDCFactory
        .connect(mdcOwner)
        .predictMDCAddress();
      orMakerDeposit = new ORMakerDeposit__factory(mdcOwner).attach(
        predictMDCAddress,
      );

      if (process.env['OR_SPV_DATA_ADRESS'] != undefined) {
        orSpvData = new ORSpvData__factory(signers[0]).attach(
          process.env['OR_SPV_DATA_ADRESS'],
        );
        console.log('connect to orSpvData', orSpvData.address);
      } else {
        orSpvData = await new ORSpvData__factory(signers[0]).deploy(
          orManager.address,
        );
        console.log('address of orSpvData:', orSpvData.address);
        await orSpvData.deployed();
        process.env['OR_SPV_DATA_ADRESS'] = orSpvData.address;
      }

      // spvTest
      if (process.env['SPV_TEST_ADDRESS'] != undefined) {
        spvTest = new TestSpv__factory(signers[0]).attach(
          process.env['SPV_TEST_ADDRESS'],
        );
        console.log('connect to spvTest', spvTest.address);
      } else {
        spvTest = await new TestSpv__factory(mdcOwner).deploy(spv.address);
      }
    }
    makerRule = {
      chainId0: BigNumber.from(5),
      chainId1: BigNumber.from(280),
      status0: 1,
      status1: 1,
      token0: BigNumber.from(0),
      token1: BigNumber.from(0),
      minPrice0: BigNumber.from(ethers.utils.parseEther('0.00000001')),
      minPrice1: BigNumber.from(ethers.utils.parseEther('0.00000001')),
      maxPrice0: BigNumber.from(ethers.utils.parseEther('100')),
      maxPrice1: BigNumber.from(ethers.utils.parseEther('100')),
      withholdingFee0: BigNumber.from(ethers.utils.parseEther('0.00000001')),
      withholdingFee1: BigNumber.from(ethers.utils.parseEther('0.00000002')),
      tradingFee0: 1,
      tradingFee1: 1,
      responseTime0: defaultResponseTime,
      responseTime1: defaultResponseTime,
      compensationRatio0: 31,
      compensationRatio1: 30,
    };

    defaultRule = converRule(makerRule);

    columnArray = {
      dealers: ['0xaFcfbb382b28dae47B76224F24eE29BE2c823648'],
      ebcs: [process.env['EVENT_BINDING_CONTRACT']!],
      chainIds: [5, 420, 421613, 280, 534351],
    };
  });

  describe.skip('part1 - update maker', function () {
    it('Restoring the ORMakerDeposit should succeed', async function () {
      const predictMDCAddress = await orMDCFactory
        .connect(mdcOwner)
        .predictMDCAddress();
      orMakerDeposit = new ORMakerDeposit__factory(mdcOwner).attach(
        predictMDCAddress,
      );
      console.log('connect of mdc:', orMakerDeposit.address);
      const owner = await orMakerDeposit.owner();

      expect(owner).eq(mdcOwner.address);
    });

    // it(
    //   'Function updateColumnArray should emit events and update hash',
    //   embedVersionIncreaseAndEnableTime(
    //     () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
    //     async function () {
    //       const mdcEbcs: string[] = process.env['EVENT_BINDING_CONTRACT'] != undefined ? [process.env['EVENT_BINDING_CONTRACT']] : [ebc.address];
    //       mdcEbcs.sort(() => Math.random() - 0.5);
    //       const mdcDealers: string[] = [mdcOwner.address]
    //       const chainIds: number[] = chainIdsMock;
    //       const columnArrayHash = utils.keccak256(
    //         utils.defaultAbiCoder.encode(
    //           ['uint256[]', 'uint256[]', 'uint256[]'],
    //           [mdcDealers, mdcEbcs, chainIds],
    //         ),
    //       );
    //       columnArray = {
    //         dealers: mdcDealers,
    //         ebcs: mdcEbcs,
    //         chainIds: chainIds,
    //       };
    //       // print columnArray
    //       console.log("columnArray: ", columnArray);
    //       const enableTime = getMinEnableTime((await orMakerDeposit.getVersionAndEnableTime()).enableTime);
    //       console.log((await orMakerDeposit.getVersionAndEnableTime()));
    //       console.log(`current time: ${(await ethers.provider.getBlock('latest')).timestamp}, block: ${(await ethers.provider.getBlock('latest')).number}, enableTime: ${enableTime}`);
    //       const { events } = await orMakerDeposit
    //         .updateColumnArray(
    //           enableTime,
    //           mdcDealers,
    //           mdcEbcs,
    //           chainIds,
    //           {
    //             gasLimit: 10000000,
    //           },
    //         )
    //         .then((t) => t.wait(2));

    //       const args = events?.[0].args;
    //       expect(args?.impl).eq(implementation);
    //       expect(await orMakerDeposit.columnArrayHash()).eq(columnArrayHash);
    //       expect(lodash.toPlainObject(args?.ebcs)).to.deep.includes(mdcEbcs);
    //       expect(lodash.toPlainObject(args?.dealers)).to.deep.includes(
    //         mdcDealers,
    //       );
    //     },
    //   ),
    // );

    // it(
    //   'Function updateSpvs should emit events and update storage',
    //   embedVersionIncreaseAndEnableTime(
    //     () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
    //     async function () {
    //       const chainId = defaultChainInfo.id;
    //       const chainInfo = await orManager.getChainInfo(chainId);

    //       const spvs = chainInfo.spvs.slice(0, 1);
    //       const chainIds = [chainId];
    //       console.log(
    //         `maker update[chainId: ${chainIds.toString()} - spv: ${spvs}]`,
    //       );

    //       const { events } = await orMakerDeposit
    //         .updateSpvs(
    //           getMinEnableTime(
    //             (
    //               await orMakerDeposit.getVersionAndEnableTime()
    //             ).enableTime,
    //           ),
    //           spvs,
    //           chainIds,
    //         )
    //         .then((t) => t.wait(2));

    //       events?.forEach((event, index) => {
    //         expect(event.args?.['impl']).eq(implementation);
    //         expect(event.args?.['chainId']).eq(chainIds[index]);
    //         expect(event.args?.['spv']).eq(spvs[index]);
    //       });

    //       // eslint-disable-next-line @typescript-eslint/no-for-in-array
    //       for (const i in chainIds) {
    //         const spv = await orMakerDeposit.spv(chainIds[i]);
    //         expect(spv).eq(spvs[i]);
    //       }

    //       await testRevertedOwner(
    //         orMakerDeposit
    //           .connect(signers[2])
    //           .updateSpvs(
    //             getMinEnableTime(
    //               (
    //                 await orMakerDeposit.getVersionAndEnableTime()
    //               ).enableTime,
    //             ),
    //             spvs,
    //             chainIds,
    //           ),
    //       );

    //       await testReverted(
    //         orMakerDeposit.updateSpvs(
    //           getMinEnableTime(
    //             (
    //               await orMakerDeposit.getVersionAndEnableTime()
    //             ).enableTime,
    //           ),
    //           spvs,
    //           [2 ** 16 - 1],
    //         ),
    //         'CI',
    //       );
    //       await testReverted(
    //         orMakerDeposit.updateSpvs(
    //           getMinEnableTime(
    //             (
    //               await orMakerDeposit.getVersionAndEnableTime()
    //             ).enableTime,
    //           ),
    //           [constants.AddressZero],
    //           chainIds,
    //         ),
    //         'SI',
    //       );
    //     },
    //   ),
    // );

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

          const { events } = await orMakerDeposit
            .updateResponseMakers(
              getMinEnableTime(
                (
                  await orMakerDeposit.getVersionAndEnableTime()
                ).enableTime,
              ),
              responseMakerSignatures,
            )
            .then((t) => t.wait(2));

          const args = events?.[0].args;
          expect(args?.responseMakers).to.deep.eq(responseMakers);

          const responseMakersHash = await orMakerDeposit.responseMakersHash();
          expect(responseMakersHash).to.eq(
            keccak256(defaultAbiCoder.encode(['uint[]'], [responseMakers])),
          );
        },
      ),
    );

    // it('Function deposit should success', async function () {
    //   const bETHBefore = await mdcOwner.provider?.getBalance(
    //     orMakerDeposit.address,
    //   );
    //   const amountETH = utils.parseEther('0.001');
    //   await orMakerDeposit
    //     .deposit(constants.AddressZero, constants.Zero, { value: amountETH })
    //     .then((t) => t.wait(2));
    //   const bETHAfter = await mdcOwner.provider?.getBalance(
    //     orMakerDeposit.address,
    //   );
    //   expect(bETHAfter?.sub(bETHBefore || 0)).eq(amountETH);

    //   const bERC20Before = await testToken.balanceOf(orMakerDeposit.address);
    //   const amountERC20 = utils.parseEther('0.001');
    //   await testToken
    //     .approve(orMakerDeposit.address, amountERC20)
    //     .then((t) => t.wait(2));
    //   await orMakerDeposit
    //     .deposit(testToken.address, amountERC20)
    //     .then((t) => t.wait(2));
    //   const bERC20After = await testToken.balanceOf(orMakerDeposit.address);
    //   expect(bERC20After.sub(bERC20Before)).eq(amountERC20);
    // });

    it(
      'Function updateRulesRoot should emit events and update storage',
      embedVersionIncreaseAndEnableTime(
        () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
        async function () {
          const rules: any[] = [];
          const defaultRule = createMakerRule(true);
          const makerRule: RuleStruct = {
            ...defaultRule,
            chainId0: BigNumber.from(5),
            chainId1: BigNumber.from(280),
            minPrice0: BigNumber.from(ethers.utils.parseEther('0.00000001')),
            minPrice1: BigNumber.from(ethers.utils.parseEther('0.00000001')),
            maxPrice0: BigNumber.from(ethers.utils.parseEther('100')),
            maxPrice1: BigNumber.from(ethers.utils.parseEther('100')),
            withholdingFee0: BigNumber.from(
              ethers.utils.parseEther('0.00000001'),
            ),
            withholdingFee1: BigNumber.from(
              ethers.utils.parseEther('0.00000002'),
            ),
            responseTime0: BigNumber.from(604800).toNumber(),
            responseTime1: BigNumber.from(604800).toNumber(),
          };
          rules.push(converRule(makerRule));
          console.log(makerRule);

          const tree = await calculateRulesTree(rules);
          const root = utils.hexlify(tree.root);

          const rootWithVersion = { root, version: 1 };
          const sourceChainIds = [1];
          const pledgeAmounts = [utils.parseEther('0.0001')];

          console.log(`ebc : [${ebc.address}]`);

          const { events } = await orMakerDeposit
            .updateRulesRoot(
              getMinEnableTime(
                (
                  await orMakerDeposit.getVersionAndEnableTime()
                ).enableTime,
              ),
              ebc.address,
              rules,
              rootWithVersion,
              sourceChainIds,
              pledgeAmounts,
              {
                value: pledgeAmounts.reduce((pv, cv) => pv.add(cv)),
              },
            )
            .then((t) => t.wait(2));

          if (!!events) {
            const txrc = await ethers.provider.getTransaction(
              events[0].transactionHash,
            );
            const recpt = await ethers.provider.getTransactionReceipt(
              events[0].transactionHash,
            );
            const inpudataGas = callDataCost(txrc.data);
            console.log(
              `updateRule, totoalGas: ${recpt.gasUsed}, callDataGasCost: ${inpudataGas}`,
            );
          }
          const args = events?.[0].args;
          expect(args?.ebc).eq(ebc.address);
          expect(args?.rootWithVersion.root).eq(rootWithVersion.root);
          expect(args?.rootWithVersion.version).eq(rootWithVersion.version);

          const storageRWV = await orMakerDeposit.rulesRoot(ebc.address);
          expect(storageRWV.root).eq(rootWithVersion.root);
          expect(storageRWV.version).eq(rootWithVersion.version);

          const key = hexToBuffer(calculateRuleKey(lodash.sample(rules)));
          const proof = await BaseTrie.createProof(tree, key);
          const v = await BaseTrie.verifyProof(
            hexToBuffer(storageRWV.root),
            key,
            proof,
          );
          expect(v !== null).to.be.true;

          await updateSpv(
            makerRule.chainId0.toNumber(),
            spv.address,
            orManager,
          );
          await updateSpv(
            makerRule.chainId1.toNumber(),
            spv.address,
            orManager,
          );
        },
      ),
    );

    // it('Function withdraw should success', async function () {
    //   const bETHBefore = await mdcOwner.provider?.getBalance(mdcOwner.address);
    //   const M_ETH_Before = await ethers.provider.getBalance(
    //     orMakerDeposit.address,
    //   );
    //   const firstRequestInfo = await orMakerDeposit?.getWithdrawRequestInfo(
    //     constants.AddressZero,
    //   );
    //   expect(BigNumber.from(firstRequestInfo.requestTimestamp)).eq(0);
    //   await testReverted(orMakerDeposit.withdraw(constants.AddressZero), 'WTN');
    //   const amountETH = utils.parseEther('0.001');
    //   const requestReceipt = await orMakerDeposit
    //     .withdrawRequest(constants.AddressZero, amountETH)
    //     .then((t) => t.wait(2));
    //   const secondRequestInfo = await orMakerDeposit?.getWithdrawRequestInfo(
    //     constants.AddressZero,
    //   );
    //   expect(BigNumber.from(secondRequestInfo.requestTimestamp)).gt(0);
    //   await testReverted(
    //     orMakerDeposit.withdrawRequest(constants.AddressZero, amountETH),
    //     'RHB',
    //   );
    //   await testReverted(orMakerDeposit.withdraw(constants.AddressZero), 'WTN');
    //   const currentBlockInfo = await ethers.provider.getBlock('latest');
    //   await mineXTimes(
    //     BigNumber.from(secondRequestInfo.requestTimestamp)
    //       .sub(currentBlockInfo.timestamp)
    //       .toNumber(),
    //     true,
    //   );
    //   const withdrawReceipt = await orMakerDeposit
    //     .withdraw(constants.AddressZero)
    //     .then((t) => t.wait(2));
    //   const thirdRequestInfo = await orMakerDeposit?.getWithdrawRequestInfo(
    //     constants.AddressZero,
    //   );
    //   expect(BigNumber.from(thirdRequestInfo.requestTimestamp)).eq(0);
    //   const bETHAfter = await mdcOwner.provider?.getBalance(mdcOwner.address);
    //   const requestGasUsed = requestReceipt.gasUsed.mul(
    //     requestReceipt.effectiveGasPrice,
    //   );
    //   const withdrawGasUsed = withdrawReceipt.gasUsed.mul(
    //     withdrawReceipt.effectiveGasPrice,
    //   );
    //   expect(
    //     bETHAfter
    //       ?.add(requestGasUsed)
    //       .add(withdrawGasUsed)
    //       .sub(bETHBefore || 0),
    //   ).eq(amountETH);

    //   const M_ETH_After = await ethers.provider.getBalance(
    //     orMakerDeposit.address,
    //   );

    //   expect(amountETH?.add(M_ETH_After)).eq(M_ETH_Before);

    //   await testRevertedOwner(
    //     orMakerDeposit
    //       .connect(signers[2])
    //       .withdrawRequest(constants.AddressZero, amountETH),
    //   );

    //   await testRevertedOwner(
    //     orMakerDeposit.connect(signers[2]).withdraw(constants.AddressZero),
    //   );
    // });
  });

  describe('part2 - send ETH', function () {
    const sendETH = async function (
      signer: SignerWithAddress,
      to: string,
      amount: BigNumberish,
    ) {
      const statuses = await ethers.provider.getBlock('latest');
      const tx = await signer.sendTransaction({
        to: to,
        value: amount,
      });
      console.log(
        `from:${signer.address} send ${utils.formatEther(amount)} ETH to:${to}`,
      );
      console.log(
        `txHash:${tx.hash}, chainId:${ethers.provider.network.chainId}, blockNumber:${statuses.number}, timestamp:${statuses.timestamp}`,
      );
      return tx;
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

    let destAmount: BigNumber;
    it('case1: send ETH to maker', async function () {
      return;
      const balanceBefore = await mdcOwner.provider?.getBalance(
        mdcOwner.address,
      );
      const price = makerRule.minPrice0.mul(2).toString().slice(0, -5);
      const testFreezeAmount =
        price +
        getSecurityCode(
          columnArray,
          ebc.address,
          mdcOwner.address,
          makerRule.chainId1.toNumber(),
        );

      destAmount = await spvTest.calculateDestAmount(
        converRule(makerRule),
        ebc.address,
        makerRule.chainId0.toNumber(),
        testFreezeAmount,
      );
      console.log('destAmount', destAmount);
      await sendETH(signers[0], mdcOwner.address, testFreezeAmount);
      expect(await mdcOwner.provider?.getBalance(mdcOwner.address)).eq(
        balanceBefore?.add(testFreezeAmount),
      );
    });

    it('case2: ERA send ETH', async function () {
      if (networkId == 5) {
        return;
      }
      // const balanceBefore = await mdcOwner.provider?.getBalance(signers[0].address);
      // const destAmount = BigNumber.from(9999900000);
      const nonce = await mdcOwner.provider?.getTransactionCount(
        mdcOwner.address,
      );
      const returnValue = BigNumber.from(nonce).add(destAmount);
      await sendETH(mdcOwner, signers[0].address, returnValue);
      // expect(await mdcOwner.provider?.getBalance(signers[0].address)).eql(balanceBefore?.add(returnValue));
    });

    it('case3: ERA send ETH, but fail', async function () {
      if (networkId == 5) {
        return;
      }
      const balanceBefore = await mdcOwner.provider?.getBalance(
        mdcOwner.address,
      );
      const price = makerRule.minPrice0.mul(2).toString().slice(0, -5);
      const ebc = process.env['EVENT_BINDING_CONTRACT']!;
      const testFreezeAmount =
        price +
        getSecurityCode(
          columnArray,
          ebc,
          mdcOwner.address,
          makerRule.chainId1.toNumber(),
        );

      await sendETHFail(mdcOwner, signers[0].address, testFreezeAmount, true);
      // expect(await mdcOwner.provider?.getBalance(mdcOwner.address)).eq(balanceBefore);
    });

    const _calculateMerkleTree = async (
      startBlockNumber: BigNumberish,
      blockInterval: number,
    ) => {
      const leaves = await Promise.all(
        new Array(blockInterval)
          .fill(undefined)
          .map((_, index) =>
            orSpvData.provider
              .getBlock(
                BigNumber.from(startBlockNumber).add(index).toHexString(),
              )
              .then((b: any) => b.hash),
          ),
      );
      return new MerkleTree(leaves, keccak256);
    };

    it('Function saveHistoryBlocksRoots should success', async function () {
      // return;
      if (ethers.provider.network.chainId == 31337) {
        await mineUpTo(1200);
      }

      if (!(networkId == 5 || networkId == 31337)) {
        return;
      }

      const receipt = await orSpvData
        .saveHistoryBlocksRoots()
        .then((t: any) => t.wait());
      const events = receipt.events!;
      const currentBlockNumber = receipt.blockNumber;

      const blockInterval = (await orSpvData.blockInterval()).toNumber();

      for (let i = 256, ei = 0; i > 0; i--) {
        const startBlockNumber = currentBlockNumber - i;
        if (
          startBlockNumber % blockInterval === 0 &&
          startBlockNumber + blockInterval < currentBlockNumber
        ) {
          expect(BigNumber.from(startBlockNumber)).to.deep.eq(
            events[ei].args?.['startBlockNumber'],
          );

          // Calculate block's hash root
          const merkleTree = await _calculateMerkleTree(
            startBlockNumber,
            blockInterval,
          );

          const blockHash = await orSpvData.getBlocksRoot(startBlockNumber);
          console.log(
            `update blockHash: ${blockHash}, startBlockNumber: ${startBlockNumber}`,
          );
          expect(BigNumber.from(blockHash)).to.eq(
            BigNumber.from(merkleTree.getHexRoot()),
          );
          ei++;
        }
      }
    });
  });
});
