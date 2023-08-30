import { expect } from 'chai';
import 'cross-fetch/polyfill';
import { BigNumber, BigNumberish, ContractTransaction, utils } from 'ethers';
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
    const reg = new RegExp(`reason=.*?${reason}.*?transaction=`, 'i');
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
export function getMinEnableTime() {
  const minEnableTime = BigNumber.from(
    Date.now() + MIN_ENABLE_DELAY * 1000,
  ).div(1000);
  return minEnableTime.add(200); // Keep time
}
