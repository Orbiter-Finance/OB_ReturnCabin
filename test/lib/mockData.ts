import hre, { ethers } from 'hardhat';
import { BridgeLib } from '../../typechain-types/contracts/ORManager';
import { BigNumber, Bytes, constants, utils } from 'ethers';
import lodash from 'lodash';
import axios from 'axios';
import fs from 'fs';

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

// MerkleTreeLib.SMTLeaf[] calldata smtLeaves,
// MerkleTreeLib.MergeValue[][] calldata siblings,
// // bytes32[][] calldata siblingsHashes,
// uint8[] calldata startIndex,
// bytes32[] calldata firstZeroBits,
// uint256[] calldata bitmaps,
// uint256[] calldata withdrawAmount

export interface withdrawVerification {
  smtLeaf: SMTLeaf[];
  siblings: MergeValue[][];
  startIndex: BigNumber[];
  firstZeroBits: Bytes[];
  bitmaps: Bytes[];
  // withdrawAmount: BigNumber[];
  root: string[];
}
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
    profitRoot: profitRootMock[0],
    stateTransTreeRoot: stateTransTreeRootMock,
  };
  return submitInfo;
};

export const proofsMock: string[][] = [
  [ethers.utils.keccak256(ethers.utils.toUtf8Bytes('proofs'))],
];

export const mockKey: SMTKey = {
  chainId: BigNumber.from(5),
  token: '0xa0321efeb50c46c17a7d72a52024eea7221b215a',
  user: '0x15962f38e6998875F9F75acDF8c6Ddc743F11041',
};

export const mockValue: SMTValue = {
  token: '0xa0321efeb50c46c17a7d72a52024eea7221b215a',
  chainId: BigNumber.from(5),
  amount: BigNumber.from(200),
  debt: BigNumber.from(0),
};

export const smtLeavesMock: SMTLeaf[] = [
  {
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
  },
  {
    key: {
      chainId: BigNumber.from(100),
      token: '0x0000000000000000000000000000000000000021',
      user: '0x0000000000000000000000000000000000000022',
    },
    value: {
      token: '0x0000000000000000000000000000000000000021',
      chainId: BigNumber.from(100),
      amount: BigNumber.from(100),
      debt: BigNumber.from(80),
    },
  },
  {
    key: {
      chainId: BigNumber.from(5),
      token: '0xa3a8a6b323e3d38f5284db9337e7c6d74af3366a',
      user: '0x15962f38e6998875F9F75acDF8c6Ddc743F11041',
    },
    value: {
      token: '0xa3a8a6b323e3d38f5284db9337e7c6d74af3366a',
      chainId: BigNumber.from(5),
      amount: BigNumber.from(200),
      debt: BigNumber.from(0),
    },
  },
  {
    key: {
      chainId: BigNumber.from(5),
      token: '0xa3a8a6b323e3d38f5284db9337e7c6d74af3366a',
      user: '0x15962f38e6998875F9F75acDF8c6Ddc743F11041',
    },
    value: {
      token: '0xa3a8a6b323e3d38f5284db9337e7c6d74af3366a',
      chainId: BigNumber.from(5),
      amount: BigNumber.from(238860800000000000000n),
      debt: BigNumber.from(0),
    },
  },
  {
    key: {
      chainId: BigNumber.from(345),
      token: '0xa0321efeb50c46c17a7d72a52024eea7221b215a',
      user: '0xc3C7A782dda00a8E61Cb9Ba0ea8680bb3f3B9d10',
    },
    value: {
      token: '0xa0321efeb50c46c17a7d72a52024eea7221b215a',
      chainId: BigNumber.from(345),
      amount: BigNumber.from(838860800000000000000n),
      debt: BigNumber.from(0),
    },
  },
  {
    key: {
      chainId: BigNumber.from(5),
      token: '0xa0321efeb50c46c17a7d72a52024eea7221b215a',
      user: '0x15962f38e6998875F9F75acDF8c6Ddc743F11041',
    },
    value: {
      token: '0xa0321efeb50c46c17a7d72a52024eea7221b215a',
      chainId: BigNumber.from(5),
      amount: BigNumber.from(838860800000000000000n),
      debt: BigNumber.from(0),
    },
  },
  {
    key: {
      chainId: BigNumber.from(5),
      token: '0xa3a8a6b323e3d38f5284db9337e7c6d74af3366a',
      user: '0x15962f38e6998875F9F75acDF8c6Ddc743F11041',
    },
    value: {
      token: '0xa3a8a6b323e3d38f5284db9337e7c6d74af3366a',
      chainId: BigNumber.from(5),
      amount: BigNumber.from(838860800000000000000n),
      debt: BigNumber.from(0),
    },
  },
];

// export const smtLeavesMock1: SMTLeaf = {};

export const submitter2Mock = '0xD6Cec62CE67E09b240B84A3FB53cC1EbA05795d6';

export const profitRootMock: string[] = [
  '0xfbfcd98ac0c411b5d62d56e8d37e1f79dde7de67fa17bdbb12a5f942703ac7ff',
  '0x7079a474f9bec927bf070f5e1b9b21da95facd7bdbd43d52c2505b26473b5de3',
  '0xfbfcd98ac0c411b5d62d56e8d37e1f79dde7de67fa17bdbb12a5f942703ac7ff',
  '0x95f0ec76ab0a7457c24aecde2f52206e26e00a7bc467f20b4f5abbb7f99bc495',
  '0x5f81a2f127da561271b6ade652be145a69bf3a73ccf398ffc21e710d5b5e8d5e',
  '0x5f81a2f127da561271b6ade652be145a69bf3a73ccf398ffc21e710d5b5e8d5e',
  '0xc44f1273f528aa869a0c34b9ba7203697d385e88b809eb86adf42858a8614e1d',
];
export const bitmapMock: Bytes[] = [
  '0x00000000000000000000000000000000000000000000000000000000000003ff' as unknown as Bytes,
  '0x0000000000000000000000000000000000000000000000000000000000000007' as unknown as Bytes,
  '0x00000000000000000000000000000000000000000000000000000000000001ff' as unknown as Bytes,
  '0x00000000000000000000000000000000000000000000000000000000000fffff' as unknown as Bytes,
  '0x000000000000000000000000000000000000000000000000000000000027ffff' as unknown as Bytes,
  '0x00000000000000000000000000000000000000000000000000000000000fffff' as unknown as Bytes,
  '0x000000000000000000000000000000000000000000000000000000000000000a' as unknown as Bytes,
];

export const zeroBitsMock: Bytes[] = [
  '0x0bb3696cdbd7208860e9d53efd6c0f72a10597148be66b509d7659ff07f06c00' as unknown as Bytes,
  '0x31364e4bce7c348943fc7a2e69fd4d912c32581a672f651dbf04f56d5b028ec0' as unknown as Bytes,
  '0x474ee95d5fdac65dc465f56a38291858027c6c57bbe25f7d9cdce74760aebf48' as unknown as Bytes,
  '0x474ee95d5fdac65dc465f56a38291858027c6c57bbe25f7d9cdce74760a00000' as unknown as Bytes,
  '0x37616663a4a2a69e16a61dbd3dfb88e6a0984277eaa0bbf01a0f4159d5c00000' as unknown as Bytes,
  '0x0bb3696cdbd7208860e9d53efd6c0f72a10597148be66b509d7659ff07f00000' as unknown as Bytes,
  '0x0bb3696cdbd7208860e9d53efd6c0f72a10597148be66b509d7659ff07f06cb0' as unknown as Bytes,
];

export const mergeValueMock: MergeValue[] = [
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xd01d78e416f465601c781101318c55fb5e152f67cb577466214699a56efd601a' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 1,
    mergeValue: {
      value1: 247,
      value2:
        '0xb689a06a09b91a18de59fadc7cca5c7184c53ae1a66f387b779c8667bb5d2a7b' as unknown as Bytes,
      value3:
        '0xfe3cc51e7d9c295e18aaf17f3797a513975dea955dd36d153693b3218e111000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x3e5e9bfbc87aa4266c0715dc94594e0330b2833738290c209471050738a543c1' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x7b3ad91d21a584cfaafda5c04c849f1fada93ccfa156a8d0720c301c49140292' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xd11b18c99f447881b09f71a0e58a6fb7d82922016edc1db9fbc27aa98543d997' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xbc7c4f1f03f4fdaa1262aa59848242fe4c51c3212c2ce2d1af763f520c668e49' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x1414e7a1cedd79f29a1097e284e59782d05dd15fa82e32564d6f6cd3e367d7b1' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x937cdb71a7a8ca9e6317423c8af41147f7112fc6e5a20b3e758aa928c9729712' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x30659a1e41f23a9dcda6335bd66455707532d15b5f00b1f7e77d69635e63c8f5' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xc1a7860320fdfaded0b6d9081e7379b32004b5c6094dd658d49391663808ea60' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
];

export const siblingHashesMock: string[] = [
  '0xfeb88050122b8b29452c711954d89cfb08c41b4bb59ff23e64550ff690de1d38',
  '0x7f7ad78356188e55a8008aa31a869fa52cffd6d16080808429597269006c5b61',
  '0xc6659fbbf925aeb2bf68f766ddca17bd264df89ce7fcd9c1841e7a3c04acd068',
  '0x487c7ae678a58e61950a0f559db410a748858b175286ada094715001e7364f76',
  '0x93991f18c409de8bcf12697d43a9d149cafc6de185b4c8bda444b43ff6faaada',
  '0x3b9de1657cf100425edd73d8c0950e1f795883ccfece78386b60fd00fd19f60c',
  '0xca0ec6f9f2fb43ea397fe655ad8b4b96a64ca55ea6fd43264421e0c23a49aae6',
  '0xa667ee71eed6f7007a72307ab7b6b210a7894f8116de4ba0bcdb85f4a5abe7f7',
  '0x6942ad62f3b333d9ed3814135bc7360301e21b6c403900a31122f4722fdf18ad',
  '0xfbfcd98ac0c411b5d62d56e8d37e1f79dde7de67fa17bdbb12a5f942703ac7ff',
];

export const startIndexMock: BigNumber[] = [
  BigNumber.from(246),
  BigNumber.from(253),
  BigNumber.from(247),
  BigNumber.from(236),
  BigNumber.from(234),
  BigNumber.from(236),
  BigNumber.from(252),
];

export const mergeValueMock6: MergeValue[] = [
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
      value1: 1,
      value2:
        '0xe51fcf55c52e9b9b7b798ccc30f943189862608c215a374a5cfa167a33eeb2b1' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
];

export const mergeValueMock5: MergeValue[] = [
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x2c582fb1e9003b9deb3e9a79c95d51dbbb39789816e8c6a668ad8d4914f6a109' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 1,
    mergeValue: {
      value1: 237,
      value2:
        '0xf771d92dbc8eea087cdf2463b0a3bf1f2dbedba96e9d98ff9dc2138ec3920bce' as unknown as Bytes,
      value3:
        '0x3f97323252edbf0eb2abf04d8f14e6ad0633acc415f735682eb4348b87c00000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x1c5987bf2fbaf97badc47867aac83c0532918a1d5ecf41ebb651845336fef660' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x9421005c0b07cca54fcaca4960b6d1985b5fc4f86c83cef462b0a91b092ac041' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x5102c820b76cbfd3fe0dce755ca1e991539b62a59dfa33a71befc0f17fa9da2f' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x67e3ae0c6b657405c920eb1049b077455d08e649d2fb9754ab7f30711ed7b0da' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x772585134b49f2de7abfe32a3afdde9479e45c246a01e90507d783a20ee2f9db' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x6919d3bbe263460fe18d6431b3380f38ad8fe72a70d53c355dd06eb66fc8d803' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x96606b975c3442b565ca1b8292b3ede6b29bec203e87fe37aa52f49d2f264bfa' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x3dc03d52b1bafc77022e25174fc751eaed1f1a1f319044b1ce6b143f6775f0b2' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x20b060a7e682fea5e117096d7cd2c42a3d753352ed862f9df07c382ce0c537e4' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x9e862c3c282bab8f8d41c85a1758dc379e87367977a96d83df549dafda2575e8' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x130b04bae100b17b714f69759b909608b1756c11f0299654efe55b14711bca06' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x4d848d4ec1cbcb1f0f4e233c0445e54f24b942f51d60578b2132a29ed57a9fd2' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xb35838141177f1534f5b97615c6e4513cd22202ce73706976edc69984b3be70e' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xd0436ee6ecacdc7ecb4d0c9c6d5dcc2eb5e6e10cc687eb8ddf9d83c0baeac323' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xb6f8496f96c4b8e041c04087f69f8f83ecf08ae163255976ef7d6fa46fbccd03' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xdb009feb622bce53043e2093aedeac6a0f5adc69d7398149c8cc9ad68a9d9426' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x92f62225cd87b335040bf8a20de9848c2d00bee3cdff54e34172c419656ada4c' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xad446f169c9bcdf03aa0146f8839db6cb713ad8fe03bdfa453af585900b764b0' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
];

export const mergeValueMock4: MergeValue[] = [
  {
    mergeType: 1,
    mergeValue: {
      value1: 234,
      value2:
        '0xaf25dc0d514d495d5b9fe00994fadb26b988e03204171c18db4c0c83095e8d50' as unknown as Bytes,
      value3:
        '0x4df7289d1d666ded30e7f98897c8a154ee14bdbe0968ba38a9085123de400000' as unknown as Bytes,
    },
  },
  {
    mergeType: 1,
    mergeValue: {
      value1: 237,
      value2:
        '0xcb3a557f6240e66a964fd2aad27676605907ef1556cd5e8e8716cbb4c1f1bc25' as unknown as Bytes,
      value3:
        '0xa31aaa3872b9172100dd24f04480eb7040cbe97d552081d53e8be324c5180000' as unknown as Bytes,
    },
  },
  {
    mergeType: 1,
    mergeValue: {
      value1: 1,
      value2:
        '0xb62fa99869efec85aceb612d839051c962c7fb439bde1a09769e63204845d193' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000040000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x9214ed28dfcf0db6dfaaa863a8d610b6553c9353742e4641afdc945de28b89a6' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xe659a0eed8795115b7c71a9527b2109ea5abe9531ea7dac63a0f36ab8454601f' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xd7ce6bc5dbd458c8ac67612e925c649ee320b8f20c23e8dbe129f84dbd0316cd' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x06d9aae61c99d4c3aed5af3162bc667fc45455d05beff1beec6c0adc892d81b0' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xf654a5866252e2b3844422af5bb3ef775f20c6ef7515982865a96325cf9092b7' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x0fedf4e475d402fa02a7bb345280b7be3eb1ab019ee41e357a06ca0374c8e286' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x12bc56e44cedbcc350582cc7ca10e32f597ddee1fe86c6c02dea168255867a6e' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x669d5781d2eb5fd42feddea0ef746cef31fdd21ed30d2fb6c86c6d2fc27ec321' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x3c2de93c1775793f2c7b10a52762820738708d182aded1b1b4316eb017b0c588' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xa062f6ec0a5a3ae21aae1553c030e6a6d48b0b61ec3d244c754c613cd2c98da6' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x0b77543d1d6bccc226c50dcf26e7345c8040ac122b3b27b8cf62e3a83f75f9c0' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x832469df4b1383114e433d2561657ea895cca6c5d4e7eaf1085f8e93d87e4cfc' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x07b958546733e99db43ce63e448fe993d7eecf1daf5b32e8fc07150ab1f0fdb3' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xd77bbaff2c3a68efd0dfeb7d3f9e236cdd7b52df63a2d8a4622c1e2aa3ae45ab' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x57629892fd7fb9fe5cfc02320df9e8cc38bf3a270f9d0c1a8a4d40327c7c4cc3' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x7ebecd994632d774348b981055667b8603030c5fea51d8de01bfc5450e82e545' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x697de267a203a5d52f1b300fa8d786dbcb41c80e45e20746b9623c19b5c61ed4' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
];

export const mergeValueMock3: MergeValue[] = [
  {
    mergeType: 1,
    mergeValue: {
      value1: 236,
      value2:
        '0xba4c891b9a6a3a56dfc36c9f81a4f1de723f3316ca018dce106cef6f4bcb1a0c' as unknown as Bytes,
      value3:
        '0x49f3654d97439f91d31d6f3f94e23b17574ba3595694a6900890ea675f000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 1,
    mergeValue: {
      value1: 2,
      value2:
        '0x14778c9bba4250f7855e37fa8cc84ce0aac4733138ee6dd466e1059f792c8700' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000180000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x39c89458ab84a9d9dac360feba7fe5710a25308296d4b2f7d6c816505e909e01' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 1,
    mergeValue: {
      value1: 239,
      value2:
        '0xd6a8cd4d12aa7c56823c79a26fe619e4b771920c1c8ce6bfa55cd10672bd9c14' as unknown as Bytes,
      value3:
        '0xafd886ee1fb9b135fc7fd9e13eb440bba78c48b86e5d032581bfc30c6b700000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xc79b33768ab2106f6d0d1059cbc834fb8557ad43dee0a7e609c39c6ea992a896' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x4e0aefbabecd68bf5b9e9f4e117a939cc318539d956170db139ecb77a5af5862' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xb3fbf012f2f25d30052b48a1b7b8132450e014e5a6f4aa053600eb6b07a4d2d0' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xf5c0c820c55bf750b65c05cacb8f3bd2aa53d2677a32f12384769d8a4ffdc54f' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x0e22940d75380233b00fd96531ff2cadf970fb9456ba6ef1b9fe9c4339acddce' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },

  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x967ed679c2075987b803ce81af794ab8b95c26935ddc09d13ebd7937f107172c' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x0a4d18b7a19cb3ad4dc6b47c1e24c401232f0ad732b13e6115a15e8c8887af50' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x3ac4cc5c12b2dd9c9d0da1d0a545c52c2ba21c64eb2065ceb927f2230b4b6d62' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x0d36aadf8e0f76cfdc74dfe4722a65523d3e7495667887954479df84adb849c7' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x7a1b141b25686a1f4edc26193c7706f7bc0be796d0b6cb552c90b656ed0e72ca' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x91679e670e24094eec5c7b70059b2bf23a239838fe029f1ea62e0e83d3c64614' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x92c86ebdd08b14a5ab94131ed1c936265452f4e6dc7790df0d49ae27003be6ae' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x71738b3990582ea50cac7a0750eaa301ad3aec9611b7686c0178b2994e97f52f' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x7d2d89f67bb5d62066fca84f6f8461b7359c64f446832f0da282673304815190' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xec7242a15d45d0ada37ab5866a0d5d2a2b7c305a765c475a10f31d6b25cc5ecd' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xa15b5cf14730f10d672696002c8dfd01f3c2a357053401efd11a0da355568f1c' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
];

export const mergeValueMock2: MergeValue[] = [
  {
    mergeType: 1,
    mergeValue: {
      value1: 247,
      value2:
        '0xa22b79d36210c6691a5e3759439e4adcaed509a3785838a951edcd0d73ae83d2' as unknown as Bytes,
      value3:
        '0x73be92482c0d4c40d1df614f2e741fabd20d00ed19293c63d16fa3992eb20400' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x41d7d033fee3c95ad6897050fdfdfc2bffd1231ece912c6ed63cd8d0b5d48f14' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x570f42f91b41e62872e04d7d25fb540cf56e151c385c752b01281d8345ae6009' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x6aeaf8f526fb6ce91cef54be000cf84fefae6316e23e3952189d9a4b1b87077c' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xbd88b50d1e6ea8a56f56ab4c52470c864a8480985bbc3f00156d5b124754ef39' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x7c7e536961ae26a8c068d49dccc39c6e51095fe85bd8110a3b98943af4f1fd59' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0x35379709f346f80e0420afb130f62782b8f66ca38ee63168a8ae6277866e1d5d' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xa667ee71eed6f7007a72307ab7b6b210a7894f8116de4ba0bcdb85f4a5abe7f7' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
  {
    mergeType: 0,
    mergeValue: {
      value1: 0,
      value2:
        '0xc1a7860320fdfaded0b6d9081e7379b32004b5c6094dd658d49391663808ea60' as unknown as Bytes,
      value3:
        '0x0000000000000000000000000000000000000000000000000000000000000000' as unknown as Bytes,
    },
  },
];

export const mergeValueMock1: MergeValue[] = [
  {
    mergeType: 1,
    mergeValue: {
      value1: 253,
      value2:
        '0xa4366628111703a3b0bb5cec1fceab50f570e0dd51d56dd6eb7a2a54bab3849b' as unknown as Bytes,
      value3:
        '0x1fd30ea2d276c20bec69f8ea60934f416cf0fed1dd41d1bf14bce37dbea5ab60' as unknown as Bytes,
    },
  },
  {
    mergeType: 1,
    mergeValue: {
      value1: 254,
      value2:
        '0x2a05c298a79e5e065d6ed28d4e3740bbd6ecee14cd6321be5d5039ed2db785ba' as unknown as Bytes,
      value3:
        '0xda95503be5e50362f74ec227db12634ff5ddb055409910557ec6d12735b410b4' as unknown as Bytes,
    },
  },
  {
    mergeType: 1,
    mergeValue: {
      value1: 255,
      value2:
        '0x086f5ccd56d9fe6db616a7420c05d3192c2374f6d0405f6d463464a6aca7952f' as unknown as Bytes,
      value3:
        '0x6436bc10c965a82e3ced8b386e05b84c8a3d7193701a4019a46237abd5d31afa' as unknown as Bytes,
    },
  },
];

export const withdrawArgSetting: withdrawVerification[] = [
  {
    smtLeaf: [smtLeavesMock[0]],
    siblings: [mergeValueMock],
    startIndex: [startIndexMock[0]],
    firstZeroBits: [zeroBitsMock[0]],
    bitmaps: [bitmapMock[0]],
    root: [profitRootMock[0]],
  },
  {
    smtLeaf: [smtLeavesMock[1]],
    siblings: [mergeValueMock1],
    startIndex: [startIndexMock[1]],
    firstZeroBits: [zeroBitsMock[1]],
    bitmaps: [bitmapMock[1]],
    root: [profitRootMock[1]],
  },
  {
    smtLeaf: [smtLeavesMock[2]],
    siblings: [mergeValueMock2],
    startIndex: [startIndexMock[2]],
    firstZeroBits: [zeroBitsMock[2]],
    bitmaps: [bitmapMock[2]],
    root: [profitRootMock[2]],
  },
  {
    smtLeaf: [smtLeavesMock[3]],
    siblings: [mergeValueMock3],
    startIndex: [startIndexMock[3]],
    firstZeroBits: [zeroBitsMock[3]],
    bitmaps: [bitmapMock[3]],
    root: [profitRootMock[3]],
  },
  {
    smtLeaf: [smtLeavesMock[4]],
    siblings: [mergeValueMock4],
    startIndex: [startIndexMock[4]],
    firstZeroBits: [zeroBitsMock[4]],
    bitmaps: [bitmapMock[4]],
    root: [profitRootMock[4]],
  },
  {
    smtLeaf: [smtLeavesMock[5]],
    siblings: [mergeValueMock5],
    startIndex: [startIndexMock[5]],
    firstZeroBits: [zeroBitsMock[5]],
    bitmaps: [bitmapMock[5]],
    root: [profitRootMock[5]],
  },
  {
    smtLeaf: [smtLeavesMock[6]], // 6 is not working
    siblings: [mergeValueMock6],
    startIndex: [startIndexMock[6]],
    firstZeroBits: [zeroBitsMock[6]],
    bitmaps: [bitmapMock[6]],
    root: [profitRootMock[6]],
  },
];

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
  // console.log('Current timestamp:', currentTime);
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
  // console.log(
  //   `mine ${minutes} minutes, current time: ${await getCurrentTime()}`,
  // );
}

export function callDataCost(data: string): number {
  return ethers.utils
    .arrayify(data)
    .map((x) => (x === 0 ? 4 : 16))
    .reduce((sum, x) => sum + x);
}

export function bytesToNumber(bytes: Bytes): number {
  const hexString = utils.hexlify(bytes);
  return parseInt(hexString.slice(2), 16);
}

export async function submitter_getProfitProof(
  tokens: [number, string][],
  user: string,
): Promise<SMTLeaf> {
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  console.log(`get userAddress: ${user}, tokenAddress: ${tokens}`);
  const url = process.env['SUBMITTER_RPC']!;
  const data = {
    jsonrpc: '2.0',
    method: 'submitter_getProfitProof',
    params: {
      user: user,
      tokens: tokens,
    },
    id: 1,
  };

  const response = await axios.post(url, data, {
    headers: { 'Content-Type': 'application/json' },
    validateStatus: () => true,
  });

  fs.writeFileSync(
    'test/RPC_DATA/response.json',
    JSON.stringify(response.data),
  );
  return response.data.result;
}
