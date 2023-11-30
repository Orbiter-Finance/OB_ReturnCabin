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
  deployMDC,
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
  let orMakerDeposit: ORMakerDeposit;
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
      if (process.env['OR_MDC_TEST'] == undefined) {
        const makerTest_impl = await new TestMakerDeposit__factory(
          mdcOwner,
        ).deploy();
        await makerTest_impl.deployed();

        const { factoryAddress, mdcAddress } = await deployMDC(
          signers[0],
          mdcOwner,
          process.env['OR_MANAGER_ADDRESS']!,
          makerTest_impl.address,
        );

        const makerTest = new TestMakerDeposit__factory(mdcOwner).attach(
          mdcAddress,
        );
        console.log('address of factory for makerTest:', factoryAddress);
        console.log('connect of makerTest:', makerTest.address);
        process.env['OR_MDC_TEST'] = makerTest.address;
      }

      if (process.env['OR_MDC'] == undefined) {
        const maker_impl = await new ORMakerDeposit__factory(mdcOwner).deploy();
        await maker_impl.deployed();

        const { factoryAddress, mdcAddress } = await deployMDC(
          signers[0],
          mdcOwner,
          process.env['OR_MANAGER_ADDRESS']!,
          maker_impl.address,
        );

        const maker = new ORMakerDeposit__factory(mdcOwner).attach(mdcAddress);
        console.log('address of factory for MDC:', factoryAddress);
        console.log('connect of MDC:', maker.address);

        process.env['OR_MDC'] = maker.address;
        process.env['OR_MDC_FACTORY_ADDRESS'] = factoryAddress;
      }

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
        spv = new ORChallengeSpvMainnet2Era__factory(signers[0]).attach(
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

        spv = await new ORChallengeSpvMainnet2Era__factory(signers[0]).deploy(
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
          mdcOwner.address,
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
        console.log('address of spvTest:', spvTest.address);
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
      compensationRatio0: 40,
      compensationRatio1: 42,
    };

    sourceChain = makerRule.chainId0.toNumber();
    destChain = makerRule.chainId1.toNumber();

    // sourceChain = makerRule.chainId0.toNumber();
    // destChain = makerRule.chainId1.toNumber();

    defaultRule = converRule(makerRule);

    columnArray = {
      dealers: [mdcOwner.address],
      ebcs: [process.env['EVENT_BINDING_CONTRACT']!],
      chainIds: [5, 420, 421613, 280, 534351],
    };
  });

  describe('part1 - update maker', function () {
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
    //       const mdcDealers: string[] = columnArray.dealers;
    //       const chainIds: number[] = columnArray.chainIds;
    //       const mdcEbcs: string[] = columnArray.ebcs;

    //       const columnArrayHash = utils.keccak256(
    //         utils.defaultAbiCoder.encode(
    //           ['uint256[]', 'uint256[]', 'uint256[]'],
    //           [mdcDealers, mdcEbcs, chainIds],
    //         ),
    //       );
    //       // columnArray = {
    //       //   dealers: mdcDealers,
    //       //   ebcs: mdcEbcs,
    //       //   chainIds: chainIds,
    //       // };
    //       // print columnArray
    //       console.log('columnArray: ', columnArray);
    //       const enableTime = await calculateEnableTime(orMakerDeposit);
    //       const { events } = await orMakerDeposit
    //         .updateColumnArray(enableTime, mdcDealers, mdcEbcs, chainIds, {
    //           gasLimit: 10000000,
    //         })
    //         .then((t) => t.wait(1));

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
    //   'Function updateResponseMakers should emit events and update hash',
    //   embedVersionIncreaseAndEnableTime(
    //     () => orMakerDeposit.getVersionAndEnableTime().then((r) => r.version),
    //     async function () {
    //       const responseSigners = signers.slice(1, 2);
    //       const responseMakers: BigNumberish[] = [];
    //       const responseMakerSignatures: BytesLike[] = [];
    //       const message = arrayify(
    //         keccak256(
    //           defaultAbiCoder.encode(['address'], [orMakerDeposit.address]),
    //         ),
    //       ); // Convert to byte array to prevent utf-8 decode when signMessage
    //       // print signer address
    //       console.log(
    //         `maker update[responseMakers: ${responseSigners
    //           .map((s) => s.address)
    //           .toString()}]`,
    //       );
    //       for (const s of responseSigners) {
    //         const signature = await s.signMessage(message);

    //         responseMakers.push(BigNumber.from(s.address));
    //         responseMakerSignatures.push(signature);
    //       }

    //       utils.verifyMessage(message, responseMakerSignatures[0]);
    //       const enableTime = await calculateEnableTime(orMakerDeposit);
    //       const { events } = await orMakerDeposit
    //         .updateResponseMakers(enableTime, responseMakerSignatures)
    //         .then((t) => t.wait(1));

    //       const args = events?.[0].args;
    //       expect(args?.responseMakers).to.deep.eq(responseMakers);

    //       const responseMakersHash = await orMakerDeposit.responseMakersHash();
    //       expect(responseMakersHash).to.eq(
    //         keccak256(defaultAbiCoder.encode(['uint[]'], [responseMakers])),
    //       );
    //     },
    //   ),
    // );

    it('prepare: update maker rule', async function () {
      await updateMakerRule(orMakerDeposit, ebc.address, makerRule, true);
    });
  });

  describe.skip('part2 - send ETH', function () {
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

    let destAmount: BigNumber = BigNumber.from(9999900000);
    let nonce: number = 3;
    it('case1: sourceChain send to destChain', async function () {
      return;
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
      console.log('price', price);
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
      return;
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

    return;
    it('Function saveHistoryBlocksRoots should success', async function () {
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
  });
});
