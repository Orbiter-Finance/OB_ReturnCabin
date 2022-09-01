import { ethers } from 'hardhat';
import { ORMakerDeposit } from '../typechain-types/contracts/ORMakerDeposit';
import { MerkleTree } from 'merkletreejs';
import { LP_LIST } from './lib/Config';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { PAIR_LIST } from './lib/Config';
let mdc: ORMakerDeposit;
let supportPairTree: MerkleTree;
let owner: SignerWithAddress;
let lpInfoTree: MerkleTree;
const { keccak256 } = ethers.utils;
describe('MakerDeposit.test.ts', () => {
  async function getFactoryInfo() {
    const mdcContractAddress =
      process.env['MDC'] || '0xc8b335273449ec29644c5433cec7383ca4d2ea62';
    [owner] = await ethers.getSigners();
    mdc = await ethers.getContractAt(
      'ORMakerDeposit',
      mdcContractAddress,
      owner,
    );
    console.log('MDC Address：', mdc.address);
    // tree
    const pairLefs = PAIR_LIST.map((row) => {
      return Buffer.from(String(row.id), 'hex');
    });
    supportPairTree = new MerkleTree(pairLefs, keccak256, {
      sort: true,
    });
    lpInfoTree = new MerkleTree([], keccak256, {
      sort: true,
    });
  }

  before(getFactoryInfo);

  it('LPAction Pledge ETH', async () => {
    // const value = ethers.utils.parseEther('2');
    lpInfoTree.addLeaf(Buffer.from(LP_LIST[0].id, 'hex'));
    lpInfoTree.addLeaf(Buffer.from(LP_LIST[1].id, 'hex'));
    // const lpId = getPairID(lpInfo);
    // const pairProof = supportPairTree.getHexProof(lpId);
    // OperationsLib.LpInfoStruct;
    // const response = await mdc.LPAction();
  });
  //   const lpInfo = lpInfoList[0];
  //   console.log(lpInfo);
  //   const lpId = getLpID(lpInfo);
  //   const proof = supportPairTree.getHexProof(lpId);
  //   const value = ethers.utils.parseEther('2');
  //   const overrides = {
  //     value,
  //   };
  //   const response = await mdc.LPAction(
  //     value,
  //     <any>lpInfo,
  //     proof,
  //     supportPairTree.getHexRoot(),
  //     overrides,
  //   );
  //   await expect(response)
  //     .to.emit(mdc, 'LogLpInfo')
  //     .withArgs(lpId, 0, anyValue, anyValue);
  //   const chainDeposit = await mdc.chainDeposit(
  //     lpInfo.sourceChain,
  //     lpInfo.sourceTAddress,
  //   );
  //   expect(chainDeposit.useLimit).equal(ethers.BigNumber.from(1));
  //   expect(chainDeposit.tokenAddress).equal(lpInfo.sourceTAddress);
  //   // const needDepositAmount = lpInfo.batchLimit * _lpinfo.maxPrice;
  //   console.log(chainDeposit, '==chainDeposit');
  //   const result2 = await mdc.usedDeposit(owner.address);
  //   console.log(result2, '==user usedDeposit');
  //   const contractBalance = await web3.eth.getBalance(mdc.address);
  //   console.log('contractBalance:', contractBalance);
  //   expect(chainDeposit.tokenAddress).equal(lpInfo.sourceTAddress);
  //   // console.log(response, '==response---', tx);
  // });
  // it('LPAction Pledge ETH Mainnet-ZkSync', async () => {
  //   const lpInfo = lpInfoList[1];
  //   console.log(lpInfo);
  //   const lpId = getLpID(lpInfo);
  //   const proof = supportPairTree.getHexProof(lpId);
  //   const value = ethers.utils.parseEther('1');
  //   const overrides = {
  //     value,
  //   };
  //   const response = await mdc.LPAction(
  //     value,
  //     <any>lpInfo,
  //     proof,
  //     supportPairTree.getHexRoot(),
  //     overrides,
  //   );
  //   await expect(response)
  //     .to.emit(mdc, 'LogLpInfo')
  //     .withArgs(lpId, 0, anyValue, anyValue);
  //   const chainDeposit = await mdc.chainDeposit(
  //     lpInfo.sourceChain,
  //     lpInfo.sourceTAddress,
  //   );

  //   expect(chainDeposit.useLimit).equal(ethers.BigNumber.from(2));
  //   expect(chainDeposit.tokenAddress).equal(lpInfo.sourceTAddress);
  // });
});
