import { ethers } from 'hardhat';
import { expect } from 'chai';
import 'cross-fetch/polyfill';
import { BigNumber, BigNumberish, ContractTransaction, utils } from 'ethers';
import { ORMakerDeposit, ORManager, TestSpv } from '../typechain-types';
import { callDataCost, getCurrentTime } from './lib/mockData';
import { RuleStruct, encodeRuleStruct } from './lib/rule';
import {
  BytesLike,
  defaultAbiCoder,
  keccak256,
  solidityPack,
} from 'ethers/lib/utils';
import { getMappingStructXSlot } from './lib/readStorage';
import { assert } from 'console';

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
        : BigNumber.from(Date.now()).add(MIN_ENABLE_DELAY);
    return minEnableTime.add(1);
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
  sourceBlockNum: number;
  sourceTxIndex: number;
  sourceTxHash: BigNumberish;
  from: string;
  freezeToken: string;
  freezeAmount: BigNumberish;
  lastChallengeIdentNum: BigNumberish;
}

export interface verifyinfoBase {
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

export const updateSpv = async (
  challengeInputInfo: challengeInputInfo,
  spvAddress: string,
  _orManager: ORManager,
) => {
  const enableTimeTime =
    // eslint-disable-next-line prettier/prettier
    (await getCurrentTime()) >
      (await _orManager.getVersionAndEnableTime()).enableTime.toNumber()
      ? await getCurrentTime()
      : (await _orManager.getVersionAndEnableTime()).enableTime;

  const { events } = await _orManager
    .updateChainSpvs(
      getMinEnableTime(BigNumber.from(enableTimeTime)),
      challengeInputInfo.sourceChainId,
      [spvAddress],
      [0],
      {
        gasLimit: 10e6,
      },
    )
    .then((t) => t.wait());
  expect(
    (await _orManager.getChainInfo(challengeInputInfo.sourceChainId)).spvs,
  ).to.deep.includes(spvAddress);
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

  const securityCode = dealerIndex
    .toString()
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
  orMakerDeposit: ORMakerDeposit,
  orManager: ORManager,
  spv: TestSpv,
  challenge: challengeInputInfo,
  verifyinfoBase: verifyinfoBase,
  rule: RuleStruct,
): Promise<VerifyInfo> => {
  const managerAddress = orManager.address;
  const makerAddress = orMakerDeposit.address;
  const chainId = challenge.sourceChainId;
  const chainId_Dest = verifyinfoBase.chainIdDest;
  const freezeToken_Dest = verifyinfoBase.freeTokenDest;
  const freezeToken = challenge.freezeToken;
  const ebc = verifyinfoBase.ebc;
  const chainIdDest = verifyinfoBase.chainIdDest;
  console.log('ebc', ebc);
  // set Verifyinfo 0
  // ORManager.sol - ChainInfo - maxVerifyChallengeSourceTxSecond | minVerifyChallengeSourceTxSecond
  // slot 2
  let slot0;
  const slot0_I = keccak256(solidityPack(['uint256', 'uint256'], [chainId, 2]));
  const value0 =
    utils.hexZeroPad(
      (
        await orManager.getChainInfo(5)
      ).maxVerifyChallengeSourceTxSecond.toHexString(),
      8,
    ) +
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

    const newValue = '0x' + BigNumber.from(value).toHexString().slice(-32);
    const storageValue =
      '0x' +
      (
        await ethers.provider.getStorageAt(
          managerAddress,
          utils.hexZeroPad(itemSlot, 32),
        )
      ).slice(-32);
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
  const value1 = (await orManager.getChainTokenInfo(chainId, freezeToken))
    .mainnetToken;
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

    const storageValue =
      '0x' +
      (
        await ethers.provider.getStorageAt(
          managerAddress,
          utils.hexZeroPad(itemSlot, 32),
        )
      ).slice(-40);

    const value1_S =
      '0x' +
      utils.hexZeroPad(BigNumber.from(value).toHexString(), 32).slice(-40);
    slot1 = itemSlot;
    expect(slot).to.equal(slot1_I).to.equal(BigNumber.from(itemSlot).sub(1));
    expect(value1.toLocaleLowerCase())
      .to.equal(value1_S)
      .to.equal(storageValue);
  }

  // --------------------------------------------------------------
  // set Verifyinfo 2
  // ORManager.sol - _minChallengeRatio
  // slot: 6
  const slot2 = BigNumber.from(6).toHexString();
  const value2 = (await orManager.minChallengeRatio()).toBigInt();
  {
    const storageValue = await ethers.provider.getStorageAt(
      managerAddress,
      utils.hexZeroPad(slot2, 32),
    );
    const minChallengeRatio = BigNumber.from(
      '0x' + storageValue.slice(-16),
    ).toBigInt();
    expect(value2).to.equal(minChallengeRatio);
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
  const value4 = (
    await orManager.getChainTokenInfo(chainId_Dest, freezeToken_Dest)
  ).mainnetToken;
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

    const storageValue =
      '0x' +
      (
        await ethers.provider.getStorageAt(
          managerAddress,
          utils.hexZeroPad(itemSlot, 32),
        )
      ).slice(-40);

    const contractSlotK = await spv.createFreezeTokenSlotKey(
      chainId_Dest,
      freezeToken_Dest,
    );

    const value4_S =
      '0x' +
      utils.hexZeroPad(BigNumber.from(value).toHexString(), 32).slice(-40);
    slot4 = itemSlot;
    expect(slot)
      .to.equal(slot4_I)
      .to.equal(BigNumber.from(itemSlot).sub(1))
      .to.equal(contractSlotK);
    expect(value4.toLocaleLowerCase())
      .to.equal(value4_S)
      .to.equal(storageValue);
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
  const slot6_I = keccak256(solidityPack(['uint256', 'uint256'], [ebc, 6]));
  let value6;
  {
    const { root, version } = await orMakerDeposit.rulesRoot(ebc);
    value6 = root;
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

    slot6 = slot6_I;
    expect(slot6_I).to.equal(hashKey);
    expect(value6).to.equal(valueRoot?.toHexString());
    expect(version).to.equal(BigNumber.from(valueVersion).toNumber());

    // console.log(
    //   `root slot :${valueRootitemSlot}, version slot: ${valueVersionitemSlot}`,
    // );
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
      // ORManager.sol - _rulesRoots
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
  ];

  // --------------------------------------------------------------
  // set VerifyInfo.data
  const encodeRule = encodeRuleStruct(rule);
  expect(encodeRule).to.be.equal(await spv.createEncodeRule(rule));

  const dataVelue: BigNumberish[] = [
    chainId,
    challenge.sourceTxHash,
    challenge.from,
    BigNumber.from(0),
    freezeToken,
    challenge.freezeAmount,
    0,
    challenge.sourceTxTime,
    encodeRule,
    chainIdDest,
    freezeToken_Dest,
  ];

  const VerifyInfo: VerifyInfo = {
    data: dataVelue,
    slots: slotValue,
  };
  console.log(VerifyInfo);
  return VerifyInfo;
};

export const getChallengeIdentNumSortList = (
  sourceTxTime: any,
  sourceChainId: any,
  sourceBlockNum: any,
  sourceTxIndex: any,
): bigint => {
  let challengeIdentNum = BigInt(sourceTxTime);

  challengeIdentNum = (challengeIdentNum << BigInt(64)) | BigInt(sourceChainId);
  challengeIdentNum =
    (challengeIdentNum << BigInt(64)) | BigInt(sourceBlockNum);
  challengeIdentNum = (challengeIdentNum << BigInt(64)) | BigInt(sourceTxIndex);

  return challengeIdentNum;
};

export const getLastChallengeIdentNum = (
  challengeIdentNumList: bigint[],
  challengeIdentNum: bigint,
) => {
  let lastChallengeIdentNum = null;
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
    lastChallengeIdentNum = lastNum;
  } else {
    lastChallengeIdentNum = 0;
  }
  return lastChallengeIdentNum;
};

export const createChallenge = async (
  orMakerDeposit: ORMakerDeposit,
  challenge: challengeInputInfo,
  revertReason?: string,
): Promise<
  Partial<{
    challengeId: BigNumberish;
    challengeInfo: any;
    gasUsed: BigNumberish;
    revertReason: string;
  }>
> => {
  const minDeposit = utils.parseEther('0.005');
  if (revertReason != undefined) {
    await expect(
      orMakerDeposit.challenge(
        challenge.sourceTxTime,
        challenge.sourceChainId,
        challenge.sourceBlockNum,
        challenge.sourceTxIndex,
        challenge.sourceTxHash.toString(),
        challenge.freezeToken,
        challenge.freezeAmount,
        challenge.lastChallengeIdentNum,
        { value: BigNumber.from(challenge.freezeAmount).add(minDeposit) },
      ),
    ).to.revertedWith(revertReason);
    return { revertReason };
  } else {
    const tx = await orMakerDeposit
      .challenge(
        challenge.sourceTxTime,
        challenge.sourceChainId,
        challenge.sourceBlockNum,
        challenge.sourceTxIndex,
        challenge.sourceTxHash.toString(),
        challenge.freezeToken,
        challenge.freezeAmount,
        challenge.lastChallengeIdentNum,
        { value: BigNumber.from(challenge.freezeAmount).add(minDeposit) },
      )
      .then((t) => t.wait());
    const args = tx.events?.[0].args;
    // const basefee = (await ethers.provider.getFeeData()).lastBaseFeePerGas;
    console.log(
      // 'challenge input:',
      // (await ethers.provider.getTransaction(tx.transactionHash)).data,
      // 'chailneId:',
      // challenge.sourceChainId,
      'gasUsed:',
      tx.gasUsed.toNumber(),
      'inputGasUsed',
      callDataCost(
        (await ethers.provider.getTransaction(tx.transactionHash)).data,
      ),
      // 'basefee',
      // basefee,
      // 'challengerVerifyTransactionFee',
      // args?.statement.challengerVerifyTransactionFee.div(basefee),
    );

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
    return {
      challengeId: args?.challengeId,
      challengeInfo: args?.challengeInfo,
      gasUsed: tx.gasUsed,
    };
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
