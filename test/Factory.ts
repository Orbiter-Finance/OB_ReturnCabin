import { expect } from 'chai';
import { ethers } from 'hardhat';
import { ORManagerFactory } from '../typechain-types/contracts/ORManagerFactory';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

let factory: ORManagerFactory;

const chainInfo_main = {
  chainID: 1,
  chainName: ethers.utils.defaultAbiCoder.encode(['string'], ['mainNet']),
  batchLimit: 100,
  maxDisputeTime: 3600 * 24,
  tokenList: [
    '0x0000000000000000000000000000000000000000',
    '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
    '0xdac17f958d2ee523a2206206994597c13d831ec7',
  ],
};

const chainInfo_arbitrum = {
  chainID: 2,
  chainName: ethers.utils.defaultAbiCoder.encode(['string'], ['arbitrum']),
  batchLimit: 100,
  maxDisputeTime: 3600 * 24,
  tokenList: [
    '0x0000000000000000000000000000000000000000',
    '0xff970a61a04b1ca14834a43f5de4533ebddb5cc8',
    '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
  ],
};

const tokeninfo_eth_main = {
  chainID: 1,
  tokenAddress: '0x0000000000000000000000000000000000000000',
  tokenPresion: 18,
  tokenName: ethers.utils.defaultAbiCoder.encode(['string'], ['ETH']),
  mainAddress: '0x0000000000000000000000000000000000000000',
};
const tokeninfo_usdc_main = {
  chainID: 1,
  tokenAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  tokenPresion: 6,
  tokenName: ethers.utils.defaultAbiCoder.encode(['string'], ['USDC']),
  mainAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
};
const tokeninfo_usdt_main = {
  chainID: 1,
  tokenAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
  tokenPresion: 6,
  tokenName: ethers.utils.defaultAbiCoder.encode(['string'], ['USDT']),
  mainAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
};
const tokeninfo_eth_arb = {
  chainID: 2,
  tokenAddress: '0x0000000000000000000000000000000000000000',
  tokenPresion: 18,
  tokenName: ethers.utils.defaultAbiCoder.encode(['string'], ['ETH']),
  mainAddress: '0x0000000000000000000000000000000000000000',
};
const tokeninfo_usdc_arb = {
  chainID: 2,
  tokenAddress: '0xff970a61a04b1ca14834a43f5de4533ebddb5cc8',
  tokenPresion: 6,
  tokenName: ethers.utils.defaultAbiCoder.encode(['string'], ['USDC']),
  mainAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
};
const tokeninfo_usdt_arb = {
  chainID: 2,
  tokenAddress: '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
  tokenPresion: 6,
  tokenName: ethers.utils.defaultAbiCoder.encode(['string'], ['USDT']),
  mainAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
};

async function deployFactoryFixture() {
  const [owner, addr1, addr2] = await ethers.getSigners();
  const Factory = await ethers.getContractFactory('ORManagerFactory');
  factory = await Factory.deploy();
  console.log(`factory :`, factory.address);
  return { Factory, factory, owner, addr1, addr2 };
}

describe('Factory.spec.ts', () => {
  let userFactory: ORManagerFactory;
  let address1: SignerWithAddress;
  let address2: SignerWithAddress;

  async function getFactoryInfo() {
    const { factory, addr1, addr2 } = await loadFixture(deployFactoryFixture);
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
      expect(await userFactory.getEBC(0)).equal(address1.address);
    });
    it('UPDATE EBC', async () => {
      expect(await userFactory.getEBCids()).equal(1);
      expect(await userFactory.getEBC(0)).equal(address1.address);

      await userFactory.updateEBC(
        (await userFactory.getEBCids()).toNumber() - 1,
        address2.address,
      );
      expect(await userFactory.getEBCids()).equal(1);
      expect(await userFactory.getEBC(0)).equal(address2.address);
    });
  });

  describe('Factory_CHAININFO_TEST', () => {
    it('SET CHAININFO', async () => {
      await userFactory.setChainInfo(
        chainInfo_main.chainID,
        chainInfo_main.chainName,
        chainInfo_main.batchLimit,
        chainInfo_main.maxDisputeTime,
        chainInfo_main.tokenList,
      );

      await userFactory.setChainInfo(
        chainInfo_arbitrum.chainID,
        chainInfo_arbitrum.chainName,
        chainInfo_arbitrum.batchLimit,
        chainInfo_arbitrum.maxDisputeTime,
        chainInfo_arbitrum.tokenList,
      );

      expect(await (await userFactory.chainList(0)).isUsed).false;

      expect(await (await userFactory.chainList(1)).isUsed).true;
      expect(await (await userFactory.chainList(1)).chainid).equal(1);
      expect(await (await userFactory.chainList(1)).chainName).equal(
        ethers.utils.defaultAbiCoder.encode(['string'], ['mainNet']),
      );
      expect(await (await userFactory.chainList(1)).batchLimit).equal(100);
      expect(await (await userFactory.chainList(1)).maxDisputeTime).equal(
        24 * 3600,
      );

      expect(await (await userFactory.chainList(2)).isUsed).true;
      expect(await (await userFactory.chainList(2)).chainid).equal(2);
      expect(await (await userFactory.chainList(2)).chainName).equal(
        ethers.utils.defaultAbiCoder.encode(['string'], ['arbitrum']),
      );
      expect(await (await userFactory.chainList(2)).batchLimit).equal(100);
      expect(await (await userFactory.chainList(2)).maxDisputeTime).equal(
        24 * 3600,
      );

      expect(await (await userFactory.chainList(3)).isUsed).false;
    });

    it('UPDATE CHAININFO', async () => {
      const ethInfo = await userFactory.getChainInfoByChainID(1);
      const arInfo = await userFactory.getChainInfoByChainID(2);
      // const errorInfo = await userFactory.getChainInfoByChainID(0);

      expect(ethInfo.isUsed).true;
      expect(ethInfo.chainid).equal(1);
      expect(ethInfo.chainName).equal(
        ethers.utils.defaultAbiCoder.encode(['string'], ['mainNet']),
      );
      expect(ethInfo.batchLimit).equal(100);
      expect(ethInfo.maxDisputeTime).equal(24 * 3600);

      expect(arInfo.isUsed).true;
      expect(arInfo.chainid).equal(2);
      expect(arInfo.chainName).equal(
        ethers.utils.defaultAbiCoder.encode(['string'], ['arbitrum']),
      );
      expect(arInfo.batchLimit).equal(100);
      expect(arInfo.maxDisputeTime).equal(24 * 3600);
    });
  });

  describe('Factory_TOKENINFO_TEST', () => {
    it('SET TOKENINFO', async () => {
      await userFactory.setTokenInfo(
        tokeninfo_eth_main.chainID,
        tokeninfo_eth_main.tokenAddress,
        tokeninfo_eth_main.tokenPresion,
        tokeninfo_eth_main.tokenName,
        tokeninfo_eth_main.mainAddress,
      );

      await userFactory.setTokenInfo(
        tokeninfo_usdc_main.chainID,
        tokeninfo_usdc_main.tokenAddress,
        tokeninfo_usdc_main.tokenPresion,
        tokeninfo_usdc_main.tokenName,
        tokeninfo_usdc_main.mainAddress,
      );

      await userFactory.setTokenInfo(
        tokeninfo_usdt_main.chainID,
        tokeninfo_usdt_main.tokenAddress,
        tokeninfo_usdt_main.tokenPresion,
        tokeninfo_usdt_main.tokenName,
        tokeninfo_usdt_main.mainAddress,
      );

      await userFactory.setTokenInfo(
        tokeninfo_eth_arb.chainID,
        tokeninfo_eth_arb.tokenAddress,
        tokeninfo_eth_arb.tokenPresion,
        tokeninfo_eth_arb.tokenName,
        tokeninfo_eth_arb.mainAddress,
      );

      await userFactory.setTokenInfo(
        tokeninfo_usdc_arb.chainID,
        tokeninfo_usdc_arb.tokenAddress,
        tokeninfo_usdc_arb.tokenPresion,
        tokeninfo_usdc_arb.tokenName,
        tokeninfo_usdc_arb.mainAddress,
      );

      await userFactory.setTokenInfo(
        tokeninfo_usdt_arb.chainID,
        tokeninfo_usdt_arb.tokenAddress,
        tokeninfo_usdt_arb.tokenPresion,
        tokeninfo_usdt_arb.tokenName,
        tokeninfo_usdt_arb.mainAddress,
      );
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
        expect(main_eth.tokenName).equal(
          ethers.utils.defaultAbiCoder.encode(['string'], ['ETH']),
        );
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
        expect(main_usdc.tokenName).equal(
          ethers.utils.defaultAbiCoder.encode(['string'], ['USDC']),
        );
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
        expect(main_usdt.tokenName.toLowerCase()).equal(
          ethers.utils.defaultAbiCoder.encode(['string'], ['USDT']),
        );
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
        expect(ar_eth.tokenName).equal(
          ethers.utils.defaultAbiCoder.encode(['string'], ['ETH']),
        );
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
        expect(ar_usdc.tokenName).equal(
          ethers.utils.defaultAbiCoder.encode(['string'], ['USDC']),
        );
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
        expect(ar_usdt.tokenName).equal(
          ethers.utils.defaultAbiCoder.encode(['string'], ['USDT']),
        );
        expect(ar_usdt.mainTokenAddress.toLowerCase()).equal(
          '0xdac17f958d2ee523a2206206994597c13d831ec7',
        );
      });
    });
  });

  describe('Factory_CREATE_MDC', () => {
    it('CREATE_MDC', async () => {
      const mdcAddress = await userFactory.createMaker();
      console.log('mdcAddress =', mdcAddress);
    });
  });
});
