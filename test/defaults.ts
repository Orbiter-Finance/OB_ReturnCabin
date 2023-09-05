import { BigNumber, constants, ethers } from 'ethers';
import { BridgeLib } from '../typechain-types/contracts/ORManager';
import { RuleLib } from '../typechain-types/contracts/interface/IOREventBinding';

export const defaultChainInfo: BridgeLib.ChainInfoStruct = {
  id: BigNumber.from(5),
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

export const defaultsEbcs: string[] = new Array(9)
  .fill(undefined)
  .map(() => ethers.Wallet.createRandom().address);

export const defaultRuleOneway: RuleLib.RuleOnewayStruct = {
  sourceChainId: 0,
  destChainId: 0,
  status: 0,
  sourceToken: 0,
  destToken: 0,
  minPrice: 0,
  maxPrice: 0,
  withholdingFee: 0,
  tradingFee: 0,
  responseTime: 0,
  compensationRatio: 0,
};
