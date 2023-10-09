import { constants } from 'ethers';

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
  ],

  ebcs: [], // Run scripts/orManagerSetup.ts need to fill
  submitter: '', // Run scripts/orManagerSetup.ts need to fill
};
