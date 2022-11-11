import { expect } from 'chai';
import { ethers } from 'hardhat';
import { ORManager } from '../typechain-types/contracts/ORManager';
import { ORMakerV1Factory } from '../typechain-types/contracts/ORMakerV1Factory';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { MerkleTree } from 'merkletreejs';
import { PAIR_LIST } from './lib/Config';
import keccak256 from 'keccak256';
// import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { CHAIN_INFO_LIST as chainInfoList, TOKEN_LIST } from './lib/Config';
import { deploy } from '../scripts/utils';
let factory: ORManager;
let makerV1Factory: ORMakerV1Factory;
const chainInfo_main = chainInfoList[0];
const chainInfo_arbitrum = chainInfoList[1];
const chainInfo_zksync = chainInfoList[2];
const chainInfo_op = chainInfoList[3];

const tokeninfo_eth_main = TOKEN_LIST[0];
const tokeninfo_usdc_main = TOKEN_LIST[1];
const tokeninfo_usdt_main = TOKEN_LIST[2];
const tokeninfo_eth_arb = TOKEN_LIST[3];
const tokeninfo_usdc_arb = TOKEN_LIST[4];
const tokeninfo_usdt_arb = TOKEN_LIST[5];

async function deployFactoryFixture() {
  const [owner, addr1, addr2] = await ethers.getSigners();
  factory = await deploy<ORManager>(false, 'ORManager');
  await factory.initialize();
  makerV1Factory = await deploy<ORMakerV1Factory>(false, 'ORMakerV1Factory');
  await makerV1Factory.initialize(factory.address.toString());
  return { factory, owner, addr1, addr2 };
}

describe('Factory.spec.ts', () => {
  let userFactory: ORManager;
  let address1: SignerWithAddress;
  let address2: SignerWithAddress;

  async function getFactoryInfo() {
    const { factory, addr1, addr2 } = await deployFactoryFixture();
    userFactory = factory;
    address1 = addr1;
    address2 = addr2;
  }

  before(getFactoryInfo);

  describe('Factory_EBC_TEST', () => {
    it('SET EBC', async () => {
      await userFactory.setEBC(address1.address);
      //ERROR TEST
      // await userFactory.setEBC('0x0000000000000000000000000000000000000000');
      expect(await userFactory.getEBCids()).equal(1);

      expect(await userFactory.getEBC(1)).equal(address1.address);
    });
    it('UPDATE EBC', async () => {
      expect(await userFactory.getEBCids()).equal(1);
      expect(await userFactory.getEBC(1)).equal(address1.address);
      await userFactory.updateEBC(1, address2.address);
      expect(await userFactory.getEBCids()).equal(1);
      expect(await userFactory.getEBC(1)).equal(address2.address);
    });
  });

  describe('Factory_CHAININFO_TEST', () => {
    it('SET CHAININFO', async () => {
      await userFactory.setChainInfo(
        chainInfo_main.chainID,
        chainInfo_main.batchLimit,
        chainInfo_main.maxDisputeTime,
        chainInfo_main.maxReceiptTime,
        chainInfo_main.tokenList,
      );

      await userFactory.setChainInfo(
        chainInfo_arbitrum.chainID,
        chainInfo_arbitrum.batchLimit,
        chainInfo_arbitrum.maxDisputeTime,
        chainInfo_arbitrum.maxReceiptTime,
        chainInfo_arbitrum.tokenList,
      );
      await userFactory.setChainInfo(
        chainInfo_zksync.chainID,
        chainInfo_zksync.batchLimit,
        chainInfo_zksync.maxDisputeTime,
        chainInfo_zksync.maxReceiptTime,
        chainInfo_zksync.tokenList,
      );
      await userFactory.setChainInfo(
        chainInfo_op.chainID,
        chainInfo_op.batchLimit,
        chainInfo_op.maxDisputeTime,
        chainInfo_op.maxReceiptTime,
        chainInfo_op.tokenList,
      );

      expect((await userFactory.chainList(0)).isUsed).false;

      expect((await userFactory.chainList(1)).isUsed).true;
      expect((await userFactory.chainList(1)).chainid).equal(1);
      expect((await userFactory.chainList(1)).batchLimit).equal(100);
      expect((await userFactory.chainList(1)).maxDisputeTime).equal(1200);

      expect((await userFactory.chainList(2)).isUsed).true;
      expect((await userFactory.chainList(2)).chainid).equal(2);
      expect((await userFactory.chainList(2)).batchLimit).equal(100);
      expect((await userFactory.chainList(2)).maxDisputeTime).equal(1200);

      expect((await userFactory.chainList(9999999)).isUsed).false;
    });

    it('UPDATE CHAININFO', async () => {
      const ethInfo = await userFactory.getChainInfoByChainID(1);
      const arInfo = await userFactory.getChainInfoByChainID(2);
      // const errorInfo = await userFactory.getChainInfoByChainID(0);

      expect(ethInfo.isUsed).true;
      expect(ethInfo.chainid).equal(1);
      expect(ethInfo.batchLimit).equal(100);
      expect(ethInfo.maxDisputeTime).equal(1200);

      expect(arInfo.isUsed).true;
      expect(arInfo.chainid).equal(2);
      expect(arInfo.batchLimit).equal(100);
      expect(arInfo.maxDisputeTime).equal(1200);
    });
  });

  describe('Factory_TOKENINFO_TEST', () => {
    it('SET TOKENINFO', async () => {
      for (const token of TOKEN_LIST) {
        await userFactory.setTokenInfo(
          token.chainID,
          token.tokenAddress,
          token.tokenPresion,
          token.mainAddress,
        );
      }
    });
    describe('GET TOKENINFO', () => {
      it('Main_ETH', async () => {
        const main_eth = await userFactory.getTokenInfo(
          tokeninfo_eth_main.chainID,
          tokeninfo_eth_main.tokenAddress,
        );
        expect(main_eth.chainID).equal(1);
        expect(main_eth.tokenAddress).equal(
          '0x0000000000000000000000000000000000000000',
        );
        expect(main_eth.tokenPresion).equal('18');
        expect(main_eth.mainTokenAddress).equal(
          '0x0000000000000000000000000000000000000000',
        );
      });
      it('Main_USDC', async () => {
        const main_usdc = await userFactory.getTokenInfo(
          tokeninfo_usdc_main.chainID,
          tokeninfo_usdc_main.tokenAddress,
        );
        expect(main_usdc.chainID).equal(1);
        expect(main_usdc.tokenAddress.toLowerCase()).equal(
          '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        );
        expect(main_usdc.tokenPresion).equal('6');
        expect(main_usdc.mainTokenAddress.toLowerCase()).equal(
          '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        );
      });
      it('Main_USDT', async () => {
        const main_usdt = await userFactory.getTokenInfo(
          tokeninfo_usdt_main.chainID,
          tokeninfo_usdt_main.tokenAddress,
        );
        expect(main_usdt.chainID).equal(1);
        expect(main_usdt.tokenAddress.toLowerCase()).equal(
          '0xdac17f958d2ee523a2206206994597c13d831ec7',
        );
        expect(main_usdt.tokenPresion).equal('6');
        expect(main_usdt.mainTokenAddress.toLowerCase()).equal(
          '0xdac17f958d2ee523a2206206994597c13d831ec7',
        );
      });
      it('Ar_ETH', async () => {
        const ar_eth = await userFactory.getTokenInfo(
          tokeninfo_eth_arb.chainID,
          tokeninfo_eth_arb.tokenAddress,
        );
        expect(ar_eth.chainID).equal(2);
        expect(ar_eth.tokenAddress).equal(
          '0x0000000000000000000000000000000000000000',
        );
        expect(ar_eth.tokenPresion).equal('18');
        expect(ar_eth.mainTokenAddress).equal(
          '0x0000000000000000000000000000000000000000',
        );
      });
      it('Ar_USDC', async () => {
        const ar_usdc = await userFactory.getTokenInfo(
          tokeninfo_usdc_arb.chainID,
          tokeninfo_usdc_arb.tokenAddress,
        );
        expect(ar_usdc.chainID).equal(2);
        expect(ar_usdc.tokenAddress.toLowerCase()).equal(
          '0xff970a61a04b1ca14834a43f5de4533ebddb5cc8',
        );
        expect(ar_usdc.tokenPresion).equal('6');
        expect(ar_usdc.mainTokenAddress.toLowerCase()).equal(
          '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        );
      });
      it('Ar_USDT', async () => {
        const ar_usdt = await userFactory.getTokenInfo(
          tokeninfo_usdt_arb.chainID,
          tokeninfo_usdt_arb.tokenAddress,
        );

        expect(ar_usdt.chainID).equal(2);
        expect(ar_usdt.tokenAddress.toLowerCase()).equal(
          '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
        );
        expect(ar_usdt.tokenPresion).equal('6');
        expect(ar_usdt.mainTokenAddress.toLowerCase()).equal(
          '0xdac17f958d2ee523a2206206994597c13d831ec7',
        );
      });
    });
  });
  describe('Factory_CREATE_PAIR', () => {
    const leafs = PAIR_LIST.map((row) => {
      return Buffer.from(row.id, 'hex');
    });
    const pairTree = new MerkleTree(leafs, keccak256, {
      sort: true,
    });
    it('Create Support Pair', async () => {
      // create Pair
      const proof = await pairTree.getMultiProof(leafs);
      const proofFlags = pairTree.getProofFlags(leafs, proof);
      const addPairObj = leafs.map((hashBuf) => {
        const leaf = PAIR_LIST.find((pair) => {
          return pair.id.toString() === hashBuf.toString('hex');
        });
        return leaf;
      });
      const tx = await factory.createPair(
        <any>addPairObj,
        pairTree.getHexRoot(),
        proof,
        proofFlags,
      );
      expect(tx.blockNumber).gt(0);
    });
  });
  describe('Factory_CREATE_MDC', () => {
    it('MakerV1Factory Set Manager', async () => {
      const tx = await makerV1Factory.setManager(factory.address);
      expect(tx.blockNumber).gt(0);
    });
    it('CREATE_MDC', async () => {
      // create mdc
      const response = await makerV1Factory.connect(address1).createMaker();
      const tx = await response.wait();
      const makerMapEvent = tx.events?.find(
        (row) => row.event == 'MakerCreated',
      );
      if (makerMapEvent && makerMapEvent.args) {
        process.env['MDC'] = makerMapEvent.args[1].toLowerCase();
        process.env['MDCFactory'] = makerV1Factory.address;
      }
      //
    });
  });
});
