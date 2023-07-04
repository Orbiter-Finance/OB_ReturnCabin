import { BigNumber, constants, ethers } from 'ethers';
import { BridgeLib } from '../typechain-types/contracts/ORManager';

export const defaultChainInfo: BridgeLib.ChainInfoStruct = {
  id: 2,
  batchLimit: BigNumber.from(1000),
  spvs: [constants.AddressZero],
  minVerifyChallengeSourceTxSecond: BigNumber.from(100),
  maxVerifyChallengeSourceTxSecond: BigNumber.from(200),
  minVerifyChallengeDestTxSecond: BigNumber.from(100),
  maxVerifyChallengeDestTxSecond: BigNumber.from(200),
  tokens: [
    {
      decimals: 18,
      token: constants.Two,
      mainnetToken: constants.AddressZero,
    },
  ],
};

export const defaultsEbcs: string[] = new Array(10)
  .fill(undefined)
  .map(() => ethers.Wallet.createRandom().address);
