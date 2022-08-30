export const pairList = [
  {
    sourceChain: 1,
    destChain: 2,
    sourceTAddress: '0x0000000000000000000000000000000000000000',
    destTAddress: '0x0000000000000000000000000000000000000000',
    ebcid: '0x0000000000000000000000000000000000000000',
  },
  {
    sourceChain: 1,
    destChain: 3,
    sourceTAddress: '0x0000000000000000000000000000000000000000',
    destTAddress: '0x0000000000000000000000000000000000000000',
    ebcid: '0x0000000000000000000000000000000000000000',
  },
  {
    sourceChain: 2,
    destChain: 1,
    sourceTAddress: '0x0000000000000000000000000000000000000000',
    destTAddress: '0x0000000000000000000000000000000000000000',
    ebcid: '0x0000000000000000000000000000000000000000',
  },
  {
    sourceChain: 3,
    destChain: 1,
    sourceTAddress: '0x0000000000000000000000000000000000000000',
    destTAddress: '0x0000000000000000000000000000000000000000',
    ebcid: '0x0000000000000000000000000000000000000000',
  },
];
export const chainInfoList = [
  {
    chainID: 1,
    batchLimit: 100,
    maxDisputeTime: 3600 * 24,
    tokenList: [
      '0x0000000000000000000000000000000000000000',
      '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
      '0xdac17f958d2ee523a2206206994597c13d831ec7',
    ],
  },
  {
    chainID: 2,
    batchLimit: 100,
    maxDisputeTime: 3600 * 24,
    tokenList: [
      '0x0000000000000000000000000000000000000000',
      '0xff970a61a04b1ca14834a43f5de4533ebddb5cc8',
      '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
    ],
  },
  {
    chainID: 3,
    batchLimit: 100,
    maxDisputeTime: 3600 * 24,
    tokenList: ['0x0000000000000000000000000000000000000000'],
  },
  {
    chainID: 7,
    batchLimit: 100,
    maxDisputeTime: 3600 * 24,
    tokenList: ['0x0000000000000000000000000000000000000000'],
  },
];
export const tokenList = [
  {
    chainID: 1,
    symbol: 'ETH',
    tokenAddress: '0x0000000000000000000000000000000000000000',
    tokenPresion: 18,
    mainAddress: '0x0000000000000000000000000000000000000000',
  },
  {
    chainID: 1,
    symbol: 'USDC',
    tokenAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
    tokenPresion: 6,
    mainAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  },
  {
    chainID: 1,
    symbol: 'USDT',
    tokenAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
    tokenPresion: 6,
    mainAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
  },
  {
    chainID: 2,
    symbol: 'ETH',
    tokenAddress: '0x0000000000000000000000000000000000000000',
    tokenPresion: 18,
    mainAddress: '0x0000000000000000000000000000000000000000',
  },
  {
    chainID: 2,
    symbol: 'USDC',
    tokenAddress: '0xff970a61a04b1ca14834a43f5de4533ebddb5cc8',
    tokenPresion: 6,
    mainAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  },
  {
    symbol: 'USDT',
    chainID: 2,
    tokenAddress: '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
    tokenPresion: 6,
    mainAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
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
  Object.assign(pairList[1], {
    sourcePresion: 18,
    destPresion: 18,
    minPrice: '5000000000000000',
    maxPrice: '9000000000000000',
    gasFee: '10000000000000000',
    tradingFee: '10000000000000000',
    startTime: 0,
  }),
];
