import { expect } from 'chai';
import {
  DataInit,
  getManagerContract,
  getORProtocalV1Contract,
  getORSPVContract,
} from './utils.test';

describe('ORManager.test.ts => Chain', () => {
  it('initChain', async () => {
    const contract = await getManagerContract();
    const chains = DataInit.chains;
    const addTokensData: any[] = [];
    const addChainsData = chains.map((chain) => {
      for (const token of chain.tokenList) {
        addTokensData.push(
          contract.interface.encodeFunctionData('setTokenInfo', [
            chain.id,
            token.decimals,
            token.address,
            token.pledgeToken,
          ]),
        );
      }
      return contract.interface.encodeFunctionData('setChainInfo', [
        chain.id,
        chain.chainID,
        chain.batchLimit,
        chain.maxDisputeTime,
        chain.maxReceiptTime,
        chain.stopDelayTime,
        chain.maxBits,
      ]);
    });
    await contract.multicall(addChainsData);
    await contract.multicall(addTokensData);
  });
  it('init Pairs', async () => {
    const contract = await getManagerContract();
    const pairs = DataInit.pairs;
    const addPair1 = await contract.addPair(pairs[0]);
    await addPair1.wait();
    const datas = pairs.map((row) => {
      return contract.interface.encodeFunctionData('addPair', [row]);
    });
    const tx = await contract.multicall(datas);
    await tx.wait();
    const pairIds = await contract.getPairIds();
    expect(pairIds.length).eq(datas.length);
    for (const pairId of pairIds) {
      const pair = await contract.getPairs(pairId);
      const localPair = pairs.find((p) => p.id === pairId);
      expect(localPair).not.empty;
      expect(pair).not.empty;
      expect(pair.sourceChain).eq(localPair.sourceChain);
      expect(pair.destChain).eq(localPair.destChain);
      expect(pair.sourceToken).eq(localPair.sourceToken);
      expect(pair.ebc).eq(localPair.ebc);
    }
  });
  it('Delete Pair (Not Exists)', async () => {
    const contract = await getManagerContract();
    const response = contract.removePair(
      '0xafee4ad1a2d0f54fdfde4a5f259c9d035b0ed39a8f615477f59c021ac2a274ad',
    );
    await expect(response).to.be.revertedWith('ID does not exist');
  });
  it('Delete Pair (Exists)', async () => {
    const contract = await getManagerContract();
    const pairs = DataInit.pairs;
    const pairId = pairs[0].id;
    const response = await contract.removePair(pairId);
    const isSupport = await contract.isSupportPair(pairId);
    await expect(isSupport).false;
    const pairInfo = await contract.getPairs(pairId);
    await expect(pairInfo.sourceChain).eq(0);
    await expect(pairInfo.destChain).eq(0);
  });
  it('Add deleted Pair', async () => {
    const contract = await getManagerContract();
    const pairs = DataInit.pairs;
    const pairId = pairs[0].id;
    await contract.addPair(pairs[0]);
    const isSupport = await contract.isSupportPair(pairId);
    await expect(isSupport).true;
  });

  it('Check Chain Field Value', async () => {
    const chains = DataInit.chains;
    const manager = await getManagerContract();
    for (const chain of chains) {
      const {
        id,
        chainID,
        batchLimit,
        maxDisputeTime,
        maxReceiptTime,
        tokenList,
      } = chain;
      const chainRes = await manager.getChain(id);
      expect(chainRes.chainId).equal(chainID);
      expect(chainRes.batchLimit).equal(batchLimit);
      expect(chainRes.maxDisputeTime).equal(maxDisputeTime);
      expect(chainRes.maxReceiptTime).equal(maxReceiptTime);
      for (const tokenItem of tokenList) {
        const token = await manager.getTokenInfo(id, tokenItem.address);
        expect(token.tokenAddress.toLowerCase()).equal(
          String(tokenItem.address).toLowerCase(),
        );
        expect(token.decimals).equal(tokenItem.decimals);
        expect(token.mainTokenAddress).equal(tokenItem.pledgeToken);
        expect(token.chainID).equal(id);
      }
    }
  });
  it('Manager Change Chain batchLimit', async () => {
    const chains = DataInit.chains;
    const manager = await getManagerContract();
    const {
      id,
      chainID,
      batchLimit,
      stopDelayTime,
      maxDisputeTime,
      maxReceiptTime,
      maxBits,
    } = chains[0];
    await manager
      .setChainInfo(
        id,
        chainID,
        batchLimit * 2,
        maxDisputeTime,
        maxReceiptTime,
        stopDelayTime,
        maxBits,
      )
      .then(async (tx) => {
        await tx.wait();
        expect((await manager.getChain(id)).batchLimit).equal(batchLimit * 2);
      });
  });
  it('isSupportChain Token', async () => {
    const chains = DataInit.chains;
    const manager = await getManagerContract();
    const { id } = chains[0];
    let tokenInfo = await manager.getTokenInfo(
      id,
      '0x0000000000000000000000000000000000000000',
    );
    expect(tokenInfo.chainID).gt(0);
    tokenInfo = await manager.getTokenInfo(
      id,
      '0x0000000000000000000000000000000000000001',
    );
    expect(tokenInfo.chainID).eq(0);
  });
  it('Manager Change Token tokenPresion', async () => {
    const manager = await getManagerContract();
    const chains = DataInit.chains;
    const { id, tokenList } = chains[0];
    const { address, decimals, pledgeToken } = tokenList[0];
    await manager
      .setTokenInfo(
        id,
        decimals,
        address,
        '0x0000000000000000000000000000000000000001',
      )
      .then(async (tx) => {
        await tx.wait();
        const contractToken = await manager.getTokenInfo(id, address);
        expect(contractToken.mainTokenAddress).equal(
          '0x0000000000000000000000000000000000000001',
        );
      });

    await manager
      .setTokenInfo(id, decimals, address, pledgeToken)
      .then(async (tx) => {
        await tx.wait();
        const contractToken = await manager.getTokenInfo(id, address);
        expect(contractToken.mainTokenAddress).equal(pledgeToken);
      });
  });
});
describe('Manager EBC', () => {
  it('SET EBC', async () => {
    const manager = await getManagerContract();
    const ebc = await getORProtocalV1Contract();
    await manager.addEBC(ebc.address);
    //ERROR TEST
    // await userFactory.setEBC('0x0000000000000000000000000000000000000000');
    // expect(await manager.getEBC(1)).equal(ebc.address);
  });
  it('Calculate pledge quantity', async () => {
    const manager = await getManagerContract();
    const lps = DataInit.lps;
    const firstLp = lps[0];
    const [_pledgedToken, list] = await manager.calculatePledgeAmount([lps[0]]);
    // result
    const ebc = await getORProtocalV1Contract();
    // const result2 = await ebc.getPledgeAmount(100, firstLp.maxPrice);
    // expect(result2.baseValue.add(result2.additiveValue)).equal(
    //   list[0].pledgeValue,
    // );
  });
  it('SET SPV', async () => {
    const manager = await getManagerContract();
    const contract = await getORSPVContract();
    await manager.setSPV(contract.address);
  });
});
