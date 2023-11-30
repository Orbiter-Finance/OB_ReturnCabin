import { ethers } from 'hardhat';
import { expect } from 'chai';
import 'cross-fetch/polyfill';
import {
  BigNumber,
  BigNumberish,
  ContractReceipt,
  ContractTransaction,
  constants,
  utils,
} from 'ethers';
import {
  IORSpvData,
  ORMakerDeposit,
  ORManager,
  ORSpvData,
  TestMakerDeposit,
  TestSpv,
} from '../typechain-types';
import { callDataCost, getCurrentTime, mineXTimes } from './lib/mockData';
import {
  RuleStruct,
  calculateRuleKey,
  calculateRulesTree,
  converRule,
  createMakerRule,
  encodeChallengeRawData,
  encodeChallengeRawDataWORule,
  encodeRuleStruct,
  formatRule,
} from './lib/rule';
import {
  BytesLike,
  defaultAbiCoder,
  keccak256,
  solidityPack,
} from 'ethers/lib/utils';
import { getMappingStructXSlot } from './lib/readStorage';
import { assert } from 'console';
import { string } from 'hardhat/internal/core/params/argumentTypes';
import { chain, random, update } from 'lodash';
import { calculateEnableTime } from '../scripts/utils';
import { BridgeLib } from '../typechain-types/contracts/ORManager';
import { promises } from 'dns';
import { mineUpTo } from '@nomicfoundation/hardhat-network-helpers';

export function hexToBuffer(hex: string) {
  return Buffer.from(utils.arrayify(hex));
}

export async function sleep(ms: number) {
  return new Promise((resolve) => {
    setTimeout(() => resolve(true), ms);
  });
}

export async function testReverted(
  transaction: Promise<ContractTransaction>,
  reason: string,
) {
  await expect(transaction).to.be.revertedWith(reason);
}

export async function testRevertedOwner(
  transaction: Promise<ContractTransaction>,
) {
  await testReverted(transaction, 'Ownable: caller is not the owner');
}

export async function getEffectiveEbcsFromLogs(orManager: ORManager) {
  const topics: string[] = [utils.id('EbcsUpdated(address[],bool[])')];
  const logs = await orManager.provider.getLogs({
    fromBlock: 0,
    toBlock: 'latest',
    address: orManager.address,
    topics,
  });

  const mappingEbcs: { [key: string]: boolean } = {};
  for (const log of logs) {
    const [ebcs, statuses] = utils.defaultAbiCoder.decode(
      ['address[]', 'bool[]'],
      log.data,
    );

    ebcs.forEach((ebc: string, i: number) => {
      mappingEbcs[ebc] = statuses?.[i] === undefined ? true : statuses[i];
    });
  }

  const effectiveEbcs: string[] = [];
  for (const ebc in mappingEbcs) {
    if (mappingEbcs[ebc]) {
      effectiveEbcs.push(ebc);
    }
  }

  return effectiveEbcs;
}

export function embedVersionIncreaseAndEnableTime(
  svFn: () => Promise<BigNumberish>,
  fn: () => Promise<void>,
  increase = 1,
) {
  return async () => {
    const sv0 = await svFn();
    await fn();
    const sv1 = await svFn();
    expect(BigNumber.from(sv1).sub(sv0).toNumber()).eq(increase);
  };
}

export const MIN_ENABLE_DELAY = 120; // Unit: second
export function getMinEnableTime(currentEnableTime?: BigNumber) {
  if (currentEnableTime != undefined) {
    const minEnableTime =
      currentEnableTime.toNumber() != 0
        ? currentEnableTime.add(MIN_ENABLE_DELAY)
        : BigNumber.from((Date.now() / 1000).toFixed(0)).add(MIN_ENABLE_DELAY);
    return minEnableTime.add(30);
  } else {
    const minEnableTime = BigNumber.from(
      Date.now() + MIN_ENABLE_DELAY * 1000,
    ).div(1000);
    return minEnableTime.add(200); // Keep time
  }
}

export interface challengeInputInfo {
  sourceTxTime: number;
  sourceChainId: BigNumberish;
  destChainId: BigNumberish;
  sourceBlockNum: number;
  sourceTxIndex: number;
  sourceTxHash: string;
  from: string;
  freezeToken: string;
  freezeAmount: BigNumberish;
  parentNodeNumOfTargetNode: BigNumberish;
}

export interface challengeNodeInfoList {
  sourceChainId: BigNumberish;
  sourceTxHash: string;
  challengeIdentNum: BigNumberish;
  challenge: challengeInputInfo;
  liquidated: boolean;
  index?: number;
}

export interface VerifyinfoBase {
  freeTokenSource: string;
  chainIdSource: BigNumberish;
  freeTokenDest: string;
  chainIdDest: BigNumberish;
  ebc: string;
}

export interface VerifyInfoSlotStruct {
  account: string;
  key: BytesLike;
  value: BigNumberish;
}

export interface VerifyInfo {
  data: BigNumberish[];
  slots: VerifyInfoSlotStruct[];
}

export interface columnArray {
  dealers: string[];
  ebcs: string[];
  chainIds: number[];
}

export interface PublicInputData {
  tx_hash: BytesLike;
  chain_id: BigNumberish;
  index: BigNumberish;
  from: BigNumberish;
  to: BigNumberish;
  token: string;
  amount: BigNumberish;
  nonce: BigNumberish;
  time_stamp: BigNumberish;
  dest: string;
  dest_token: string;
  mdc_contract_address: string;
  manage_contract_address: string;
  mdc_rule_root_slot: BigNumberish;
  mdc_rule_version_slot: BigNumberish;
  mdc_rule_enable_time_slot: BigNumberish;
  mdc_column_array_hash_slot: BigNumberish;
  mdc_response_makers_hash_slot: BigNumberish;
  manage_source_chain_info_slot: BigNumberish;
  min_verify_challenge_src_tx_second: BigNumberish;
  max_verify_challenge_src_tx_second: BigNumberish;
  min_verify_challenge_dest_tx_second: BigNumberish;
  max_verify_challenge_dest_tx_second: BigNumberish;
  manage_source_chain_mainnet_token_info_slot: BigNumberish;
  manage_dest_chain_mainnet_token_slot: BigNumberish;
  manage_challenge_user_ratio_slot: BigNumberish;
  mdc_current_rule_root: BytesLike;
  mdc_current_rule_enable_time: BigNumberish;
  mdc_current_column_array_hash: BytesLike;
  mdc_current_response_makers_hash: BigNumberish;
  // manage_current_source_chain_info: BytesLike;
  manage_current_source_chain_mainnet_token: string;
  manage_current_dest_chain_mainnet_token: string;
  manage_current_challenge_user_ratio: BigNumberish;
  mdc_next_rule_enable_time: BigNumberish;
  mdc_current_rule_value_hash: BytesLike;
  merkle_roots: string[];
}

export interface PublicInputDataDest {
  // tx_hash: BytesLike;
  chain_id: BigNumberish;
  // index: BigNumberish;
  from: BigNumberish;
  to: BigNumberish;
  token: BigNumberish;
  amount: BigNumberish;
  // nonce: BigNumberish;
  time_stamp: BigNumberish;
  merkle_roots: string[];
}

export interface VerifiedDataInfo {
  minChallengeSecond: BigNumberish;
  maxChallengeSecond: BigNumberish;
  nonce: BigNumberish;
  destChainId: BigNumberish;
  from: BigNumberish;
  destToken: BigNumberish;
  destAmount: BigNumberish;
  responseMakersHash: BigNumberish;
  responseTime: BigNumberish;
}

export const updateChains = async (
  orManager: ORManager,
  chainsInfo: BridgeLib.ChainInfoStruct[],
) => {
  for (const chainInfo of chainsInfo) {
    const updateChainId = chainInfo.id;
    const exitChainId = (await orManager.getChainInfo(updateChainId)).id;
    if (BigNumber.from(updateChainId).eq(exitChainId)) {
      console.log('already exist chainId: ', chainInfo.id);
      return promises;
    }
  }

  console.log(
    'registerChains: ',
    chainsInfo.map((chain) => chain.id),
  );

  await orManager
    .registerChains(await calculateEnableTime(orManager), chainsInfo)
    .then((t) => t.wait(1));
};

export const updateSpv = async (
  chainId: number,
  spvAddress: string,
  _orManager: ORManager,
) => {
  let currentSpvs: string[] = (
    await _orManager.getChainInfo(chainId)
  ).spvs.filter((v) => v != constants.AddressZero);

  const indexArray = Array.from(Array(currentSpvs.length).keys());

  if (currentSpvs.includes(spvAddress)) {
    console.log(
      `chainId: ${chainId}, no need to update spvAddress: ${spvAddress} is exist`,
    );
    return;
  }
  currentSpvs.push(spvAddress);

  const { events } = await _orManager
    .updateChainSpvs(
      await calculateEnableTime(_orManager),
      chainId,
      currentSpvs,
      indexArray,
      {
        gasLimit: 1e6,
      },
    )
    .then((t) => t.wait(1));
  const updatedSpvs = (await _orManager.getChainInfo(chainId)).spvs;
  expect(updatedSpvs).to.deep.includes(spvAddress);

  console.log(`chainId: ${chainId}, newSpvAddress: ${spvAddress}`);
};

export const getSecurityCode = (
  columnArray: columnArray,
  ebc: string,
  dealer: string,
  chainId: number,
): string => {
  const dealerIndex = columnArray.dealers.indexOf(dealer) + 1;
  const ebcIndex = columnArray.ebcs.indexOf(ebc) + 1;
  const chainIdIndex = utils.arrayify(
    columnArray.chainIds.indexOf(chainId) + 1,
  );
  // console.log(
  //   `dealerIndex: ${dealerIndex}, ebcIndex: ${ebcIndex}, chainIdIndex: ${chainIdIndex}`,
  // );
  const dealerIndexStr = dealerIndex.toString().padStart(2, '0');
  const securityCode = dealerIndex
    .toString()
    .padStart(2, '0')
    .concat(ebcIndex.toString())
    .concat('0')
    .concat(chainIdIndex.toString());

  return securityCode;
};

/**
 * notice: this function *only* used to check the current slot of contract,
 * it cannot be used to check the historical slots.
 * In production environments, historical slot values will be used.
 * @param {ORMakerDeposit} maker - ORMakerDeposit contract
 * @param {ORManager} manager - ORManager contract
 * @param {challengeInputInfo} challenge - carry basic challenge info
 * @return {VerifyInfo[]} The parameters of verifyChallengeSource()
 */
export const getVerifyinfo = async (
  orMakerDeposit: ORMakerDeposit | TestMakerDeposit,
  orManager: ORManager,
  verifyinfoBase: VerifyinfoBase,
  challenge?: challengeInputInfo,
  spv?: TestSpv,
  rule?: RuleStruct,
): Promise<VerifyInfo> => {
  const managerAddress = orManager.address;
  const makerAddress = orMakerDeposit.address;
  const chainId = verifyinfoBase.chainIdSource;
  const chainId_Dest = verifyinfoBase.chainIdDest;
  const freezeToken_Dest = verifyinfoBase.freeTokenDest;
  const freezeToken = verifyinfoBase.freeTokenSource;
  const ebc = verifyinfoBase.ebc;
  // set Verifyinfo 0
  // ORManager.sol - ChainInfo - maxVerifyChallengeSourceTxSecond | minVerifyChallengeSourceTxSecond
  // slot 2
  let slot0;
  const slot0_I = keccak256(solidityPack(['uint256', 'uint256'], [chainId, 2]));
  const value0 =
    utils.hexZeroPad(
      (
        await orManager.getChainInfo(5)
      ).maxVerifyChallengeDestTxSecond.toHexString(),
      8,
    ) +
    utils
      .hexZeroPad(
        (
          await orManager.getChainInfo(5)
        ).minVerifyChallengeDestTxSecond.toHexString(),
        8,
      )
      .slice(2) +
    utils
      .hexZeroPad(
        (
          await orManager.getChainInfo(5)
        ).maxVerifyChallengeSourceTxSecond.toHexString(),
        8,
      )
      .slice(2) +
    utils
      .hexZeroPad(
        (
          await orManager.getChainInfo(5)
        ).minVerifyChallengeSourceTxSecond.toHexString(),
        8,
      )
      .slice(2);
  {
    const { slot, itemSlot, value } = await getMappingStructXSlot(
      '0x2',
      managerAddress,
      BigNumber.from(chainId).toHexString(),
      1,
      'number',
    );

    const newValue = utils.hexZeroPad(BigNumber.from(value).toHexString(), 32);

    const storageValue = await ethers.provider.getStorageAt(
      managerAddress,
      utils.hexZeroPad(itemSlot, 32),
    );
    slot0 = itemSlot;
    expect(slot0_I).to.equal(slot).to.equal(BigNumber.from(itemSlot).sub(1));
    expect(value0).to.equal(newValue).to.equal(storageValue);
  }
  // --------------------------------------------------------------
  // set Verifyinfo 1
  // ORManager.sol - chainTokenInfo - mainnetToken
  // slot 3
  let slot1;
  const slot1_I = keccak256(
    solidityPack(
      ['uint256', 'uint256'],
      [
        keccak256(solidityPack(['uint256', 'uint256'], [chainId, freezeToken])),
        3,
      ],
    ),
  );
  // slot value: address mainnetToken + uint8 decimals;
  const value1 =
    utils.hexZeroPad(
      BigNumber.from(
        (await orManager.getChainTokenInfo(chainId, freezeToken)).decimals,
      ).toHexString(),
      12,
    ) +
    (
      await orManager.getChainTokenInfo(chainId, freezeToken)
    ).mainnetToken.slice(2);

  {
    const hashKey = keccak256(
      solidityPack(['uint256', 'uint256'], [chainId, freezeToken]),
    );
    const { slot, itemSlot, value } = await getMappingStructXSlot(
      '0x3',
      managerAddress,
      hashKey,
      1,
      'number',
    );

    const storageValue = await ethers.provider.getStorageAt(
      managerAddress,
      utils.hexZeroPad(itemSlot, 32),
    );

    slot1 = itemSlot;
    expect(slot).to.equal(slot1_I).to.equal(BigNumber.from(itemSlot).sub(1));
    expect(value1.toLocaleLowerCase()).to.equal(storageValue);
  }

  // --------------------------------------------------------------
  // set Verifyinfo 2
  // ORManager.sol - _challengeUserRatio
  // slot: 6
  // slot value = int64 private _minChallengeRatio +
  // uint64 private _challengeUserRatio +
  // uint64 private _feeChallengeSecond +
  // uint64 private _feeTakeOnChallengeSecond
  let value2;
  const slot2 = BigNumber.from(6).toHexString();
  const minChallengeRatioValue2 = (
    await orManager.minChallengeRatio()
  ).toBigInt();
  {
    const storageValue = await ethers.provider.getStorageAt(
      managerAddress,
      utils.hexZeroPad(slot2, 32),
    );
    const minChallengeRatio = BigNumber.from(
      '0x' + storageValue.slice(-16),
    ).toBigInt();
    value2 = storageValue;
    expect(minChallengeRatioValue2).to.equal(minChallengeRatio);
  }

  // --------------------------------------------------------------
  // set Verifyinfo 3
  // ORMakerDeposit.sol - _columnArrayHash
  // slot: 3
  const slot3 = BigNumber.from(3).toHexString();
  const value3: BytesLike = await orMakerDeposit.columnArrayHash();
  {
    const storageValue = await ethers.provider.getStorageAt(
      makerAddress,
      utils.hexZeroPad(slot3, 32),
    );
    expect(value3).to.equal(storageValue);
  }

  // --------------------------------------------------------------
  // set Verifyinfo 4
  // ORManager.sol - chainTokenInfo - mainnetToken
  // slot 3
  let slot4;
  const slot4_I = keccak256(
    defaultAbiCoder.encode(
      ['uint256', 'uint256'],
      [
        keccak256(
          defaultAbiCoder.encode(
            ['uint256', 'uint256'],
            [chainId_Dest, freezeToken_Dest],
          ),
        ),
        3,
      ],
    ),
  );
  // slot value: address mainnetToken + uint8 decimals;
  const value4 =
    utils.hexZeroPad(
      BigNumber.from(
        (await orManager.getChainTokenInfo(chainId_Dest, freezeToken_Dest))
          .decimals,
      ).toHexString(),
      12,
    ) +
    (
      await orManager.getChainTokenInfo(chainId_Dest, freezeToken_Dest)
    ).mainnetToken.slice(2);
  {
    const hashKey = keccak256(
      defaultAbiCoder.encode(
        ['uint256', 'uint256'],
        [chainId_Dest, freezeToken_Dest],
      ),
    );
    const { slot, itemSlot, value } = await getMappingStructXSlot(
      '0x3',
      managerAddress,
      hashKey,
      1,
      'number',
    );

    const storageValue = await ethers.provider.getStorageAt(
      managerAddress,
      utils.hexZeroPad(itemSlot, 32),
    );

    // const contractSlotK = await spv.createFreezeTokenSlotKey(
    //   chainId_Dest,
    //   freezeToken_Dest,
    // );
    slot4 = itemSlot;
    expect(slot).to.equal(slot4_I).to.equal(BigNumber.from(itemSlot).sub(1));
    // .to.equal(contractSlotK);
    expect(value4.toLocaleLowerCase()).to.equal(storageValue);
  }
  // --------------------------------------------------------------
  // set Verifyinfo 5
  // ORMakerDeposit.sol - responseMakersHash
  // slot 5
  const slot5 = BigNumber.from(5).toHexString();
  const value5: BytesLike = await orMakerDeposit.responseMakersHash();
  {
    const storageValue = await ethers.provider.getStorageAt(
      makerAddress,
      utils.hexZeroPad(slot5, 32),
    );
    expect(value5).to.equal(storageValue);
  }

  // --------------------------------------------------------------
  // set Verifyinfo 6
  // ORMakerDeposit.sol - ruleRoot
  // slot 6
  let slot6;
  let slot7;
  const slot6_I = keccak256(solidityPack(['uint256', 'uint256'], [ebc, 6]));
  let value6;
  let value7;
  {
    const { root, version } = await orMakerDeposit.rulesRoot(ebc);
    // value6 = root;
    const hashKey = keccak256(
      defaultAbiCoder.encode(['uint256', 'uint256'], [ebc, 6]),
    );
    const valueRoot = (
      await getMappingStructXSlot('0x6', makerAddress, ebc, 0, 'bytes')
    ).value;
    const valueVersion = (
      await getMappingStructXSlot('0x6', makerAddress, ebc, 1, 'number')
    ).value;

    const valueRootitemSlot = (
      await getMappingStructXSlot('0x6', makerAddress, ebc, 0, 'bytes')
    ).itemSlot;
    const valueVersionitemSlot = (
      await getMappingStructXSlot('0x6', makerAddress, ebc, 1, 'number')
    ).itemSlot;

    slot6 = valueRootitemSlot;
    value6 = valueRoot ? utils.hexZeroPad(valueRoot.toHexString(), 32) : '0x00';
    slot7 = valueVersionitemSlot;
    value7 = valueVersion
      ? utils.hexZeroPad(valueVersion.toHexString(), 32)
      : '0x00';

    expect(slot6_I).to.equal(hashKey);
    expect(BigNumber.from(value6)).to.equal(
      BigNumber.from(valueRoot?.toHexString()),
    );
    expect(version).to.equal(BigNumber.from(valueVersion).toNumber());
  }

  const slotValue: VerifyInfoSlotStruct[] = [
    {
      // verifyInfo 0
      // ORManager.sol - ChainInfo - maxVerifyChallengeSourceTxSecond | minVerifyChallengeSourceTxSecond
      // slot: 2
      // itemSlot: 1
      account: managerAddress,
      key: slot0,
      value: value0,
    },
    {
      // verifyInfo 1
      // ORManager.sol - chainTokenInfo - mainnetToken (sourceChain)
      // slot: 3
      // itemSlot: 1
      account: managerAddress,
      key: slot1,
      value: value1,
    },
    {
      // verifyInfo 2
      // ORManager.sol - _challengeUserRatio
      // slot: 5
      account: managerAddress,
      key: utils.hexZeroPad(slot2, 32),
      value: value2,
    },
    {
      // verifyInfo 3
      // ORMakerDeposit.sol - _columnArrayHash
      // slot: 3
      account: makerAddress,
      key: utils.hexZeroPad(slot3, 32),
      value: value3,
    },
    {
      // verifyInfo 4
      // ORManager.sol - chainTokenInfo - mainnetToken (destChain)
      // slot: 3
      // itemSlot: 1
      account: managerAddress,
      key: slot4,
      value: value4,
    },
    {
      // Verifyinfo 5
      // ORMakerDeposit.sol - responseMakersHash
      // slot 5
      account: makerAddress,
      key: utils.hexZeroPad(slot5, 32),
      value: value5,
    },
    {
      // Verifyinfo 6
      // ORMakerDeposit.sol - ruleRoot
      // slot 6
      account: makerAddress,
      key: slot6,
      value: value6,
    },
    {
      // Verifyinfo 7
      // ORMakerDeposit.sol - ruleVersion
      // slot 7
      account: makerAddress,
      key: slot7,
      value: value7,
    },
  ];

  // --------------------------------------------------------------
  // set VerifyInfo.data
  let dataVelue: BigNumberish[] = [];
  if (rule != undefined && spv != undefined && challenge != undefined) {
    const encodeRule = encodeRuleStruct(rule);
    expect(encodeRule).to.be.equal(await spv.createEncodeRule(rule));

    dataVelue = [
      chainId,
      challenge.sourceTxHash,
      challenge.from,
      BigNumber.from(0),
      freezeToken,
      challenge.freezeAmount,
      0,
      challenge.sourceTxTime,
      encodeRule,
      chainId_Dest,
      freezeToken_Dest,
    ];
  }

  const VerifyInfo: VerifyInfo = {
    data: dataVelue,
    slots: slotValue,
  };
  // console.log(`mangerAddress: ${managerAddress}, makerAddress: ${makerAddress}, sourceChainId: ${chainId}, chainId_Dest: ${chainId_Dest}, freezeToken_Dest: ${freezeToken_Dest}, freezeToken: ${freezeToken}, ebc: ${ebc}`);
  // console.log(VerifyInfo);
  return VerifyInfo;
};

export const createChallenge = async (
  orMakerDeposit: ORMakerDeposit | TestMakerDeposit,
  challenge: challengeInputInfo,
  rule: BigNumberish[],
  revertReason?: string,
): Promise<
  Partial<{
    challengeId: BigNumberish;
    challengeInfo: any;
    gasUsed: BigNumberish;
    revertReason: string;
  }>
> => {
  // const minDeposit = utils.parseEther('0.005');
  const minDeposit = 0;
  if (revertReason == undefined) {
    const challengeIdentNum = challengeManager.getChallengeIdentNumSortList(
      challenge.sourceTxTime,
      challenge.sourceChainId,
      challenge.sourceBlockNum,
      challenge.sourceTxIndex,
    );
    challengeManager.addNum(challengeIdentNum);
    const parentNodeNumOfTargetNode = challengeManager.getLastChallengeIdentNum(
      challengeManager.numList,
      challengeIdentNum,
    );
    challenge.parentNodeNumOfTargetNode = parentNodeNumOfTargetNode;
    const tx = await orMakerDeposit
      .challenge(
        challenge.sourceTxTime,
        challenge.sourceChainId,
        challenge.sourceBlockNum,
        challenge.sourceTxIndex,
        challenge.sourceTxHash.toString(),
        challenge.freezeToken,
        challenge.freezeAmount,
        challenge.parentNodeNumOfTargetNode,
        { value: BigNumber.from(challenge.freezeAmount).add(minDeposit) },
      )
      .then((t) => t.wait(1));
    const args = tx.events?.[0].args;
    const basefee = (await ethers.provider.getFeeData()).lastBaseFeePerGas;
    await calculateTxGas(tx, `Create challenge!`);

    // console.log(
    //   'input',
    //   (await ethers.provider.getTransaction(tx.transactionHash)).data,
    // );

    // console.log(
    //   // 'challenge input:',
    //   // (await ethers.provider.getTransaction(tx.transactionHash)).data,
    //   // 'chailneId:',
    //   // challenge.sourceChainId,
    //   'Create challenge! gasUsed:',
    //   tx.gasUsed.toNumber(),
    //   'inputGasUsed',
    //   callDataCost(
    //     (await ethers.provider.getTransaction(tx.transactionHash)).data,
    //   ),
    //   // 'basefee',
    //   // basefee?.toNumber(),
    //   // 'challengerVerifyTransactionFee',
    //   // args?.statement.challengerVerifyTransactionFee.div(basefee).toNumber(),
    // );

    expect(args).not.empty;
    if (!!args) {
      expect(args.challengeId).not.empty;
      expect(args.statement.sourceTxFrom).eql(BigNumber.from(0));
      expect(args.statement.sourceTxTime).eql(
        BigNumber.from(challenge.sourceTxTime),
      );
      expect(args.statement.freezeToken).eql(challenge.freezeToken);
      expect(args.statement.freezeAmount0).eql(challenge.freezeAmount);
      expect(args.statement.freezeAmount1).eql(challenge.freezeAmount);
    }

    challengeManager.addChallengeNodeInfo({
      sourceChainId: challenge.sourceChainId,
      sourceTxHash: challenge.sourceTxHash,
      challengeIdentNum: challengeIdentNum,
      challenge: challenge,
      liquidated: false,
    });

    return {
      challengeId: args?.challengeId,
      challengeInfo: args?.challengeInfo,
      gasUsed: tx.gasUsed,
    };
  } else {
    await expect(
      orMakerDeposit.challenge(
        challenge.sourceTxTime,
        challenge.sourceChainId,
        challenge.sourceBlockNum,
        challenge.sourceTxIndex,
        challenge.sourceTxHash.toString(),
        challenge.freezeToken,
        challenge.freezeAmount,
        challenge.parentNodeNumOfTargetNode,
        { value: BigNumber.from(challenge.freezeAmount).add(minDeposit) },
      ),
    ).to.revertedWith(revertReason);
    return { revertReason };
  }
};

export const getBlockHash = async (BlockNumber: number): Promise<String> => {
  const blcokHash = (await ethers.provider.getBlock(BlockNumber))?.hash;
  return blcokHash;
};

export const predictEnableBlock = async (
  currentBlockNumber: number,
  enableTimestamp: number,
) => {
  const configTimestamp = (await ethers.provider.getBlock(currentBlockNumber))
    .timestamp;
  const timeStampGap = enableTimestamp - configTimestamp;
  assert(enableTimestamp > configTimestamp, 'timestamp error');
  const enableBlockNumber = Math.trunc(timeStampGap / 12 + currentBlockNumber);
  const enableBlockHash = await getBlockHash(enableBlockNumber);
  assert(enableBlockHash != undefined, 'block are not generated yet');
  return {
    enableBlockNumber,
    enableBlockHash,
  };
};

export const calculateTxGas = async (
  tx: ContractReceipt,
  title?: string,
  index?: number,
) => {
  const gasUsed = tx.gasUsed.toNumber();
  const gasPrice = tx.effectiveGasPrice?.toNumber();
  const gasFee = gasUsed * gasPrice;
  const inputGasUsed = callDataCost(
    (await ethers.provider.getTransaction(tx.transactionHash)).data,
  );
  console.log(
    title ? title : 'gasUsed',
    index ? index : '',
    'total_Gas:',
    gasUsed,
    'excution_Gas',
    gasUsed - inputGasUsed - 21000,
    'inputData_Gas:',
    inputGasUsed,
  );
};

export const liquidateChallenge = async (
  orMakerDeposit: ORMakerDeposit | TestMakerDeposit,
  challengeNodeList: challengeNodeInfoList[],
  chalengers: string[],
) => {
  assert(
    challengeNodeList
      .map((item) => item.sourceChainId)
      .every((val, i, arr) => val === arr[0]),
    'sourceChainId are not same',
  );
  assert(
    challengeNodeList
      .map((item) => item.sourceTxHash)
      .every((val, i, arr) => val === arr[0]),
    'sourceTxHash are not same',
  );

  let checkGasUsed = BigNumber.from(0);
  const challengeNode = challengeNodeList[0];
  const tx = await orMakerDeposit
    .checkChallenge(
      challengeNode.sourceChainId,
      challengeNode.sourceTxHash,
      chalengers,
    )
    .then((t) => t.wait(1));
  const gasUsed = tx.gasUsed;
  const effectiveGasPrice = tx.effectiveGasPrice;
  await calculateTxGas(tx, `Liquidation ${chalengers.length} challengers!`);
  tx.events?.forEach((event, index) => {
    const args = event.args!;
    const challengeNode = challengeNodeList[index];
    expect(args.challengeId).not.empty;
    expect(args.statement.sourceTxTime).eql(
      BigNumber.from(challengeNode.challenge.sourceTxTime),
    );
    expect(args.statement.freezeToken).eql(challengeNode.challenge.freezeToken);
    expect(args.statement.freezeAmount0).eql(
      challengeNode.challenge.freezeAmount,
    );
    expect(args.statement.freezeAmount1).eql(
      challengeNode.challenge.freezeAmount,
    );
    checkGasUsed = checkGasUsed.add(tx.gasUsed);
  });
  expect(tx.events?.length).to.equal(chalengers.length);
  challengeNodeList.forEach((item) => {
    challengeManager.liquidateChallengeNodeInfo(item.index!, true);
  });
};

export class challengeManager {
  static challengeInfoList: challengeInputInfo[] = [];
  static challengeNodeInfoList: challengeNodeInfoList[] = [];
  static sortingNodeInfoList: challengeNodeInfoList[] = [];
  static numList: bigint[] = [];
  static numSortingList: bigint[] = [];

  static initialize() {
    this.challengeInfoList = [];
    this.challengeNodeInfoList = [];
    this.sortingNodeInfoList = [];
    this.numList = [];
    this.numSortingList = [];
  }

  static addChallengeInfo(challengeInfo: challengeInputInfo) {
    this.challengeInfoList.push(challengeInfo);
  }

  static getChallengeInfoList() {
    return this.sortingNodeInfoList.filter((v) => !v.liquidated);
  }

  static addChallengeNodeInfo(challengeNodeInfo: challengeNodeInfoList) {
    this.challengeNodeInfoList.push(challengeNodeInfo);
    this.sortingNodeInfoList = this.challengeNodeInfoList.sort((a, b) => {
      if (a.challengeIdentNum > b.challengeIdentNum) return 1;
      if (a.challengeIdentNum < b.challengeIdentNum) return -1;
      return 0;
    });
    this.sortingNodeInfoList.forEach((item, index) => {
      if (item.index == undefined) {
        item.index = index;
      }
    });
  }

  static addNum(challengeIdentNum: bigint) {
    this.numList.push(challengeIdentNum);
    this.numSortingList = this.numList.sort((a, b) => {
      if (a > b) return -1;
      if (a < b) return 1;
      return 0;
    });
  }

  static liquidateChallengeNodeInfo(index: number, liquidated: boolean) {
    this.sortingNodeInfoList.forEach((item) => {
      if (item.index == index) {
        item.liquidated = liquidated;
      }
    });
  }

  static getChallengeIdentNumSortList(
    sourceTxTime: any,
    sourceChainId: any,
    sourceBlockNum: any,
    sourceTxIndex: any,
  ): bigint {
    let challengeIdentNum = BigInt(sourceTxTime);

    challengeIdentNum =
      (challengeIdentNum << BigInt(64)) | BigInt(sourceChainId);
    challengeIdentNum =
      (challengeIdentNum << BigInt(64)) | BigInt(sourceBlockNum);
    challengeIdentNum =
      (challengeIdentNum << BigInt(64)) | BigInt(sourceTxIndex);

    return challengeIdentNum;
  }

  static getLastChallengeIdentNum(
    challengeIdentNumList: bigint[],
    challengeIdentNum: bigint,
  ) {
    let parentNodeNumOfTargetNode = null;
    if (challengeIdentNumList.length > 0) {
      const challengeIdentNumSortList = challengeIdentNumList.sort((a, b) => {
        if (a > b) return -1;
        if (a < b) return 1;
        return 0;
      });
      let lastNum = 0n;
      let index = 0;
      while (
        index <= challengeIdentNumSortList.length - 1 &&
        challengeIdentNum < challengeIdentNumSortList[index]
      ) {
        lastNum = challengeIdentNumSortList[index];
        index++;
      }
      parentNodeNumOfTargetNode = lastNum;
    } else {
      parentNodeNumOfTargetNode = 0;
    }
    return parentNodeNumOfTargetNode;
  }
}

export const updateMakerRule = async (
  orMakerDeposit: ORMakerDeposit | TestMakerDeposit,
  ebc: string,
  rule?: RuleStruct,
  modifyRule = false,
): Promise<BigNumberish[]> => {
  const rules: any[] = [];
  const defaultRule: RuleStruct =
    rule != undefined ? rule : createMakerRule(true);
  const newRule: RuleStruct = {
    ...defaultRule,
    compensationRatio0: modifyRule
      ? defaultRule.compensationRatio0 + random(2, 10)
      : defaultRule.compensationRatio0,
    compensationRatio1: modifyRule
      ? defaultRule.compensationRatio1 + random(2, 10)
      : defaultRule.compensationRatio1,
  };

  rules.push(converRule(newRule));

  const tree = await calculateRulesTree(rules);
  const root = utils.hexlify(tree.root);

  const currentRootwithVersion = await orMakerDeposit.getVersionAndEnableTime();
  // console.log('currentRootwithVersion', currentRootwithVersion);
  const version = (await orMakerDeposit.rulesRoot(ebc)).version + 1;

  const rootWithVersion = { root, version };
  const sourceChainIds = [1];
  const pledgeAmounts = [utils.parseEther('0.000001')];
  const statuses = await ethers.provider.getBlock('latest');
  const oldTimeStamp =
    statuses.timestamp > currentRootwithVersion.enableTime.toNumber()
      ? statuses.timestamp
      : currentRootwithVersion.enableTime.toNumber();
  const enableTime = getMinEnableTime(BigNumber.from(oldTimeStamp));

  console.log(
    `update current timestamp: ${
      statuses.timestamp
    }, enableTime: ${enableTime}, currBlk:${
      statuses.number
    } predict enable block: ${(
      (enableTime.toNumber() - statuses.timestamp) / 12 +
      statuses.number
    ).toFixed(0)}`,
  );

  const { events } = await orMakerDeposit
    .updateRulesRoot(
      enableTime,
      ebc,
      rules,
      rootWithVersion,
      sourceChainIds,
      pledgeAmounts,
      {
        value: pledgeAmounts.reduce((pv, cv) => pv.add(cv)),
      },
    )
    .then((t: any) => t.wait(1));
  console.log('newRule:', newRule);

  return converRule(newRule);
};

export const getRLPEncodeMakerRuleHash = (rule: BigNumberish[]) => {
  const rlpRawdata = utils.RLP.encode(
    rule.map((r) => utils.stripZeros(BigNumber.from(r).toHexString())),
  );
  const encodeHash = utils.keccak256(rlpRawdata);
  return {
    rlpRawdata: rlpRawdata,
    encodeHash: encodeHash,
  };
};

export const getRawDataNew = async (columnArray: columnArray, ebc: string) => {
  const jsEncode = encodeChallengeRawDataWORule(
    columnArray.dealers,
    columnArray.ebcs,
    columnArray.chainIds,
    ebc,
  );

  const columnArrayHash = utils.keccak256(
    utils.defaultAbiCoder.encode(
      ['uint256[]', 'uint256[]', 'uint256[]'],
      [columnArray.dealers, columnArray.ebcs, columnArray.chainIds],
    ),
  );
  // expect(columnArrayHash).eql(await orMakerDeposit.columnArrayHash());

  return {
    rawData: utils.arrayify(jsEncode),
    columnArrayHash: columnArrayHash,
  };
};

export const mockSpvData = async (
  orSpvData: ORSpvData,
  injectionBlocksRoots: string[],
): Promise<void> => {
  const _injectionBlocksRoots: IORSpvData.InjectionBlocksRootStruct[] = [];
  await mineUpTo(1200);
  const receipt1 = await orSpvData
    .saveHistoryBlocksRoots()
    .then((t) => t.wait());
  const events1 = receipt1.events!;
  const startBlock1 = BigNumber.from(events1[0].args?.['startBlockNumber']);
  const blocksRoot1 = BigNumber.from(
    events1[0].args?.['blocksRoot'],
  ).toHexString();
  await mineUpTo(10000);
  const receipt2 = await orSpvData
    .saveHistoryBlocksRoots()
    .then((t) => t.wait());
  const events2 = receipt2.events!;
  const startBlock2 = BigNumber.from(
    events2[events2.length - 1].args?.['startBlockNumber'],
  );
  const blocksRoot2 = BigNumber.from(
    events2[events2.length - 1].args?.['blocksRoot'],
  ).toHexString();
  let currBlk = BigNumber.from(startBlock1);
  for (let i = 0; i < injectionBlocksRoots.length; i++) {
    currBlk = currBlk.add(192);
    _injectionBlocksRoots.push({
      startBlockNumber: currBlk,
      blocksRoot: injectionBlocksRoots[i],
    });
  }

  for (let i = 0; i < injectionBlocksRoots.length; i++) {
    const receipt = await orSpvData
      .injectBlocksRoots(blocksRoot1, blocksRoot2, [_injectionBlocksRoots[i]])
      .then((t) => t.wait(1));
    const events = receipt.events!;
    mineXTimes(100);
  }
};
