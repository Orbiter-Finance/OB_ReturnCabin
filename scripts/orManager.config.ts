import { constants } from 'ethers';

export default {
  chains: [
    // Mainnet
    {
      id: 1,
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

    // Arbitrum One
    {
      id: 42161,
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

    // Optimism
    {
      id: 10,
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

    // zkSync Era
    {
      id: 324,
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

    // Scroll
    {
      id: 534352,
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
  ],

  ebcs: [], // Run scripts/orManagerSetup.ts need to fill
  submitter: '', // Run scripts/orManagerSetup.ts need to fill
};
