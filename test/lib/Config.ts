import { getPairID, getPairLPID } from './Utils';
export interface PairStruct {
  id: string;
  sourceChain: number;
  destChain: number;
  sourceTAddress: string;
  destTAddress: string;
  ebcid: any;
}
export interface LpInfoStruct {
  id: string;
  pairId: string;
  sourcePresion: number;
  destPresion: number;
  maxPrice: string;
  minPrice: string;
  gasFee: string;
  tradingFee: string;
  startTime: number;
  stopTime?: number;
}
export const PAIR_LIST: PairStruct[] = [
  {
    id: '',
    sourceChain: 1,
    destChain: 2,
    sourceTAddress: '0x0000000000000000000000000000000000000000',
    destTAddress: '0x0000000000000000000000000000000000000000',
    ebcid: '0x0000000000000000000000000000000000000000',
  },
  {
    id: '',
    sourceChain: 1,
    destChain: 3,
    sourceTAddress: '0x0000000000000000000000000000000000000000',
    destTAddress: '0x0000000000000000000000000000000000000000',
    ebcid: '0x0000000000000000000000000000000000000000',
  },
  {
    id: '',
    sourceChain: 2,
    destChain: 1,
    sourceTAddress: '0x0000000000000000000000000000000000000000',
    destTAddress: '0x0000000000000000000000000000000000000000',
    ebcid: '0x0000000000000000000000000000000000000000',
  },
  {
    id: '',
    sourceChain: 3,
    destChain: 1,
    sourceTAddress: '0x0000000000000000000000000000000000000000',
    destTAddress: '0x0000000000000000000000000000000000000000',
    ebcid: '0x0000000000000000000000000000000000000000',
  },
].map((row: PairStruct) => {
  row.id = getPairID(row);
  return row;
});
export const LP_LIST: LpInfoStruct[] = [
  {
    id: '',
    pairId: String(PAIR_LIST[0].id),
    sourcePresion: 18,
    destPresion: 18,
    minPrice: '5000000000000000',
    maxPrice: '9000000000000000',
    gasFee: '10000000000000000',
    tradingFee: '10000000000000000',
    startTime: 0,
    stopTime: 0,
  },
  {
    id: '',
    pairId: String(PAIR_LIST[2].id),
    sourcePresion: 18,
    destPresion: 18,
    minPrice: '5000000000000000',
    maxPrice: '9000000000000000',
    gasFee: '10000000000000000',
    tradingFee: '10000000000000000',
    startTime: 0,
    stopTime: 0,
  },
].map((row: LpInfoStruct) => {
  row.id = getPairLPID(row);
  return row;
});
export const CHAIN_INFO_LIST = [
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
export const TOKEN_LIST = [
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
export const USER_TX_LIST = [
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b91',
    id: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b91',
    from: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '1',
    fee: '46810453281384',
    value: '998798000000009003',
    nonce: 0,
    timestamp: 111111111,
    responseAmount: 10000,
    ebcid: 0,
  },
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b94',
    id: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b92',
    from: '0xAec1379dc4BDe48245F75f9726239cEC2E0C8DDa',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    chainId: '1',
    token: '0x0000000000000000000000000000000000000000',
    fee: '46810453281384',
    value: '998798000000009003',
    nonce: 1,
    timestamp: 111111111,
    responseAmount: 10000,
    ebcid: 0,
  },
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b93',
    id: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b93',
    from: '0xE879e54Ab4893953773C0b41304A05C2D49cc612',
    chainId: '1',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    fee: '46810453281384',
    value: '998798000000009003',
    nonce: 3,
    timestamp: 111111111,
    responseAmount: 10000,
    ebcid: 0,
  },
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b92',
    id: '0xfd123fe2054b7f2140ebc9be98dc8638d17f7eae74887894d220d160dc188c1b',
    from: '0xbf28bce31463a3a023c2c324aecbd5689ffa06ee',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '3',
    fee: '20969931642240',
    value: '276866090070000000',
    nonce: 9,
    timestamp: 111111111,
    responseAmount: 10000,
    ebcid: 0,
  },
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b99',
    id: '0xfd123fe2054b7f2140ebc9be98dc8638d17f7eae74887894d220d160dc188c1a',
    from: '0x90F79bf6EB2c4f870365E785982E1f101E93b906',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '1',
    fee: '20969931642240',
    value: '276866090070009007',
    nonce: 10,
    timestamp: 111111111,
    responseAmount: 10010,
    ebcid: 0,
  },
];
export const MAKER_TX_LIST = [
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b95',
    id: '0x6f1308d493d20956ef2806439e095451ba859c02211b60595d6469858161c9bd',
    from: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    to: '0xbf28bce31463a3a023c2c324aecbd5689ffa06ee',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '7',
    fee: '378000000000000',
    value: '276016000000000009',
    nonce: 62374,
    timestamp: 111111111,
    responseAmount: 10000,
    ebcid: 0,
  },

  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b96',
    id: '0xd615805a657aa2fae3172ca6f6fdbd1c0036f29c233eb2a94b408f7ef2b29a02',
    from: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    to: '0xac9facad1c42986520bd7df5ded1d30d94a13095',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '7',
    fee: '378000000000000',
    value: '389667000000000007',
    nonce: 62373,
    timestamp: 111111111,
    responseAmount: 10000,
    ebcid: 0,
  },
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b99',
    id: '0xfd123fe2054b7f2140ebc9be98dc8638d17f7eae74887894d220d160dc188c1a',
    from: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    to: '0x90F79bf6EB2c4f870365E785982E1f101E93b906',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '7',
    fee: '378000000000000',
    value: '276016000000000010',
    nonce: 62372,
    timestamp: 111151111,
    responseAmount: 10010,
    ebcid: 0,
  },
];
