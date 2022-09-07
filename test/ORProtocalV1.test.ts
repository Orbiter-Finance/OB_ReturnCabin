/* eslint-disable @typescript-eslint/ban-ts-comment */
import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';
import { ORProtocalV1 } from '../typechain-types';
let ebc: ORProtocalV1;
const UserTxList = [
  {
    lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b91',
    id: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b91',
    from: '0x188DD5b655E2fe78f5ede164d37170FB1B941c9e',
    to: '0x80c67432656d59144ceff962e8faf8926599bcf8',
    token: '0x0000000000000000000000000000000000000000',
    chainId: '1',
    fee: '46810453281384',
    value: '998798000000009003',
    nonce: 0,
    timestamp: 111111111,
    responseAmount: 10000,
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
  },
];
// const MakerTxList = [
//   {
//     lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b95',
//     id: '0x6f1308d493d20956ef2806439e095451ba859c02211b60595d6469858161c9bd',
//     from: '0x80c67432656d59144ceff962e8faf8926599bcf8',
//     to: '0xbf28bce31463a3a023c2c324aecbd5689ffa06ee',
//     token: '0x0000000000000000000000000000000000000000',
//     chainId: '7',
//     fee: '378000000000000',
//     value: '276016000000000009',
//     nonce: 62374,
//     timestamp: 111111111,
//     responseAmount: 10000,
//   },

//   {
//     lpid: '0x12747d215bcd3c407229d6fdfaf3c9e29608573499f4640e2d50fdef01360b96',
//     id: '0xd615805a657aa2fae3172ca6f6fdbd1c0036f29c233eb2a94b408f7ef2b29a02',
//     from: '0x80c67432656d59144ceff962e8faf8926599bcf8',
//     to: '0xac9facad1c42986520bd7df5ded1d30d94a13095',
//     token: '0x0000000000000000000000000000000000000000',
//     chainId: '7',
//     fee: '378000000000000',
//     value: '389667000000000007',
//     nonce: 62373,
//     timestamp: 111111111,
//     responseAmount: 10000,
//   },
// ];
describe('ORProtocalV1.test.ts', () => {
  async function createEbcInfo() {
    const managerAddress = process.env['factory'] || '';
    const ORProtocalV1 = await ethers.getContractFactory('ORProtocalV1', {
      libraries: {},
    });
    const ORProtocalV1Proxy = await upgrades.deployProxy(ORProtocalV1, [
      managerAddress,
    ]);
    await ORProtocalV1Proxy.deployed();
    ebc = ORProtocalV1Proxy as ORProtocalV1;
  }

  before(createEbcInfo);
  function getLeaf(tx: typeof UserTxList[0]) {
    const lpid = tx.lpid.toLowerCase();
    const txHash = tx.id.toLowerCase();
    const sourceAddress = tx.from.toLowerCase();
    const destAddress = tx.to.toLowerCase();
    const nonce = tx.nonce;
    const amount = tx.value;
    const chainID = tx.chainId;
    const tokenAddress = tx.token;
    const timestamp = tx.timestamp;
    const responseAmount = tx.responseAmount;
    const hex = ethers.utils.solidityKeccak256(
      [
        'bytes32',
        'uint256',
        'bytes32',
        'address',
        'address',
        'uint256',
        'uint256',
        'address',
        'uint256',
        'uint256',
      ],
      [
        lpid,
        chainID,
        txHash,
        sourceAddress,
        destAddress,
        nonce,
        amount,
        tokenAddress,
        timestamp,
        responseAmount,
      ],
    );
    const leaf = {
      lpid,
      chainID,
      txHash,
      sourceAddress,
      destAddress,
      nonce,
      amount,
      tokenAddress,
      timestamp,
      responseAmount,
    };
    return { hex, leaf };
  }
  it('Create EBC', async () => {
    console.log('EBC address', ebc.address);
  });
  it('Update EBC factory', async () => {
    const factoryAddress = process.env['factory'] || '';
    const spvAddress = process.env['SPV'];
    !expect(factoryAddress).not.empty;
    const factoryContract = await ethers.getContractAt(
      'ORManager',
      factoryAddress,
    );
    await factoryContract.updateEBC(
      (await factoryContract.getEBCids()).toNumber() - 1,
      ebc.address,
    );
    console.log('fa spv', await factoryContract.spv());
    expect(await factoryContract.getEBCids()).equal(1);
    expect(await factoryContract.getEBC(0)).equal(ebc.address);
  });
  it('getETHPunish', async () => {
    const value = UserTxList[0].value;
    const response = await ebc.getETHPunish(value);
    expect(response).lt(ethers.BigNumber.from(value));
  });
  it('getTokenPunish', async () => {
    const value = UserTxList[0].value;
    const response = await ebc.getTokenPunish(value);
    expect(response).lt(ethers.BigNumber.from(value));
  });
  it('getRespnseHash', async () => {
    const { leaf } = getLeaf(UserTxList[0]);
    const expectResponce = ethers.utils.solidityKeccak256(
      ['bytes32', 'uint256', 'address', 'address', 'uint256', 'address'],
      [
        leaf.lpid,
        ethers.BigNumber.from(leaf.amount)
          .mod(ethers.BigNumber.from(10000))
          .sub(ethers.BigNumber.from(9000)),
        leaf.destAddress,
        leaf.sourceAddress,
        leaf.responseAmount,
        leaf.tokenAddress,
      ],
    );
    const realResponse = await ebc.getRespnseHash(leaf);
    expect(expectResponce).equals(realResponse);
  });
});
