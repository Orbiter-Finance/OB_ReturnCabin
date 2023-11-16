import { Provider } from '@ethersproject/providers';
import { BigNumber, BigNumberish, BytesLike, utils } from 'ethers';
import { Hexable, keccak256 } from 'ethers/lib/utils';
import { BaseTrie } from 'merkle-patricia-tree';
import Pako from 'pako';
import { hexToBuffer } from '../utils.test';
import { getRulesSetting } from './mockData';

export const ruleTypes = [
  'uint64', // chain0's id
  'uint64', // chain1's id
  'uint8', // chain0's status
  'uint8', // chain1's status
  'uint', // chain0's token
  'uint', // chain1's token
  'uint128', // chain0's minPrice
  'uint128', // chain1's minPrice
  'uint128', // chain0's maxPrice
  'uint128', // chain1's maxPrice
  'uint128', // chain0's withholdingFee
  'uint128', // chain1's withholdingFee
  'uint32', // chain0's tradeFee. 1000,000 percent
  'uint32', // chain1's tradeFee
  'uint32', // chain0's response time
  'uint32', // chain1's response time
  'uint32', // chain0's compensation ratio
  'uint32', // chain1's compensation ratio
];

export interface RuleStruct {
  chainId0: BigNumber;
  chainId1: BigNumber;
  status0: number;
  status1: number;
  token0: BigNumber;
  token1: BigNumber;
  minPrice0: BigNumber;
  minPrice1: BigNumber;
  maxPrice0: BigNumber;
  maxPrice1: BigNumber;
  withholdingFee0: BigNumber;
  withholdingFee1: BigNumber;
  tradingFee0: number;
  tradingFee1: number;
  responseTime0: number;
  responseTime1: number;
  compensationRatio0: number;
  compensationRatio1: number;
}

export function createRandomRule(getNative: boolean) {
  const {
    chain0Id,
    chain1Id,
    chain0token,
    chain1token,
    randomStatus1,
    randomStatus2,
    chain0MinPrice,
    chain0MaxPrice,
    chain1MinPrice,
    chain1MaxPrice,
    chain0withholdingFee,
    chain1withholdingFee,
  } = getRulesSetting(getNative);

  return [
    BigNumber.from(chain0Id).add(0),
    BigNumber.from(chain1Id).add(0),
    randomStatus1,
    randomStatus2,
    chain0token,
    chain1token,
    chain0MinPrice,
    chain0MaxPrice,
    chain1MinPrice,
    chain1MaxPrice,
    chain0withholdingFee,
    chain1withholdingFee,
    1,
    2,
    (2 ^ 32) - 1,
    (2 ^ 31) - 1,
    (2 ^ 30) - 1,
    (2 ^ 29) - 1,
  ];
}

export const formatRule = (rule: BigNumberish[]): RuleStruct => {
  const formatRule: RuleStruct = {
    chainId0: BigNumber.from(rule[0]).add(0),
    chainId1: BigNumber.from(rule[1]).add(0),
    status0: BigNumber.from(rule[2]).toNumber(),
    status1: BigNumber.from(rule[3]).toNumber(),
    token0: BigNumber.from(rule[4]).add(0),
    token1: BigNumber.from(rule[5]).add(0),
    minPrice0: BigNumber.from(rule[6]).add(0),
    minPrice1: BigNumber.from(rule[7]).add(0),
    maxPrice0: BigNumber.from(rule[8]).add(0),
    maxPrice1: BigNumber.from(rule[9]).add(0),
    withholdingFee0: BigNumber.from(rule[10]).add(0),
    withholdingFee1: BigNumber.from(rule[11]).add(0),
    tradingFee0: BigNumber.from(rule[12]).toNumber(),
    tradingFee1: BigNumber.from(rule[13]).toNumber(),
    responseTime0: BigNumber.from(rule[14]).toNumber(),
    responseTime1: BigNumber.from(rule[15]).toNumber(),
    compensationRatio0: BigNumber.from(rule[16]).toNumber(),
    compensationRatio1: BigNumber.from(rule[17]).toNumber(),
  };
  return formatRule;
};

export const createMakerRule = (getNative: boolean): RuleStruct => {
  const {
    chain0Id,
    chain1Id,
    chain0token,
    chain1token,
    randomStatus1,
    randomStatus2,
    chain0MinPrice,
    chain0MaxPrice,
    chain1MinPrice,
    chain1MaxPrice,
    chain0withholdingFee,
    chain1withholdingFee,
  } = getRulesSetting(getNative);

  const rule: RuleStruct = {
    chainId0: BigNumber.from(chain0Id).add(0),
    chainId1: BigNumber.from(chain1Id).add(0),
    status0: randomStatus1,
    status1: randomStatus2,
    token0: BigNumber.from(chain0token),
    token1: BigNumber.from(chain1token),
    minPrice0: chain0MinPrice,
    minPrice1: chain1MinPrice,
    maxPrice0: chain0MaxPrice,
    maxPrice1: chain1MaxPrice,
    withholdingFee0: chain0withholdingFee,
    withholdingFee1: chain1withholdingFee,
    tradingFee0: 1,
    tradingFee1: 1,
    responseTime0: 2 ^ (32 - 1),
    responseTime1: 2 ^ (31 - 1),
    compensationRatio0: 2 ^ (30 - 1),
    compensationRatio1: 2 ^ (29 - 1),
  };
  return rule;
};

export const encodeChallengeRawData = (
  dealers: string[],
  ebcs: string[],
  chainIds: number[],
  ebc: string,
  rule: RuleStruct,
): string => {
  return utils.defaultAbiCoder.encode(
    [
      'address[]',
      'address[]',
      'uint64[]',
      'address',
      'uint64',
      'uint64',
      'uint8',
      'uint8',
      'uint',
      'uint',
      'uint128',
      'uint128',
      'uint128',
      'uint128',
      'uint128',
      'uint128',
      'uint32',
      'uint32',
      'uint32',
      'uint32',
      'uint32',
      'uint32',
    ],
    [
      dealers,
      ebcs,
      chainIds,
      ebc,
      rule.chainId0,
      rule.chainId1,
      rule.status0,
      rule.status1,
      rule.token0,
      rule.token1,
      rule.minPrice0,
      rule.minPrice1,
      rule.maxPrice0,
      rule.maxPrice1,
      rule.withholdingFee0,
      rule.withholdingFee1,
      rule.tradingFee0,
      rule.tradingFee1,
      rule.responseTime0,
      rule.responseTime1,
      rule.compensationRatio0,
      rule.compensationRatio1,
    ],
  );
};

export const encodeRuleStruct = (rule: RuleStruct): string => {
  return keccak256(
    utils.defaultAbiCoder.encode(
      [
        'uint64',
        'uint64',
        'uint8',
        'uint8',
        'uint',
        'uint',
        'uint128',
        'uint128',
        'uint128',
        'uint128',
        'uint128',
        'uint128',
        'uint32',
        'uint32',
        'uint32',
        'uint32',
        'uint32',
        'uint32',
      ],
      [
        rule.chainId0,
        rule.chainId1,
        rule.status0,
        rule.status1,
        rule.token0,
        rule.token1,
        rule.minPrice0,
        rule.minPrice1,
        rule.maxPrice0,
        rule.maxPrice1,
        rule.withholdingFee0,
        rule.withholdingFee1,
        rule.tradingFee0,
        rule.tradingFee1,
        rule.responseTime0,
        rule.responseTime1,
        rule.compensationRatio0,
        rule.compensationRatio1,
      ],
    ),
  );
};

export function calculateRuleKey(rule: BigNumberish[]) {
  return utils.keccak256(
    utils.solidityPack(
      ['uint256', 'uint256', 'uint256', 'uint256'],
      rule.slice(0, 2).concat(rule.slice(4, 6)),
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

    const decodes = utils.defaultAbiCoder.decode(
      [
        'uint64',
        'address',
        `tuple(${ruleTypes.join(',')})[]`,
        'tuple(bytes32,uint32)',
        'uint64[]',
        'uint[]',
      ],
      utils.hexDataSlice(transaction.data, 4),
    );

    for (const _rule of decodes[2]) {
      const k = calculateRuleKey(_rule);
      const index = rules.findIndex((r) => calculateRuleKey(r) == k);

      if (index === -1) rules.push(_rule);
      else rules[index] = _rule;
    }
  }

  return rules;
}

export async function calculateRulesTree(rules: BigNumberish[][]) {
  const trie = new BaseTrie();
  for (const rule of rules) {
    const key = calculateRuleKey(rule);
    const value = utils.RLP.encode(
      rule.map((r) => utils.stripZeros(BigNumber.from(r).toHexString())),
    );

    await trie.put(hexToBuffer(key), hexToBuffer(value));
    const Trieproof = BaseTrie;
    const proof = await Trieproof.createProof(trie, hexToBuffer(key));
    await Trieproof.verifyProof(trie.root, hexToBuffer(key), proof);
  }

  return trie;
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
