import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish, constants } from 'ethers';
import { ethers } from 'hardhat';
import lodash from 'lodash';
import { ORManager, ORManager__factory } from '../typechain-types';
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

      const storageChainInfo = await orManager.getChainInfo(chains[i].id);
      expect(storageChainInfo.id).eq(chains[i].id);
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
    for (let i = 0; i < 10; i++) {
      tokens.push({
        decimals: i * 2,
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

  it('Function updateEbcs should succeed', async function () {
    const ebcs: string[] = [];
    const indexs: BigNumberish[] = [];
    for (let i = 0; i < 10; i++) {
      ebcs.push(ethers.Wallet.createRandom().address);
    }

    const { events } = await orManager
      .updateEbcs(ebcs, indexs)
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.ebcs).to.deep.eq(ebcs);

    const storageEbcs = await orManager.ebcs();
    expect(storageEbcs).to.deep.eq(ebcs);
  });

  it('Function updateSubmitter should succeed', async function () {
    const submitter = ethers.Wallet.createRandom().address;

    const { events } = await orManager
      .updateSubmitter(submitter)
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.submitter).to.deep.eq(submitter);

    const storageSubmitter = await orManager.submitter();
    expect(storageSubmitter).to.deep.eq(submitter);
  });

  it('Function updateProtocolFee should succeed', async function () {
    const protocolFee = 10;

    const { events } = await orManager
      .updateProtocolFee(protocolFee)
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.protocolFee).to.deep.eq(protocolFee);

    const storageProtocolFee = await orManager.protocolFee();
    expect(storageProtocolFee).to.deep.eq(protocolFee);
  });

  it('Function updateMinChallengeRatio should succeed', async function () {
    const minChallengeRatio = 20;

    const { events } = await orManager
      .updateMinChallengeRatio(minChallengeRatio)
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.minChallengeRatio).to.deep.eq(minChallengeRatio);

    const storageMinChallengeRatio = await orManager.minChallengeRatio();
    expect(storageMinChallengeRatio).to.deep.eq(minChallengeRatio);
  });

  it('Function updateChallengeUserRatio should succeed', async function () {
    const challengeUserRatio = 15;

    const { events } = await orManager
      .updateChallengeUserRatio(challengeUserRatio)
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.challengeUserRatio).to.deep.eq(challengeUserRatio);

    const storageChallengeUserRatio = await orManager.challengeUserRatio();
    expect(storageChallengeUserRatio).to.deep.eq(challengeUserRatio);
  });

  it('Function updateFeeChallengeSecond should succeed', async function () {
    const feeChallengeSecond = 25;

    const { events } = await orManager
      .updateFeeChallengeSecond(feeChallengeSecond)
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.feeChallengeSecond).to.deep.eq(feeChallengeSecond);

    const storageFeeChallengeSecond = await orManager.feeChallengeSecond();
    expect(storageFeeChallengeSecond).to.deep.eq(feeChallengeSecond);
  });

  it('Function updateFeeTakeOnChallengeSecond should succeed', async function () {
    const feeTakeOnChallengeSecond = 25;

    const { events } = await orManager
      .updateFeeTakeOnChallengeSecond(feeTakeOnChallengeSecond)
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.feeTakeOnChallengeSecond).to.deep.eq(feeTakeOnChallengeSecond);

    const storageFeeTakeOnChallengeSecond =
      await orManager.feeTakeOnChallengeSecond();
    expect(storageFeeTakeOnChallengeSecond).to.deep.eq(
      feeTakeOnChallengeSecond,
    );
  });

  it('Function updateMaxMDCLimit should succeed', async function () {
    const maxMDCLimit = BigNumber.from(2).pow(64).sub(1);

    const { events } = await orManager
      .updateMaxMDCLimit(maxMDCLimit)
      .then((t) => t.wait());

    const args = events![0].args!;
    expect(args.maxMDCLimit).to.deep.eq(maxMDCLimit);

    const storageMaxMDCLimit = await orManager.maxMDCLimit();
    expect(storageMaxMDCLimit).to.deep.eq(maxMDCLimit);
  });
});
