import hre, { ethers } from 'hardhat';
import { BridgeLib } from '../../typechain-types/contracts/ORManager';
import { BigNumber, Bytes, Wallet, constants, utils } from 'ethers';
import lodash from 'lodash';
import axios from 'axios';
import fs from 'fs';

export const chainNames = {
  5: 'goerli',
  420: 'optimisim goerli',
  421613: 'arbitrum goerli',
  280: 'zk-sync Era Testnet',
  534351: 'Scroll Sepolia',
};

/**
 * mark the netkwork ID if you don't want to test it
 * @param none
 * @return none
 */
export const chainIdsMock = [
  // 1,
  // 42161,
  // 10,
  // 324,
  5, // goerli
  420, // optimisim goerli testnet
  421613, // arbitrum goerli testnet
  280, // zk-sync Era testnet
  534351, // Scroll Sepolia Testnet
];

export const chainIdsMockMainnetToken = [
  // 1,
  // 42161,
  // 10,
  // 324,
  '0x0000000000000000000000000000000000000000', // 5        //goerli
  '0x0000000000000000000000000000000000000000', // 420      //optimisim goerli testnet
  '0x0000000000000000000000000000000000000000', // 421613  //arbitrum goerli testnet
  '0x0000000000000000000000000000000000000000', // 280,    // zk-sync Era testnet
  '0x0000000000000000000000000000000000000000', // 534351, // Scroll Sepolia Testnet
];

// struct SubmitInfo
export interface SubmitInfo {
  stratBlock: number;
  endBlock: number;
  profitRoot: string;
  stateTransTreeRoot: string;
}

export interface SMTLeaf {
  chainId: BigNumber;
  token: string;
  user: string;
  amount: BigNumber;
  debt: BigNumber;
}

interface SMTKey {
  chainId: BigNumber;
  token: string;
  user: string;
}

interface SMTValue {
  token: string;
  chainId: BigNumber;
  amount: BigNumber;
  debt: BigNumber;
}

interface MergeValueSingle {
  value1: number;
  value2: Bytes;
  value3: Bytes;
}

export interface MergeValue {
  mergeType: number;
  mergeValue: MergeValueSingle;
}

export interface withdrawVerification {
  smtLeaf: SMTLeaf[];
  siblings: MergeValue[][];
  startIndex: BigNumber[];
  firstZeroBits: Bytes[];
  bitmaps: Bytes[];
  // withdrawAmount: BigNumber[];
  root: string[];
}

/************************ Mock Data ***************************/

export const dealersMock = async () => {
  const dealers = new Array(99)
    .fill(undefined)
    .map(() => Wallet.createRandom().address);
  return dealers;
};

export const submitterMock = async () => {
  const signers = await ethers.getSigners();
  return signers[0].address;
};

export const dealersSignersMock = async () => {
  const signers = await ethers.getSigners();
  return signers.slice(0, 2);
};

export const spvMock = async () => {
  const signers = await ethers.getSigners();
  return signers.slice(5, 7).map((signer) => signer.address);
};

export const stateTransTreeRootMock = ethers.utils.keccak256(
  ethers.utils.toUtf8Bytes('stateTransTreeRoot'),
);

export const SubmitInfoMock = async (): Promise<SubmitInfo> => {
  const submitInfo: SubmitInfo = {
    stratBlock: 0,
    endBlock: 2,
    profitRoot: ethers.utils.keccak256(ethers.utils.toUtf8Bytes('profitRoot')),
    stateTransTreeRoot: stateTransTreeRootMock,
  };
  return submitInfo;
};

export const proofsMock: string[][] = [
  [ethers.utils.keccak256(ethers.utils.toUtf8Bytes('proofs'))],
];

export const mockKey: SMTKey = {
  chainId: BigNumber.from(5),
  token: '0xa0321efeb50c46c17a7d72a52024eea7221b215a',
  user: '0x15962f38e6998875F9F75acDF8c6Ddc743F11041',
};

export const mockValue: SMTValue = {
  token: '0xa0321efeb50c46c17a7d72a52024eea7221b215a',
  chainId: BigNumber.from(5),
  amount: BigNumber.from(200),
  debt: BigNumber.from(0),
};

export const submitter2Mock = '0xD6Cec62CE67E09b240B84A3FB53cC1EbA05795d6';

export const defaultChainInfoArray: BridgeLib.ChainInfoStruct[] =
  chainIdsMock.map((chainId) => {
    return {
      id: BigNumber.from(chainId),
      batchLimit: BigNumber.from(1000),
      minVerifyChallengeSourceTxSecond: BigNumber.from(100),
      maxVerifyChallengeSourceTxSecond: BigNumber.from(200),
      minVerifyChallengeDestTxSecond: BigNumber.from(100),
      maxVerifyChallengeDestTxSecond: BigNumber.from(200),
      nativeToken: BigNumber.from(
        chainIdsMockMainnetToken[chainIdsMock.indexOf(chainId)],
      ),
      spvs: [constants.AddressZero],
    };
  });

export function getRandomPadding() {
  return Math.floor(Math.random() * 500) + 1;
}

export let testToken = {
  USDT_TOKEN: [] as string[],
  UDSC_TOKEN: [] as string[],
  DAI_TOKEN: [] as string[],
  MAINNET_TOKEN: [] as string[],
  ARBITRUM_TOKEN: [] as string[],
  OPTIMISM_TOKEN: [] as string[],
  ERA_TOKRN: [] as string[],
  SCROLL_TOKEN: [] as string[],
};

export function initTestToken() {
  const usdtTokens = new Set<string>();
  const usdcTokens = new Set<string>();
  const daiTokens = new Set<string>();
  const mainnetTokens = new Set<string>();
  const arbitrumTokens = new Set<string>();
  const optimismTokens = new Set<string>();
  const eraTokens = new Set<string>();
  const scrollTokens = new Set<string>();

  if (process.env['MAINNET_NATIVE_TOKEN'] != undefined) {
    process.env['MAINNET_NATIVE_TOKEN'].split(',').forEach((token) => {
      mainnetTokens.add(token);
    });
  }

  if (process.env['ARBITRUM_NATIVE_TOKEN'] != undefined) {
    process.env['ARBITRUM_NATIVE_TOKEN'].split(',').forEach((token) => {
      arbitrumTokens.add(token);
    });
  }

  if (process.env['OPTIMISM_NATIVE_TOKEN'] != undefined) {
    process.env['OPTIMISM_NATIVE_TOKEN'].split(',').forEach((token) => {
      optimismTokens.add(token);
    });
  }

  if (process.env['ERA_NATIVE_TOKEN'] != undefined) {
    process.env['ERA_NATIVE_TOKEN'].split(',').forEach((token) => {
      eraTokens.add(token);
    });
  }

  if (process.env['SCROLL_NATIVE_TOKEN'] != undefined) {
    process.env['SCROLL_NATIVE_TOKEN'].split(',').forEach((token) => {
      scrollTokens.add(token);
    });
  }

  if (process.env['MAINNET_TEST_USDT'] != undefined) {
    process.env['MAINNET_TEST_USDT'].split(',').forEach((token) => {
      usdtTokens.add(token);
    });
    process.env['MAINNET_TEST_USDT'].split(',').forEach((token) => {
      mainnetTokens.add(token);
    });
  }
  if (process.env['ARBITRUM_TEST_USDT'] != undefined) {
    process.env['ARBITRUM_TEST_USDT'].split(',').forEach((token) => {
      usdtTokens.add(token);
    });
    process.env['ARBITRUM_TEST_USDT'].split(',').forEach((token) => {
      arbitrumTokens.add(token);
    });
  }
  if (process.env['OPTIMISM_TEST_USDT'] != undefined) {
    process.env['OPTIMISM_TEST_USDT'].split(',').forEach((token) => {
      usdtTokens.add(token);
    });
    process.env['OPTIMISM_TEST_USDT'].split(',').forEach((token) => {
      optimismTokens.add(token);
    });
  }

  if (process.env['ERA_TEST_USDT'] != undefined) {
    process.env['ERA_TEST_USDT'].split(',').forEach((token) => {
      usdtTokens.add(token);
    });
    process.env['ERA_TEST_USDT'].split(',').forEach((token) => {
      eraTokens.add(token);
    });
  }

  if (process.env['SCROLL_TEST_USDT'] != undefined) {
    process.env['SCROLL_TEST_USDT'].split(',').forEach((token) => {
      usdtTokens.add(token);
    });
    process.env['SCROLL_TEST_USDT'].split(',').forEach((token) => {
      scrollTokens.add(token);
    });
  }

  if (process.env['MAINNET_TEST_USDC'] != undefined) {
    process.env['MAINNET_TEST_USDC'].split(',').forEach((token) => {
      usdcTokens.add(token);
    });
    process.env['MAINNET_TEST_USDC'].split(',').forEach((token) => {
      mainnetTokens.add(token);
    });
  }
  if (process.env['ARBITRUM_TEST_USDC'] != undefined) {
    process.env['ARBITRUM_TEST_USDC'].split(',').forEach((token) => {
      usdcTokens.add(token);
    });
    process.env['ARBITRUM_TEST_USDC'].split(',').forEach((token) => {
      arbitrumTokens.add(token);
    });
  }
  if (process.env['OPTIMISM_TEST_USDC'] != undefined) {
    process.env['OPTIMISM_TEST_USDC'].split(',').forEach((token) => {
      usdcTokens.add(token);
    });
    process.env['OPTIMISM_TEST_USDC'].split(',').forEach((token) => {
      optimismTokens.add(token);
    });
  }

  if (process.env['ERA_TEST_USDC'] != undefined) {
    process.env['ERA_TEST_USDC'].split(',').forEach((token) => {
      usdcTokens.add(token);
    });
    process.env['ERA_TEST_USDC'].split(',').forEach((token) => {
      eraTokens.add(token);
    });
  }

  if (process.env['SCROLL_TEST_USDC'] != undefined) {
    process.env['SCROLL_TEST_USDC'].split(',').forEach((token) => {
      usdcTokens.add(token);
    });
    process.env['SCROLL_TEST_USDC'].split(',').forEach((token) => {
      scrollTokens.add(token);
    });
  }

  if (process.env['MAINNET_TEST_DAI'] != undefined) {
    process.env['MAINNET_TEST_DAI'].split(',').forEach((token) => {
      daiTokens.add(token);
    });
    process.env['MAINNET_TEST_DAI'].split(',').forEach((token) => {
      mainnetTokens.add(token);
    });
  }

  if (process.env['ARBITRUM_TEST_DAI'] != undefined) {
    process.env['ARBITRUM_TEST_DAI'].split(',').forEach((token) => {
      daiTokens.add(token);
    });
    process.env['ARBITRUM_TEST_DAI'].split(',').forEach((token) => {
      arbitrumTokens.add(token);
    });
  }

  if (process.env['OPTIMISM_TEST_DAI'] != undefined) {
    process.env['OPTIMISM_TEST_DAI'].split(',').forEach((token) => {
      daiTokens.add(token);
    });
    process.env['OPTIMISM_TEST_DAI'].split(',').forEach((token) => {
      optimismTokens.add(token);
    });
  }

  if (process.env['ERA_TEST_DAI'] != undefined) {
    process.env['ERA_TEST_DAI'].split(',').forEach((token) => {
      daiTokens.add(token);
    });
    process.env['ERA_TEST_DAI'].split(',').forEach((token) => {
      eraTokens.add(token);
    });
  }
  if (process.env['SCROLL_TEST_DAI'] != undefined) {
    process.env['SCROLL_TEST_DAI'].split(',').forEach((token) => {
      daiTokens.add(token);
    });
    process.env['SCROLL_TEST_DAI'].split(',').forEach((token) => {
      scrollTokens.add(token);
    });
  }

  testToken = {
    USDT_TOKEN: Array.from(usdtTokens),
    UDSC_TOKEN: Array.from(usdcTokens),
    DAI_TOKEN: Array.from(daiTokens),
    MAINNET_TOKEN: Array.from(new Set([...mainnetTokens])),
    ARBITRUM_TOKEN: Array.from(new Set([...arbitrumTokens])),
    OPTIMISM_TOKEN: Array.from(new Set([...optimismTokens])),
    ERA_TOKRN: Array.from(new Set([...eraTokens])),
    SCROLL_TOKEN: Array.from(new Set([...scrollTokens])),
  };

  // console.log(testToken);
}

export function calculateMainnetToken(
  chainId: number,
  L2token: string,
): string {
  switch (chainId) {
    case 421613: {
      if (testToken.ARBITRUM_TOKEN.indexOf(L2token) != -1) {
        return testToken.MAINNET_TOKEN[
          testToken.ARBITRUM_TOKEN.indexOf(L2token)
        ];
      }
    }
    case 420: {
      if (testToken.OPTIMISM_TOKEN.indexOf(L2token) != -1) {
        return testToken.MAINNET_TOKEN[
          testToken.OPTIMISM_TOKEN.indexOf(L2token)
        ];
      }
    }
    case 280: {
      if (testToken.ERA_TOKRN.indexOf(L2token) != -1) {
        return testToken.MAINNET_TOKEN[testToken.ERA_TOKRN.indexOf(L2token)];
      }
    }
    case 5: {
      return L2token;
    }
    case 534351: {
      if (testToken.SCROLL_TOKEN.indexOf(L2token) != -1) {
        return testToken.MAINNET_TOKEN[testToken.SCROLL_TOKEN.indexOf(L2token)];
      }
    }
    default:
      return '0xA00000000000000000000000000000000000000B';
  }
}

export function chainIDgetTokenSequence(chainId: number, idx: number) {
  switch (chainId) {
    case 5: {
      if (idx < testToken.MAINNET_TOKEN.length) {
        return testToken.MAINNET_TOKEN[idx];
      } else {
        return ethers.constants.AddressZero;
      }
    }
    case 421613: {
      if (idx < testToken.ARBITRUM_TOKEN.length) {
        return testToken.ARBITRUM_TOKEN[idx];
      } else {
        return ethers.constants.AddressZero;
      }
    }
    case 420: {
      if (idx < testToken.OPTIMISM_TOKEN.length) {
        return testToken.OPTIMISM_TOKEN[idx];
      } else {
        return ethers.constants.AddressZero;
      }
    }
    case 280: {
      if (idx < testToken.ERA_TOKRN.length) {
        return testToken.ERA_TOKRN[idx];
      } else {
        return ethers.constants.AddressZero;
      }
    }
    case 534351: {
      if (idx < testToken.SCROLL_TOKEN.length) {
        return testToken.SCROLL_TOKEN[idx];
      } else {
        return ethers.constants.AddressZero;
      }
    }
    default:
      return ethers.constants.AddressZero;
  }
}

export function chainIDgetToken(
  chainId: number,
  isNative: boolean,
  type?: string,
) {
  let mainnetToken = ethers.constants.AddressZero;
  let arbitrumToken = ethers.constants.AddressZero;
  let optimismToken = ethers.constants.AddressZero;
  let eraToken = ethers.constants.AddressZero;
  let scrollToken = ethers.constants.AddressZero;
  if (!isNative) {
    mainnetToken =
      testToken.MAINNET_TOKEN.length > 0
        ? lodash.sample(testToken.MAINNET_TOKEN.slice(1))!
        : ethers.Wallet.createRandom().address;
    arbitrumToken =
      testToken.ARBITRUM_TOKEN.length > 0
        ? lodash.sample(testToken.ARBITRUM_TOKEN.slice(1))!
        : ethers.Wallet.createRandom().address;
    optimismToken =
      testToken.OPTIMISM_TOKEN.length > 0
        ? lodash.sample(testToken.OPTIMISM_TOKEN.slice(1))!
        : ethers.Wallet.createRandom().address;
    eraToken =
      testToken.ERA_TOKRN.length > 0
        ? lodash.sample(testToken.ERA_TOKRN.slice(1))!
        : ethers.Wallet.createRandom().address;
    scrollToken =
      testToken.SCROLL_TOKEN.length > 0
        ? lodash.sample(testToken.SCROLL_TOKEN.slice(1))!
        : ethers.Wallet.createRandom().address;
  }

  switch (chainId) {
    case 1:
      return mainnetToken;
    case 42161:
      return arbitrumToken;
    case 10:
      return optimismToken;
    case 5: {
      if (type == 'USDT') {
        const goerliUSDT =
          process.env['MAINNET_TEST_USDT'] != undefined
            ? process.env['MAINNET_TEST_USDT']
            : ethers.constants.AddressZero;
        return goerliUSDT;
      } else if (type == 'USDC') {
        const goerliUSDC =
          process.env['MAINNET_TEST_USDC'] != undefined
            ? process.env['MAINNET_TEST_USDC']
            : ethers.constants.AddressZero;
        return goerliUSDC;
      } else if (type == 'DAI') {
        const goerliDAI =
          process.env['MAINNET_TEST_DAI'] != undefined
            ? process.env['MAINNET_TEST_DAI']
            : ethers.constants.AddressZero;
        return goerliDAI;
      } else {
        return mainnetToken;
      }
    }
    case 420: {
      if (type == 'USDT') {
        const optimismUSDT =
          process.env['OPTIMISM_TEST_USDT'] != undefined
            ? process.env['OPTIMISM_TEST_USDT']
            : ethers.constants.AddressZero;
        return optimismUSDT;
      } else if (type == 'USDC') {
        const optimismUSDC =
          process.env['OPTIMISM_TEST_USDC'] != undefined
            ? process.env['OPTIMISM_TEST_USDC']
            : ethers.constants.AddressZero;
        return optimismUSDC;
      } else if (type == 'DAI') {
        const optimismDAI =
          process.env['OPTIMISM_TEST_DAI'] != undefined
            ? process.env['OPTIMISM_TEST_DAI']
            : ethers.constants.AddressZero;
        return optimismDAI;
      } else {
        return optimismToken;
      }
    }
    case 421613: {
      if (type == 'USDT') {
        const arbitrumUSDT =
          process.env['ARBITRUM_TEST_USDT'] != undefined
            ? process.env['ARBITRUM_TEST_USDT']
            : ethers.constants.AddressZero;
        return arbitrumUSDT;
      } else if (type == 'USDC') {
        const arbitrumUSDC =
          process.env['ARBITRUM_TEST_USDC'] != undefined
            ? process.env['ARBITRUM_TEST_USDC']
            : ethers.constants.AddressZero;
        return arbitrumUSDC;
      } else if (type == 'DAI') {
        const arbitrumDAI =
          process.env['ARBITRUM_TEST_DAI'] != undefined
            ? process.env['ARBITRUM_TEST_DAI']
            : ethers.constants.AddressZero;
        return arbitrumDAI;
      } else {
        return arbitrumToken;
      }
    }
    case 534351: {
      if (type == 'USDT') {
        const scrollUSDT =
          process.env['ARBITRUM_TEST_USDT'] != undefined
            ? process.env['ARBITRUM_TEST_USDT']
            : ethers.constants.AddressZero;
        return scrollUSDT;
      } else if (type == 'USDC') {
        const scrollUSDC =
          process.env['ARBITRUM_TEST_USDC'] != undefined
            ? process.env['ARBITRUM_TEST_USDC']
            : ethers.constants.AddressZero;
        return scrollUSDC;
      } else if (type == 'DAI') {
        const scrollDAI =
          process.env['ARBITRUM_TEST_DAI'] != undefined
            ? process.env['ARBITRUM_TEST_DAI']
            : ethers.constants.AddressZero;
        return scrollDAI;
      } else {
        return scrollToken;
      }
    }
    case 280:
      return eraToken;
    default:
      return ethers.Wallet.createRandom().address;
  }
}

function checkTokensChainInfo(token: string): string {
  // check if token in testToken.USDT_TOKEN
  if (testToken.USDT_TOKEN.includes(token)) {
    return 'USDT';
  } else if (testToken.UDSC_TOKEN.includes(token)) {
    return 'USDC';
  } else if (testToken.DAI_TOKEN.includes(token)) {
    return 'DAI';
  } else {
    return 'UNKNOWN';
  }
}

export function getRulesSetting(getNative: boolean) {
  let chain0Id: keyof typeof chainNames = 0 as keyof typeof chainNames;
  let chain1Id: keyof typeof chainNames = 0 as keyof typeof chainNames;
  let chain0token: string;
  let chain1token: string;
  chain0Id = lodash.sample(chainIdsMock)! as keyof typeof chainNames;
  chain1Id = lodash.sample(
    chainIdsMock.filter((id) => id !== chain0Id),
  )! as keyof typeof chainNames;

  if (chain0Id > chain1Id) {
    [chain0Id, chain1Id] = [chain1Id, chain0Id];
  }

  chain0token = chainIDgetToken(chain0Id, getNative);
  chain1token = chainIDgetToken(
    chain1Id,
    getNative,
    checkTokensChainInfo(chain0token),
  );

  let randomStatus1 = Math.floor(Math.random() * 2);
  let randomStatus2 = Math.floor(Math.random() * 2);
  let paddingString = '0';
  if (checkTokensChainInfo(chain0token) != 'DAI') {
    paddingString = '0000000000';
  }
  let chain0MinPrice = BigNumber.from(5)
    .pow(parseInt(Math.random() * 6 + ''))
    .add(BigNumber.from('50000' + paddingString));
  let chain0MaxPrice = BigNumber.from(5)
    .pow(parseInt(Math.random() * 9 + ''))
    .add(BigNumber.from('70000000' + paddingString));
  let chain1MinPrice = BigNumber.from(5)
    .pow(parseInt(Math.random() * 6 + ''))
    .add(BigNumber.from('50000' + paddingString));
  let chain1MaxPrice = BigNumber.from(5)
    .pow(parseInt(Math.random() * 9 + ''))
    .add(BigNumber.from('80000000' + paddingString));
  const chain0withholdingFee = BigNumber.from(56 * 100000).add(
    BigNumber.from('100000' + paddingString),
  );
  const chain1withholdingFee = BigNumber.from(78 * 100000).add(
    BigNumber.from('100000' + paddingString),
  );

  if (chain0MinPrice > chain0MaxPrice) {
    [chain0MinPrice, chain0MaxPrice] = [chain0MaxPrice, chain0MinPrice];
  }
  if (chain1MinPrice > chain1MaxPrice) {
    [chain1MinPrice, chain1MaxPrice] = [chain1MaxPrice, chain1MinPrice];
  }

  randomStatus1 = 1;
  randomStatus2 = 1;

  return {
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
  };
}

export async function verifyContract(address: string, args: any[]) {
  if ((await ethers.provider.getNetwork()).chainId != 31337) {
    try {
      return await hre.run('verify:verify', {
        address: address,
        constructorArguments: args,
      });
    } catch (e) {
      console.log(address, args, e);
    }
  }
}

export async function printCurrentTime() {
  const currentTime = await getCurrentTime();
  console.log('Current timestamp:', currentTime);
}

export async function getCurrentTime() {
  const block = await ethers.provider.getBlock('latest');
  return block.timestamp;
}

export async function mineXTimes(time: number, useSecond = false) {
  const seconds = useSecond ? time : time * 60;
  const currentTime = await getCurrentTime();
  await ethers.provider.send('evm_increaseTime', [currentTime]);
  await ethers.provider.send('evm_mine', [currentTime + seconds]);
  // console.log(
  //   `mine ${minutes} minutes, current time: ${await getCurrentTime()}`,
  // );
}

export function callDataCost(data: string): number {
  return ethers.utils
    .arrayify(data)
    .map((x) => (x === 0 ? 4 : 16))
    .reduce((sum, x) => sum + x);
}

export function bytesToNumber(bytes: Bytes): number {
  const hexString = utils.hexlify(bytes);
  return parseInt(hexString.slice(2), 16);
}

export async function submitter_getProfitProof(
  tokens: [number, string][],
  user: string,
): Promise<SMTLeaf> {
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  console.log(`RPC get userAddress: ${user}, tokenAddress: ${tokens}...wait`);
  const url = process.env['SUBMITTER_RPC']!;
  const data = {
    jsonrpc: '2.0',
    method: 'submitter_getProfitProof',
    params: {
      user: user,
      tokens: tokens,
    },
    id: 1,
  };

  const response = await axios.post(url, data, {
    headers: { 'Content-Type': 'application/json' },
    validateStatus: () => true,
  });

  fs.writeFileSync(
    'test/RPC_DATA/response.json',
    JSON.stringify(response.data),
  );
  return response.data.result;
}
