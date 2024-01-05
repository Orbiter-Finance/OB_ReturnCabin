import { BigNumber, constants } from 'ethers';
import { BridgeLib } from '../typechain-types/contracts/ORManager';
import { chainIdsMockMainnetToken, chainIdsMock } from '../test/lib/mockData';

export const chainIdList = [
  1, // mainnet
  10, // Optimism
  42161, //Arbitrum one
  324, // zkSync-Era
];

export const deploymentChainInfoArray: BridgeLib.ChainInfoStruct[] = [
  {
    id: BigNumber.from(1),
    batchLimit: BigNumber.from(100),
    minVerifyChallengeSourceTxSecond: BigNumber.from(129600), //1.5 Days
    maxVerifyChallengeSourceTxSecond: BigNumber.from(259200), //3 Days
    minVerifyChallengeDestTxSecond: BigNumber.from(259200), //3 Days
    maxVerifyChallengeDestTxSecond: BigNumber.from(388800), // 4.5 Days
    nativeToken: constants.AddressZero,
    spvs: [],
  },
  {
    id: BigNumber.from(10),
    batchLimit: BigNumber.from(100),
    minVerifyChallengeSourceTxSecond: BigNumber.from(129600), //1.5 Days
    maxVerifyChallengeSourceTxSecond: BigNumber.from(259200), //3 Days
    minVerifyChallengeDestTxSecond: BigNumber.from(259200), //3 Days
    maxVerifyChallengeDestTxSecond: BigNumber.from(388800), // 4.5 Days
    nativeToken: constants.AddressZero,
    spvs: [],
  },
  {
    id: BigNumber.from(42161),
    batchLimit: BigNumber.from(100),
    minVerifyChallengeSourceTxSecond: BigNumber.from(129600), //1.5 Days
    maxVerifyChallengeSourceTxSecond: BigNumber.from(259200), //3 Days
    minVerifyChallengeDestTxSecond: BigNumber.from(259200), //3 Days
    maxVerifyChallengeDestTxSecond: BigNumber.from(388800), // 4.5 Days
    nativeToken: constants.AddressZero,
    spvs: [],
  },
  {
    id: BigNumber.from(324),
    batchLimit: BigNumber.from(100),
    minVerifyChallengeSourceTxSecond: BigNumber.from(129600), //1.5 Days
    maxVerifyChallengeSourceTxSecond: BigNumber.from(259200), //3 Days
    minVerifyChallengeDestTxSecond: BigNumber.from(259200), //3 Days
    maxVerifyChallengeDestTxSecond: BigNumber.from(388800), // 4.5 Days
    nativeToken: constants.AddressZero,
    spvs: [],
  },
  {
    id: BigNumber.from(534352),
    batchLimit: BigNumber.from(100),
    minVerifyChallengeSourceTxSecond: BigNumber.from(129600), //1.5 Days
    maxVerifyChallengeSourceTxSecond: BigNumber.from(259200), //3 Days
    minVerifyChallengeDestTxSecond: BigNumber.from(259200), //3 Days
    maxVerifyChallengeDestTxSecond: BigNumber.from(388800), // 4.5 Days
    nativeToken: constants.AddressZero,
    spvs: [],
  },
];

export const tokenDefault: BridgeLib.TokenInfoStruct = {
  token: constants.AddressZero,
  mainnetToken: constants.AddressZero,
  decimals: 18,
};

export default {
  chains: [
    // Goerli
    {
      id: 5,
      batchLimit: 100, // TODO: mock
      minVerifyChallengeSourceTxSecond: 900, // TODO: mock
      maxVerifyChallengeSourceTxSecond: 1800, // TODO: mock
      minVerifyChallengeDestTxSecond: 1800, // TODO: mock
      maxVerifyChallengeDestTxSecond: 2700, // TODO: mock
      nativeToken: constants.AddressZero,
      spvs: [],

      tokens: [
        {
          token: constants.AddressZero,
          mainnetToken: constants.AddressZero,
          decimals: 18,
        },
      ],
    },

    // Arbitrum Goerli
    {
      id: 421613,
      batchLimit: 100, // TODO: mock
      minVerifyChallengeSourceTxSecond: 900, // TODO: mock
      maxVerifyChallengeSourceTxSecond: 1800, // TODO: mock
      minVerifyChallengeDestTxSecond: 1800, // TODO: mock
      maxVerifyChallengeDestTxSecond: 2700, // TODO: mock
      nativeToken: constants.AddressZero,
      spvs: [],

      tokens: [
        {
          token: constants.AddressZero,
          mainnetToken: constants.AddressZero,
          decimals: 18,
        },
      ],
    },

    // Optimism Goerli Testnet
    {
      id: 420,
      batchLimit: 100, // TODO: mock
      minVerifyChallengeSourceTxSecond: 900, // TODO: mock
      maxVerifyChallengeSourceTxSecond: 1800, // TODO: mock
      minVerifyChallengeDestTxSecond: 1800, // TODO: mock
      maxVerifyChallengeDestTxSecond: 2700, // TODO: mock
      nativeToken: constants.AddressZero,
      spvs: [],

      tokens: [
        {
          token: constants.AddressZero,
          mainnetToken: constants.AddressZero,
          decimals: 18,
        },
      ],
    },

    // zkSync Era Testnet
    {
      id: 280,
      batchLimit: 100, // TODO: mock
      minVerifyChallengeSourceTxSecond: 900, // TODO: mock
      maxVerifyChallengeSourceTxSecond: 1800, // TODO: mock
      minVerifyChallengeDestTxSecond: 1800, // TODO: mock
      maxVerifyChallengeDestTxSecond: 2700, // TODO: mock
      nativeToken: constants.AddressZero,
      spvs: [],

      tokens: [
        {
          token: constants.AddressZero,
          mainnetToken: constants.AddressZero,
          decimals: 18,
        },
      ],
    },

    // ethereum Sepolia Testnet
    {
      id: 11155111,
      batchLimit: 100, // TODO: mock
      minVerifyChallengeSourceTxSecond: 900, // TODO: mock
      maxVerifyChallengeSourceTxSecond: 1800, // TODO: mock
      minVerifyChallengeDestTxSecond: 1800, // TODO: mock
      maxVerifyChallengeDestTxSecond: 2700, // TODO: mock
      nativeToken: constants.AddressZero,
      spvs: [],

      tokens: [
        {
          token: constants.AddressZero,
          mainnetToken: constants.AddressZero,
          decimals: 18,
        },
      ],
    },
    // zk-sync Sepolia Testnet
    {
      id: 11155111,
      batchLimit: 300, // TODO: mock
      minVerifyChallengeSourceTxSecond: 900, // TODO: mock
      maxVerifyChallengeSourceTxSecond: 1800, // TODO: mock
      minVerifyChallengeDestTxSecond: 1800, // TODO: mock
      maxVerifyChallengeDestTxSecond: 2700, // TODO: mock
      nativeToken: constants.AddressZero,
      spvs: [],

      tokens: [
        {
          token: constants.AddressZero,
          mainnetToken: constants.AddressZero,
          decimals: 18,
        },
      ],
    },
  ],

  ebcs: [], // Run scripts/orManagerSetup.ts need to fill
  submitter: '', // Run scripts/orManagerSetup.ts need to fill
};
