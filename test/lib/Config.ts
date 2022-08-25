export const pairList = [
  {
    sourceChain: 1,
    destChain: 2,
    sourceTAddress: '0x0000000000000000000000000000000000000000',
    destTAddress: '0x0000000000000000000000000000000000000000',
    ebcid: '0x0000000000000000000000000000000000000000',
  },
];
export const lpInfoList = [
  Object.assign(pairList[0], {
    sourcePresion: 18,
    destPresion: 18,
    minPrice: '5000000000000000',
    maxPrice: '9000000000000000',
    gasFee: '10000000000000000',
    tradingFee: '10000000000000000',
    startTime: 0,
  }),
];
