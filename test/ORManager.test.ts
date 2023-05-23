import { expect } from 'chai';
import lodash from 'lodash';
import {
  DataInit,
  getManagerContract,
  getORProtocalV1Contract,
  getORSPVContract,
} from './utils.test';
import { ORManager, ORManager__factory } from '../typechain-types';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Address } from 'ethereumjs-util';
import { BigNumber, BigNumberish, Wallet, constants, utils } from 'ethers';
import { OperationsLib } from '../typechain-types/contracts/ORManager';

const defaultChainInfo: OperationsLib.ChainInfoStruct = {
  id: BigNumber.from(2),
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

describe('Test ORManager', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;

  before(async function () {
    signers = await ethers.getSigners();
  });

  it('Owner should be able to be set when deploying the contract', async function () {
    orManager = await new ORManager__factory(signers[0]).deploy(
      signers[1].address,
    );
    console.log('Address of orManager contract:', orManager.address);
    await orManager.deployed();

    const owner = await orManager.owner();
    expect(owner).eq(signers[1].address);
  });

  it('Function transferOwnership should succeed', async function () {
    try {
      await orManager
        .transferOwnership(signers[0].address)
        .then((t) => t.wait());
    } catch (e: any) {
      expect(
        e.message.indexOf('Ownable: caller is not the owner') > -1,
      ).to.be.eq(true);
    }

    await orManager.connect(signers[1]).transferOwnership(signers[0].address);
  });

  it('Function registerChains should succeed', async function () {
    const chains = [
      lodash.cloneDeepWith(defaultChainInfo),
      lodash.cloneDeepWith(defaultChainInfo),
    ];

    const { events } = await orManager
      .registerChains(chains)
      .then((i) => i.wait());

    for (const i in chains) {
      const event = events![i];
      let chainInfo: OperationsLib.ChainInfoStruct = lodash.toPlainObject(
        event.args!.chainInfo,
      );

      for (const j in chainInfo.tokens) {
        expect(lodash.toPlainObject(chainInfo.tokens[j])).to.deep.includes(
          chains[i].tokens[j],
        );
      }

      // ignore tokens
      chainInfo['tokens'] = [];
      chains[i]['tokens'] = [];

      expect(lodash.toPlainObject(chainInfo)).to.deep.includes(chains[i]);

      const respChainInfo = await orManager.getChainInfo(chains[i].id);
      expect(respChainInfo.id).eq(chains[i].id);
    }
  });

  it('Function updateChainSpvs should succeed', async function () {
    const chainId = defaultChainInfo.id;

    const spvs: string[] = [];
    const indexs: BigNumberish[] = [BigNumber.from(0)];
    for (let i = 0; i < 10; i++) {
      spvs.push(ethers.Wallet.createRandom().address);
    }

    const { events } = await orManager
      .updateChainSpvs(chainId, spvs, indexs)
      .then((t) => t.wait());

    expect(events![0].args!.id).eq(chainId);
    expect(events![0].args!.chainInfo.spvs).deep.eq(spvs);
  });

  it('Function updateChainTokens should succeed', async function () {
    const chainId = defaultChainInfo.id;

    const tokens: OperationsLib.TokenInfoStruct[] = [];
    const indexs: BigNumberish[] = [BigNumber.from(0)];
    for (let i = 0; i < 5; i++) {
      tokens.push({
        decimals: 6,
        token: BigNumber.from(ethers.Wallet.createRandom().address).add(0), // add(0), convert _hex uppercase to lowercase
        mainnetToken: constants.AddressZero,
      });
    }

    const { events } = await orManager
      .updateChainTokens(chainId, tokens, indexs)
      .then((t) => t.wait());

    const args = events![0].args!;

    expect(args.id).eq(chainId);
    for (const i in args.chainInfo.tokens) {
      expect(lodash.toPlainObject(args.chainInfo.tokens[i])).to.deep.includes(
        tokens[Number(i)],
      );
    }
  });

  // it('initChain', async () => {
  //   const contract = await getManagerContract();
  //   const chains = DataInit.chains;
  //   const addTokensData: any[] = [];
  //   const addChainsData = chains.map((chain) => {
  //     for (const token of chain.tokenList) {
  //       addTokensData.push(
  //         contract.interface.encodeFunctionData('registerToken', [
  //           chain.id,
  //           token.decimals,
  //           token.address,
  //           token.pledgeToken,
  //         ]),
  //       );
  //     }
  //     return contract.interface.encodeFunctionData('registerChain', [
  //       chain.id,
  //       chain.batchLimit,
  //       chain.maxDisputeTime,
  //       chain.maxReceiptTime,
  //       chain.stopDelayTime,
  //       chain.maxBits,
  //     ]);
  //   });
  //   await contract.multicall(addChainsData);
  //   await contract.multicall(addTokensData);
  // });
  // it('init Pairs', async () => {
  //   const contract = await getManagerContract();
  //   const pairs = DataInit.pairs;
  //   const addPair1 = await contract.registerPair(pairs[0]);
  //   await addPair1.wait();
  //   const datas = pairs.map((row) => {
  //     return contract.interface.encodeFunctionData('registerPair', [row]);
  //   });
  //   const tx = await contract.multicall(datas);
  //   await tx.wait();
  //   // const pairIds = await contract.getPairIds();
  //   // expect(pairIds.length).eq(datas.length);
  //   for (const pairId of pairs.map(row=> row.id)) {
  //     const pair = await contract.getPairs(pairId);
  //     const localPair = pairs.find((p) => p.id === pairId);
  //     console.log(localPair, '==', pair)
  //     expect(localPair).not.empty;
  //     expect(pair).not.empty;
  //     expect(pair.sourceChain).eq(localPair.sourceChain);
  //     expect(pair.destChain).eq(localPair.destChain);
  //     expect(pair.sourceToken).eq(localPair.sourceToken);
  //     expect(pair.ebcId).eq(localPair.ebcId);
  //   }
  // });
  // it('Delete Pair (Not Exists)', async () => {
  //   const contract = await getManagerContract();
  //   const response = contract.deletePair(
  //     '0xafee4ad1a2d0f54fdfde4a5f259c9d035b0ed39a8f615477f59c021ac2a274ad',
  //   );
  //   await expect(response).to.be.revertedWith('ID does not exist');
  // });
  // it('Delete Pair (Exists)', async () => {
  //   const contract = await getManagerContract();
  //   const pairs = DataInit.pairs;
  //   const pairId = pairs[0].id;
  //   const response = await contract.deletePair(pairId);
  //   const isSupport = await contract.isExistsPair(pairId);
  //   await expect(isSupport).false;
  //   const pairInfo = await contract.getPairs(pairId);
  //   await expect(pairInfo.sourceChain).eq(0);
  //   await expect(pairInfo.destChain).eq(0);
  // });
  // it('Add deleted Pair', async () => {
  //   const contract = await getManagerContract();
  //   const pairs = DataInit.pairs;
  //   const pairId = pairs[0].id;
  //   await contract.registerPair(pairs[0]);
  //   const isSupport = await contract.isExistsPair(pairId);
  //   await expect(isSupport).true;
  // });

  // it('Check Chain Field Value', async () => {
  //   const chains = DataInit.chains;
  //   const manager = await getManagerContract();
  //   for (const chain of chains) {
  //     const {
  //       id,
  //       chainID,
  //       batchLimit,
  //       maxDisputeTime,
  //       maxReceiptTime,
  //       tokenList,
  //     } = chain;
  //     const chainRes = await manager.getChain(id);
  //     expect(chainRes.chainId).equal(chainID);
  //     expect(chainRes.batchLimit).equal(batchLimit);
  //     expect(chainRes.maxDisputeTime).equal(maxDisputeTime);
  //     expect(chainRes.maxReceiptTime).equal(maxReceiptTime);
  //     for (const tokenItem of tokenList) {
  //       const token = await manager.getTokenInfo(id, tokenItem.address);
  //       expect(token.tokenAddress.toLowerCase()).equal(
  //         String(tokenItem.address).toLowerCase(),
  //       );
  //       expect(token.decimals).equal(tokenItem.decimals);
  //       expect(token.mainTokenAddress).equal(tokenItem.pledgeToken);
  //       expect(token.chainID).equal(id);
  //     }
  //   }
  // });
  // it('Manager Change Chain batchLimit', async () => {
  //   const chains = DataInit.chains;
  //   const manager = await getManagerContract();
  //   const {
  //     id,
  //     batchLimit,
  //     stopDelayTime,
  //     maxDisputeTime,
  //     maxReceiptTime,
  //     maxBits,
  //   } = chains[0];
  //   await manager.registerChain(
  //       id,
  //       batchLimit * 2,
  //       maxDisputeTime,
  //       maxReceiptTime,
  //       stopDelayTime,
  //       maxBits,
  //     )
  //     .then(async (tx) => {
  //       await tx.wait();
  //       expect((await manager.getChain(id)).batchLimit).equal(batchLimit * 2);
  //     });
  // });
  // it('isSupportChain Token', async () => {
  //   const chains = DataInit.chains;
  //   const manager = await getManagerContract();
  //   const { id } = chains[0];
  //   let tokenInfo = await manager.getTokenInfo(
  //     id,
  //     '0x0000000000000000000000000000000000000000',
  //   );
  //   expect(tokenInfo.chainID).gt(0);
  //   tokenInfo = await manager.getTokenInfo(
  //     id,
  //     '0x0000000000000000000000000000000000000001',
  //   );
  //   expect(tokenInfo.chainID).eq(0);
  // });
  // it('Manager Change Token tokenPresion', async () => {
  //   const manager = await getManagerContract();
  //   const chains = DataInit.chains;
  //   const { id, tokenList } = chains[0];
  //   const { address, decimals, pledgeToken } = tokenList[0];
  //   await manager
  //     .registerToken(
  //       id,
  //       decimals,
  //       address,
  //       '0x0000000000000000000000000000000000000001',
  //     )
  //     .then(async (tx) => {
  //       await tx.wait();
  //       const contractToken = await manager.getTokenInfo(id, address);
  //       expect(contractToken.mainTokenAddress).equal(
  //         '0x0000000000000000000000000000000000000001',
  //       );
  //     });

  //   await manager
  //     .registerToken(id, decimals, address, pledgeToken)
  //     .then(async (tx) => {
  //       await tx.wait();
  //       const contractToken = await manager.getTokenInfo(id, address);
  //       expect(contractToken.mainTokenAddress).equal(pledgeToken);
  //     });
  // });
});
// describe('Manager EBC', () => {
//   it('SET EBC', async () => {
//     const manager = await getManagerContract();
//     const ebc = await getORProtocalV1Contract();
//     await manager.registerEBC(ebc.address);
//     //ERROR TEST
//     // await userFactory.setEBC('0x0000000000000000000000000000000000000000');
//     // expect(await manager.getEBC(1)).equal(ebc.address);
//   });
//   it('Calculate pledge quantity', async () => {
//     const manager = await getManagerContract();
//     const lps = DataInit.lps;
//     const result = await manager.calculatePairPledgeAmount(lps);
//     console.log('calculatePairPledgeAmount:', result);
//     // result
//     // const ebc = await getORProtocalV1Contract();
//     // const result2 = await ebc.getPledgeAmount(100, firstLp.maxPrice);
//     // expect(result2.baseValue.add(result2.additiveValue)).equal(
//     //   list[0].pledgeValue,
//     // );
//   });
//   it('SET SPV', async () => {
//     const manager = await getManagerContract();
//     const contract = await getORSPVContract();
//     await manager.registerSPV(1, contract.address);
//   });
// });
