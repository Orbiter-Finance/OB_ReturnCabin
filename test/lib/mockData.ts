import hre, { ethers } from 'hardhat';
import { BridgeLib } from '../../typechain-types/contracts/ORManager';
import { BigNumber, Bytes, constants } from 'ethers';
import lodash from 'lodash';

export const chainNames = {
  5: 'goerli',
  420: 'optimisim goerli',
  421613: 'arbitrum goerli',
  280: 'zk-sync Era Testnet',
};

// mark the chain id that if we don't want to test
export const chainIdsMock = [
  // 1,
  // 42161,
  // 10,
  // 324,
  5, // goerli
  420, // optimisim goerli testnet
  421613, // arbitrum goerli testnet
  // 280,    // zk-sync Era testnet
];

export const chainIdsMockMainnetToken = [
  // 1,
  // 42161,
  // 10,
  // 324,
  '0x0000000000000000000000000000000000000000', // goerli
  '0x0000000000000000000000000000000000000000', // optimisim goerli testnet
  '0x0000000000000000000000000000000000000000', // arbitrum goerli testnet
  // 280,    // zk-sync Era testnet
];

// struct SubmitInfo
export interface SubmitInfo {
  stratBlock: number;
  endBlock: number;
  profitRoot: string;
  stateTransTreeRoot: string;
}

export interface SMTLeaf {
  key: SMTKey;
  value: SMTValue;
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

// export interface SMTProof {
//   proofs: string[][];
//   siblings: string[];
//   smtLeaves: SMTLeaf[];
// }

/************************ Mock Data ***************************/

export const dealersMock = async () => {
  const signers = await ethers.getSigners();
  return signers.slice(0, 2).map((signer) => signer.address);
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

export const ebcMock = '0x9E6D2B0b3AdB391AB62146c1B14a94e8D840Ff82';

export const stateTransTreeRootMock = ethers.utils.keccak256(
  ethers.utils.toUtf8Bytes('stateTransTreeRoot'),
);

export const SubmitInfoMock = async (): Promise<SubmitInfo> => {
  const submitInfo: SubmitInfo = {
    stratBlock: 0,
    endBlock: 2,
    profitRoot: profitRootMock,
    stateTransTreeRoot: stateTransTreeRootMock,
  };
  return submitInfo;
};

export const proofsMock: string[][] = [
  [ethers.utils.keccak256(ethers.utils.toUtf8Bytes('proofs'))],
];

export const mockKey: SMTKey = {
  chainId: BigNumber.from(5),
  token: '0xa3a8a6b323e3d38f5284db9337e7c6d74af3366a',
  user: '0x15962f38e6998875F9F75acDF8c6Ddc743F11041',
};

export const mockValue: SMTValue = {
  token: '0xa3a8a6b323e3d38f5284db9337e7c6d74af3366a',
  chainId: BigNumber.from(5),
  amount: BigNumber.from(200),
  debt: BigNumber.from(0),
};

export const smtLeavesMock: SMTLeaf = {
  key: {
    chainId: mockKey.chainId,
    token: mockKey.token,
    user: mockKey.user,
  },
  value: {
    token: mockValue.token,
    chainId: mockValue.chainId,
    amount: mockValue.amount,
    debt: mockValue.debt,
  },
};

export const profitRootMock =
  '0xae517a5d3749f085aad5db3021f96a33fb1d15794d1b8586c19b4cb9e167d33e';

export const bitmapMock: string[] = [
  '0x000000000000000000000000000000000000000000000000000000000000000a',
];

export const mergeValueMock: MergeValue[] = [
  {
    mergeType: 1,
    mergeValue: {
      value1: 252,
      value2:
        '0x32b10436b3679210be2e0a4d7334b16dc58e9a2505e5ad698ddab7bfbebfee70' as unknown as Bytes,
      value3:
        '0xaef908a902e98808f76e42b87aec4c4910a39aa9edd656553e7c028ac91e67f0' as unknown as Bytes,
    },
  },
  {
    mergeType: 1,
    mergeValue: {
      value1: 254,
      value2:
        '0x70816add9a4e5c06656e76cc3bf11ee3c5bb0e463b422d6902ae4c4463a50fd9' as unknown as Bytes,
      value3:
        '0x0bb3696cdbd7208860e9d53efd6c0f72a10597148be66b509d7659ff07f06cb8' as unknown as Bytes,
    },
  },
];

// export const mockKey: SMTKey = {
//   chainId: BigNumber.from(100),
//   token: '0x0000000000000000000000000000000000000021',
//   user: '0x0000000000000000000000000000000000000022',
// };

// export const mockValue: SMTValue = {
//   token: '0x0000000000000000000000000000000000000021',
//   chainId: BigNumber.from(100),
//   amount: BigNumber.from(100),
//   debt: BigNumber.from(80),
// };

// export const profitRootMock =
//   '0x7079a474f9bec927bf070f5e1b9b21da95facd7bdbd43d52c2505b26473b5de3';

// export const bitmapMock: string[] = [
//   '0x0000000000000000000000000000000000000000000000000000000000000007',
// ];

// export const mergeValueMock: MergeValue[] = [
//   {
//     mergeType: 1,
//     mergeValue: {
//       value1: 253,
//       value2:
//         '0xa4366628111703a3b0bb5cec1fceab50f570e0dd51d56dd6eb7a2a54bab3849b' as unknown as Bytes,
//       value3:
//         '0x1fd30ea2d276c20bec69f8ea60934f416cf0fed1dd41d1bf14bce37dbea5ab60' as unknown as Bytes,
//     },
//   },
//   {
//     mergeType: 1,
//     mergeValue: {
//       value1: 254,
//       value2:
//         '0x2a05c298a79e5e065d6ed28d4e3740bbd6ecee14cd6321be5d5039ed2db785ba' as unknown as Bytes,
//       value3:
//         '0xda95503be5e50362f74ec227db12634ff5ddb055409910557ec6d12735b410b4' as unknown as Bytes,
//     },
//   },
//   {
//     mergeType: 1,
//     mergeValue: {
//       value1: 255,
//       value2:
//         '0x086f5ccd56d9fe6db616a7420c05d3192c2374f6d0405f6d463464a6aca7952f' as unknown as Bytes,
//       value3:
//         '0x6436bc10c965a82e3ced8b386e05b84c8a3d7193701a4019a46237abd5d31afa' as unknown as Bytes,
//     },
//   },
// ];

/************************ Mock Data ************************** */

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
};

export function initTestToken() {
  const usdtTokens = new Set<string>();
  const usdcTokens = new Set<string>();
  const daiTokens = new Set<string>();
  const mainnetTokens = new Set<string>();
  const arbitrumTokens = new Set<string>();
  const optimismTokens = new Set<string>();
  const eraTokens = new Set<string>();

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

  testToken = {
    USDT_TOKEN: Array.from(usdtTokens),
    UDSC_TOKEN: Array.from(usdcTokens),
    DAI_TOKEN: Array.from(daiTokens),
    MAINNET_TOKEN: Array.from(new Set([...mainnetTokens])),
    ARBITRUM_TOKEN: Array.from(new Set([...arbitrumTokens])),
    OPTIMISM_TOKEN: Array.from(new Set([...optimismTokens])),
    ERA_TOKRN: [],
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
    case 5: {
      return L2token;
    }
    default:
      return constants.AddressZero;
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
    .add(BigNumber.from('70000' + paddingString));
  let chain1MinPrice = BigNumber.from(5)
    .pow(parseInt(Math.random() * 6 + ''))
    .add(BigNumber.from('50000' + paddingString));
  let chain1MaxPrice = BigNumber.from(5)
    .pow(parseInt(Math.random() * 9 + ''))
    .add(BigNumber.from('80000' + paddingString));
  const chain0withholdingFee = BigNumber.from(560000).add(
    BigNumber.from('10000' + paddingString),
  );
  const chain1withholdingFee = BigNumber.from(780000).add(
    BigNumber.from('10000' + paddingString),
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

export async function mineXMinutes(minutes: number) {
  const seconds = minutes * 60;
  const currentTime = await getCurrentTime();
  await ethers.provider.send('evm_increaseTime', [currentTime]);
  await ethers.provider.send('evm_mine', [currentTime + seconds]);
  console.log(
    `mine ${minutes} minutes, current time: ${await getCurrentTime()}`,
  );
}
