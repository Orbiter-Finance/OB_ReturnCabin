import { Provider } from '@ethersproject/providers';
import { BigNumber, BigNumberish, BytesLike, Wallet, utils } from 'ethers';
import { Hexable } from 'ethers/lib/utils';
import MerkleTree from 'merkletreejs';
import Pako from 'pako';

export const ruleTypes = [
  'uint16',
  'uint16',
  'uint8',
  'uint8',
  'uint',
  'uint',
  'uint128',
  'uint128',
  'uint128',
  'uint128',
  'uint16',
  'uint16',
  'uint32',
  'uint32',
  'uint32',
  'uint32',
];

export function createRandomRule() {
  return [
    1, // chain0
    2, // chain1
    0, // chain0's status
    1, // chain1's status
    Wallet.createRandom().address, // chain0's token
    Wallet.createRandom().address, // chain1's token
    BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1), // minPrice
    BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1), // maxPrice
    BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1), // chain0's withholdingFee
    BigNumber.from(5).pow(parseInt(Math.random() * 40 + '') + 1), // chain1's withholdingFee
    1, // chain0's tradeFee
    2, // chain1's tradeFee
    (2 ^ 32) - 1, // chain0's response time
    (2 ^ 31) - 1, // chain1's response time
    (2 ^ 30) - 1, // chain0's compensation ratio
    (2 ^ 29) - 1, // chain1's compensation ratio
  ];
}

export function calculateRuleKey(rule: BigNumberish[]) {
  return utils.keccak256(
    utils.solidityPack(
      ['uint16', 'uint16', 'uint8', 'uint8'],
      rule.slice(0, 4),
    ),
  );
}

export async function getRulesRootUpdatedLogs(
  provider: Provider | undefined,
  mdc: string,
  implementation: string,
) {
  const logs = await provider?.getLogs({
    address: mdc,
    topics: [
      utils.id('RulesRootUpdated(address,address,(bytes32,uint32))'),
      utils.hexZeroPad(implementation.toLowerCase(), 32),
    ],
    fromBlock: 0,
    toBlock: 'latest',
  });

  const updateActions: {
    transactionHash: string;
    ebc: string;
    root: string;
    version: number;
  }[] = [];
  for (const log of logs || []) {
    const [ebc, [root, version]] = utils.defaultAbiCoder.decode(
      ['address', 'tuple(bytes32,uint32)'],
      log.data,
    );
    updateActions.push({
      transactionHash: log.transactionHash,
      ebc,
      root,
      version,
    });
  }
  updateActions.sort((a, b) => a.version - b.version);

  const rules: BigNumberish[][] = [];
  for (const item of updateActions) {
    const transaction = await provider?.getTransaction(item.transactionHash);
    if (!transaction) continue;

    const [_, rsc] = utils.defaultAbiCoder.decode(
      ['address', 'bytes', 'tuple(bytes32,uint32)', 'uint16[]', 'uint[]'],
      utils.hexDataSlice(transaction.data, 4),
    );

    const _rules = ungzipRules(rsc);

    for (const _rule of _rules) {
      const k = calculateRuleKey(_rule);
      const index = rules.findIndex((r) => calculateRuleKey(r) == k);

      if (index === -1) rules.push(_rule);
      else rules[index] = _rule;
    }
  }

  return rules;
}

export function calculateRulesMerkleTree(rules: BigNumberish[][]) {
  const leaves = rules
    .map((rule) =>
      utils.keccak256(utils.defaultAbiCoder.encode(ruleTypes, rule)),
    )
    .sort((a, b) => (BigNumber.from(a).sub(b).gt(0) ? 1 : -1));
  return new MerkleTree(leaves, utils.keccak256);
}

export function gzipRules(rules: BigNumberish[][]) {
  const rsEncode = utils.defaultAbiCoder.encode(
    [`tuple(${ruleTypes.join(',')})[]`],
    [rules],
  );
  return utils.hexlify(Pako.gzip(utils.arrayify(rsEncode), { level: 9 }));
}

export function ungzipRules(rsc: BytesLike | Hexable | number) {
  const ungzipData = Pako.ungzip(utils.arrayify(rsc));

  const [rules] = utils.defaultAbiCoder.decode(
    [`tuple(${ruleTypes.join(',')})[]`],
    utils.hexlify(ungzipData),
  );

  return rules as BigNumberish[][];
}
