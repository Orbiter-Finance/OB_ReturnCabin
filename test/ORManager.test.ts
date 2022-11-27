import { expect } from 'chai';
import keccak256 from 'keccak256';
import { orderBy } from 'lodash';
import MerkleTree from 'merkletreejs';
import { printSuccess } from '../scripts/utils';
import {
  DataInit,
  getManagerContract,
  getORProtocalV1Contract,
} from './index.test';
const { chains, pairs } = new DataInit();
async function initChain() {
  const contract = await getManagerContract();
  for (const chain of chains) {
    const tokenList = chain.tokenList.map((row: any) => row.address);
    const tx = await contract.setChainInfo(
      chain.chainID,
      chain.batchLimit,
      chain.maxDisputeTime,
      chain.maxReceiptTime,
      tokenList,
    );
    printSuccess(`Add Chain ${chain.chainID} Hash: ${tx.hash}`);
    for (const token of chain.tokenList) {
      const tx = await contract.setTokenInfo(
        chain.chainID,
        token.address,
        token.decimals,
        token.pledgeToken,
      );
      printSuccess(
        `Add Chain Token ${token.symbol} ${chain.chainID} Token:${token.address} Hash: `,
        tx.hash,
      );
    }
  }
}
export function getPairTree() {
  const newPairs = pairs;
  const pairTree = new MerkleTree(
    newPairs.map((row: any) => row.id),
    keccak256,
    {
      sort: true,
    },
  );
  const sortAfter = orderBy(newPairs, ['id'], ['asc']);
  return { tree: pairTree, datas: sortAfter };
}
async function initPair() {
  const contract = await getManagerContract();
  const { tree, datas } = getPairTree();
  const leaves = tree.getLeaves();
  const proof = tree.getMultiProof(leaves);
  const proofFlag = tree.getProofFlags(leaves, proof);
  const tx = await contract.createPair(
    datas,
    tree.getHexRoot(),
    proof,
    proofFlag,
  );
  printSuccess(`Multiple CreatePair Hash:${tx.hash}`);
}

describe('ORManager.test.ts => Chain', () => {
  it('Init Contract', async () => {
    const manager = await getManagerContract();
    expect(manager).not.empty;
  });
  it('initChain', async () => {
    await initChain();
  });
  it('Check Chain Field Value', async () => {
    const manager = await getManagerContract();
    for (const chain of chains) {
      const { chainID, batchLimit, maxDisputeTime, maxReceiptTime, tokenList } =
        chain;
      const chainRes = await manager.chainList(chainID);

      expect(chainRes.isUsed).true;
      expect(chainRes.chainid).equal(chainID);
      expect(chainRes.batchLimit).equal(batchLimit);
      expect(chainRes.maxDisputeTime).equal(maxDisputeTime);
      expect(chainRes.maxReceiptTime).equal(maxReceiptTime);
      for (const tokenItem of tokenList) {
        const token = await manager.getTokenInfo(chainID, tokenItem.address);
        expect(token.tokenAddress).equal(tokenItem.address);
        expect(token.tokenPresion).equal(tokenItem.decimals);
        expect(token.mainTokenAddress).equal(tokenItem.pledgeToken);
        expect(token.chainID).equal(chainID);
      }
    }
  });
  it('Manager Change Chain batchLimit', async () => {
    const manager = await getManagerContract();
    const { chainID, batchLimit, maxDisputeTime, maxReceiptTime, tokenList } =
      chains[0];
    const tokenAddressList = tokenList.map((row: any) => row.address);
    await manager.setChainInfo(
      chainID,
      batchLimit * 2,
      maxDisputeTime,
      maxReceiptTime,
      tokenAddressList,
    );
    expect((await manager.chainList(chainID)).batchLimit).equal(batchLimit * 2);
  });
  it('Manager Change Token tokenPresion', async () => {
    const manager = await getManagerContract();
    const { chainID, tokenList } = chains[0];
    const { address, decimals, pledgeToken } = tokenList[0];
    await manager.setTokenInfo(
      chainID,
      address,
      decimals,
      '0x0000000000000000000000000000000000000001',
    );
    let contractToken = await manager.getTokenInfo(chainID, address);
    expect(contractToken.mainTokenAddress).equal(
      '0x0000000000000000000000000000000000000001',
    );
    await manager.setTokenInfo(chainID, address, decimals, pledgeToken);
    contractToken = await manager.getTokenInfo(chainID, address);
    expect(contractToken.mainTokenAddress).equal(pledgeToken);
  });
});
describe('ORManager.test.ts => Pair', () => {
  it('initPair', async () => {
    await initPair();
  });

  it('Check Pair Root Hash', async () => {
    const manager = await getManagerContract();
    const { tree } = getPairTree();
    const pairsRoot = await manager.pairsRoot();
    expect(pairsRoot).equal(tree.getHexRoot());
  });
});

describe('Manager EBC', () => {
  it('SET EBC', async () => {
    const manager = await getManagerContract();
    const ebc = await getORProtocalV1Contract();
    await manager.setEBC(ebc.address);
    //ERROR TEST
    // await userFactory.setEBC('0x0000000000000000000000000000000000000000');
    expect(await manager.getEBC(1)).equal(ebc.address);
  });
});
