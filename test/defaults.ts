import { BigNumber, constants, ethers } from 'ethers';
import { BridgeLib } from '../typechain-types/contracts/ORManager';

export const defaultChainInfo: BridgeLib.ChainInfoStruct = {
  id: 5,
  batchLimit: BigNumber.from(1000),
  minVerifyChallengeSourceTxSecond: BigNumber.from(100),
  maxVerifyChallengeSourceTxSecond: BigNumber.from(200),
  minVerifyChallengeDestTxSecond: BigNumber.from(100),
  maxVerifyChallengeDestTxSecond: BigNumber.from(200),
  spvs: [constants.AddressZero],
};

export const defaultChainTokens: {
  [key: number]: BridgeLib.TokenInfoStruct[];
} = {
  5: [
    {
      token: constants.Two,
      decimals: 18,
      mainnetToken: constants.AddressZero,
    },
  ],
};

export const defaultsEbcs: string[] = new Array(10)
  .fill(undefined)
  .map(() => ethers.Wallet.createRandom().address);
