import { expect } from 'chai';
import 'cross-fetch/polyfill';
import { ContractTransaction, utils } from 'ethers';
import { ORManager } from '../typechain-types';
import { writeFileSync } from 'fs';

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
  let succeed = false;

  try {
    await transaction.then((t) => t.wait());
    succeed = true;
  } catch (err: any) {
    const reg = new RegExp(`reason=.*?${reason}`, 'i');
    const match = reg.exec(err.message);

    expect(!!match?.[0]).to.be.eq(true);
  }

  if (succeed)
    throw new Error(`should reverted with reason string '${reason}'`);
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
