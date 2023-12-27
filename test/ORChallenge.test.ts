import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { BigNumber, BigNumberish, Wallet, constants, utils } from 'ethers';
import { ethers } from 'hardhat';
import fs from 'fs';

import {
  BytesLike,
  RLP,
  arrayify,
  defaultAbiCoder,
  keccak256,
  solidityPack,
} from 'ethers/lib/utils';
import lodash, { get, random } from 'lodash';
import { BaseTrie } from 'merkle-patricia-tree';
import {
  OREventBinding,
  OREventBinding__factory,
  ORMDCFactory,
  ORMDCFactory__factory,
  ORMakerDeposit,
  ORMakerDeposit__factory,
  ORManager,
  ORManager__factory,
  TestSpv,
  TestSpv__factory,
  TestToken,
  TestToken__factory,
  ORChallengeSpvMainnet2Era,
  ORChallengeSpvMainnet2Era__factory,
  TestMakerDeposit,
  TestMakerDeposit__factory,
  RLPDecoder,
  RLPDecoder__factory,
  ORSpvData__factory,
  ORChallengeSpvEra2Mainnet,
  ORChallengeSpvEra2Mainnet__factory,
  ORSpvData,
} from '../typechain-types';
import { defaultChainInfo } from './defaults';
import {
  RuleStruct,
  calculateRuleKey,
  calculateRulesTree,
  converRule,
  createMakerRule,
  createRandomRule,
  encodeChallengeRawData,
  formatRule,
  getRulesRootUpdatedLogs,
} from './lib/rule';
import {
  challengeInputInfo,
  columnArray,
  embedVersionIncreaseAndEnableTime,
  getEffectiveEbcsFromLogs,
  getMinEnableTime,
  hexToBuffer,
  testReverted,
  testRevertedOwner,
  createChallenge,
  getSecurityCode,
  getVerifyinfo,
  updateSpv,
  VerifyinfoBase,
  calculateTxGas,
  challengeManager,
  liquidateChallenge,
  PublicInputData,
  updateMakerRule,
  PublicInputDataDest,
  VerifiedDataInfo,
  getRLPEncodeMakerRuleHash,
  getRawDataNew,
  mockSpvData,
} from './utils.test';
import {
  callDataCost,
  chainIdsMock,
  dealersMock,
  defaultChainInfoArray,
  defaultResponseTime,
  getCurrentTime,
  mineXTimes,
} from './lib/mockData';
import { PromiseOrValue } from '../typechain-types/common';
import { randomBytes } from 'crypto';
import {
  compile_yul,
  createRandomChallenge,
  deployContracts,
  deployMDC,
  deploySPVs,
  getSpvProof,
  SPVTypeEnum,
  VerifierAbi,
} from '../scripts/utils';
import { Console } from 'console';
import { deploy } from '../scripts/deploy';
import exp from 'constants';

describe('start challenge & liquidaion test module', () => {
  let spvTest: TestSpv;
  let mainnet2eraSpv: ORChallengeSpvMainnet2Era;
  let era2mainnetSpv: ORChallengeSpvEra2Mainnet;
  let makerTest: TestMakerDeposit;
  let rlpDecoder: RLPDecoder;
  let spvData: ORSpvData;
  let orManager: ORManager;
  let ebc: OREventBinding;
  let signers: SignerWithAddress[];
  let deployer: SignerWithAddress;
  let mdcOwner: SignerWithAddress;
  let makerRuleSourceChain: BigNumber;
  let makerRuleDestChain: BigNumber;
  let mdc_test_impl: TestMakerDeposit;
  const defaultRule = createMakerRule(true);
  const makerRule: RuleStruct = {
    ...defaultRule,
    token0: BigNumber.from(constants.AddressZero),
    token1: BigNumber.from(constants.AddressZero),
    minPrice0: BigNumber.from(ethers.utils.parseEther('1')),
    minPrice1: BigNumber.from(ethers.utils.parseEther('1')),
    maxPrice0: BigNumber.from(ethers.utils.parseEther('5')),
    maxPrice1: BigNumber.from(ethers.utils.parseEther('5')),
    chainId0: BigNumber.from(300),
    chainId1: BigNumber.from(11155111),
    withholdingFee0: BigNumber.from('3' + '0'.repeat(5)),
    withholdingFee1: BigNumber.from('4' + '0'.repeat(5)),
    responseTime0: defaultResponseTime,
    responseTime1: defaultResponseTime,
  };
  const chainId = makerRule.chainId0;
  const chainIdDest = makerRule.chainId1;

  const m2eSourceProof: BytesLike = getSpvProof().verifySourceProof;
  const m2eDestProof: BytesLike = getSpvProof().verifyDestProof;

  const e2mSourceProof: BytesLike = getSpvProof(
    SPVTypeEnum.era2mainnet,
  ).verifySourceProof;

  const e2mDestProof: BytesLike = getSpvProof(
    SPVTypeEnum.era2mainnet,
  ).verifyDestProof;

  const getRawData = async (
    columnArray: columnArray,
    ebc: string,
    makerRule: RuleStruct,
  ) => {
    const jsEncode = encodeChallengeRawData(
      columnArray.dealers,
      columnArray.ebcs,
      columnArray.chainIds,
      ebc,
      makerRule,
    );

    const contractEncode = await spvTest.encodeRawDatas(
      columnArray.dealers,
      columnArray.ebcs,
      columnArray.chainIds,
      ebc,
      makerRule,
    );

    expect(jsEncode).eql(contractEncode);

    {
      const { dealers, ebcs, chainIds, ebc, rule } =
        await spvTest.decodeRawDatas(utils.arrayify(jsEncode));
      expect(dealers).eql(columnArray.dealers);
      expect(ebcs).eql(columnArray.ebcs);
      expect(chainIds.toString()).eql(columnArray.chainIds.toString());
      expect(rule.chainId0).eql(makerRule.chainId0);
      expect(rule.chainId1).eql(makerRule.chainId1);
      expect(rule.status0).eql(makerRule.status0);
      expect(rule.status1).eql(makerRule.status1);
    }
    const columnArrayHash = utils.keccak256(
      utils.defaultAbiCoder.encode(
        ['uint256[]', 'uint256[]', 'uint256[]'],
        [columnArray.dealers, columnArray.ebcs, columnArray.chainIds],
      ),
    );

    return {
      rawData: utils.arrayify(contractEncode),
      columnArrayHash: columnArrayHash,
    };
  };

  before(async function () {
    signers = await ethers.getSigners();
    deployer = signers[0];
    mdcOwner = signers[1];

    makerRuleSourceChain = makerRule.chainId1;
    makerRuleDestChain = makerRule.chainId0;

    await deployContracts(signers[0], true);
    const envEBCAddress = process.env['EVENT_BINDING_CONTRACT'];
    // const envMDCAddress = process.env['OR_MDC'];
    const envMDCTestAddress = process.env['OR_MDC_TEST'];
    const envRLPDecoderAddress = process.env['RLP_DECODER_ADDRESS'];
    const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
    const envSPVTestAddress = process.env['SPV_TEST_ADDRESS'];
    const envSPVAddress = process.env['SPV_ADDRESS'];
    const envSPVEraAddress = process.env['SPV_ADDRESS_ERA'];
    const envSPVDataAddress = process.env['OR_SPV_DATA_ADRESS'];
    const makerTest_impl = process.env['OR_MDC_TEST_IMPL'];
    assert(
      !!envMDCTestAddress &&
        !!envEBCAddress &&
        !!envRLPDecoderAddress &&
        !!envORManagerAddress &&
        !!envSPVTestAddress &&
        !!envSPVEraAddress &&
        !!envSPVDataAddress &&
        !!makerTest_impl &&
        !!envSPVAddress,
      'Env miss [something].',
    );

    mainnet2eraSpv = new ORChallengeSpvMainnet2Era__factory(deployer).attach(
      envSPVAddress,
    );
    console.log('connect of mainnet2eraSpv:', mainnet2eraSpv.address);

    era2mainnetSpv = new ORChallengeSpvEra2Mainnet__factory(deployer).attach(
      envSPVEraAddress,
    );
    console.log('connect of era2mainnetSpv:', era2mainnetSpv.address);
    spvTest = new TestSpv__factory(deployer).attach(envSPVTestAddress);
    console.log('connect of spvTest:', spvTest.address);

    rlpDecoder = new RLPDecoder__factory(deployer).attach(envRLPDecoderAddress);
    console.log('connect of rlpDecoder:', rlpDecoder.address);

    makerTest = new TestMakerDeposit__factory(deployer).attach(
      envMDCTestAddress,
    );
    console.log('connect of makerTest:', makerTest.address);

    spvData = new ORSpvData__factory(deployer).attach(envSPVDataAddress);
    console.log('connect of spvData:', spvData.address);

    orManager = new ORManager__factory(deployer).attach(envORManagerAddress);
    console.log('connect of orManager:', orManager.address);

    ebc = new OREventBinding__factory(deployer).attach(envEBCAddress);
    console.log('connect of ebc:', ebc.address);

    mdc_test_impl = new TestMakerDeposit__factory(deployer).attach(
      makerTest_impl,
    );
    console.log('connect of mdc_test_impl:', mdc_test_impl.address);
  });

  const skipGasCostTest = false;
  it('calculate spv verify gas cost', async function () {
    if (!skipGasCostTest) {
      expect(await mainnet2eraSpv.owner()).eq(deployer.address);
      expect(await era2mainnetSpv.owner()).eq(deployer.address);

      const paresSourcePoorf: boolean = false;
      const pareseDestProof: boolean = false;
      const tx = await mainnet2eraSpv
        .verifySourceTx(m2eSourceProof)
        .then((t: any) => t.wait());
      expect(tx.status).to.be.eq(1);
      expect(
        await spvTest.verifySourceTx(m2eSourceProof, mainnet2eraSpv.address),
      ).to.satisfy;
      console.log('mainnet2era sourceProof verify Pass');
      await calculateTxGas(tx, 'spvVerifySourceTx');
      if (paresSourcePoorf) {
        console.log(
          'era2mainnet, paresSourcePoorf',
          await era2mainnetSpv.parseSourceTxProof(e2mSourceProof),
        );
      }
      expect(
        await spvTest.verifySourceTx(e2mSourceProof, era2mainnetSpv.address),
      ).to.satisfy;
      console.log('era2mainnet sourceProof verify Pass');
      const txDest = await mainnet2eraSpv
        .verifyDestTx(m2eDestProof)
        .then((t: any) => t.wait());
      expect(txDest.status).to.be.eq(1);
      expect(await spvTest.verifyDestTx(m2eDestProof, mainnet2eraSpv.address))
        .to.satisfy;
      console.log('mainnet2era destProof verify Pass');
      // await calculateTxGas(txDest, 'spvVerifyDestTx');

      if (pareseDestProof) {
        console.log(
          'era2mainnet, pareseDestProof',
          await era2mainnetSpv.parseDestTxProof(e2mDestProof),
        );
      }
      expect(await spvTest.verifyDestTx(e2mDestProof, era2mainnetSpv.address))
        .to.satisfy;
      console.log('era2mainnet destProof verify Pass');
    }
  });

  it('Challenge and verifySourceTx', async function () {
    const victim = signers[signers.length - 1];
    const challengerRatio100 = 1000000; // 1000000 = 100%
    const challengerRatio = 300000;
    console.log('victim:', victim.address);
    const amount = utils.parseEther('10');
    await deployer.sendTransaction({
      to: makerTest.address,
      value: amount,
    });

    const columnArray = {
      dealers: [mdcOwner.address],
      ebcs: [process.env['EVENT_BINDING_CONTRACT']!],
      chainIds: [5, 420, 280, 300, 11155111],
    };
    await orManager
      .updateSpvDataContract(spvData.address)
      .then((t) => t.wait());
    await orManager
      .updateSpvDataInjectOwner(deployer.address)
      .then((t) => t.wait());

    await orManager.updatePriorityFee(1);

    challengeManager.initialize();

    let defaultRule: BigNumberish[] = [
      300,
      11155111,
      1,
      1,
      0,
      0,
      20000000000,
      20000000000,
      BigNumber.from('100000000000000000000'),
      BigNumber.from('100000000000000000000'),
      10000000,
      20000000,
      1,
      1,
      604800,
      604800,
      42,
      49,
    ];
    const formatDefaultRule = formatRule(defaultRule);
    await updateMakerRule(makerTest, ebc.address, makerRule);
    await orManager.updateDecoderAddress(rlpDecoder.address);
    expect(await orManager.getRulesDecoder()).eq(rlpDecoder.address);
    const publicInputData: PublicInputData =
      await mainnet2eraSpv.parseSourceTxProof(m2eSourceProof);

    const publicInputDataDest: PublicInputDataDest =
      await mainnet2eraSpv.parseDestTxProof(m2eDestProof);

    await mockSpvData(
      spvData,
      Array.from(
        new Set(
          publicInputDataDest.merkle_roots.concat(publicInputData.merkle_roots),
        ),
      ),
    );

    // {
    //   const { encodeHash } = getRLPEncodeMakerRuleHash(defaultRule);
    //   expect(publicInputData).not.null;
    //   expect(encodeHash).eql(publicInputData.mdc_current_rule_value_hash);
    // }

    const challengeColumnArray: columnArray = {
      ...columnArray,
      dealers: [mdcOwner.address],
      ebcs: [ebc.address],
    };

    const verifyTimeMax =
      utils.hexZeroPad(BigNumber.from(9999999).toHexString(), 8) +
      utils.hexZeroPad('0x00', 8).slice(2) +
      utils.hexZeroPad(BigNumber.from(8888888).toHexString(), 8).slice(2) +
      utils.hexZeroPad('0x00', 8).slice(2);

    const { rawData, columnArrayHash } = await getRawDataNew(
      challengeColumnArray,
      ebc.address,
    );

    const price = makerRule.minPrice0.mul(3).toString().slice(0, -5);
    const victimLostAmount =
      price +
      getSecurityCode(
        challengeColumnArray,
        ebc.address,
        mdcOwner.address,
        parseInt(makerRuleDestChain.toString()),
      );
    console.log('victimLostAmount', utils.formatEther(victimLostAmount));

    const verifyinfoBase: VerifyinfoBase = {
      chainIdSource: makerRuleSourceChain,
      freeTokenSource: makerRule.token0.toHexString(),
      chainIdDest: makerRuleDestChain,
      freeTokenDest: makerRule.token1.toHexString(),
      ebc: ebc.address,
    };

    // get related slots & values of maker/manager contract
    const verifyInfo = await getVerifyinfo(
      makerTest,
      orManager,
      verifyinfoBase,
    );
    // default rule not work in uint test , replace with new rule
    const { rlpRawdata, encodeHash } = getRLPEncodeMakerRuleHash(
      converRule(makerRule),
    );
    const RLPDecodeRule: RuleStruct = await rlpDecoder.decodeRule(rlpRawdata);
    expect(converRule(RLPDecodeRule)).deep.equals(converRule(makerRule));
    const defaultRessponseMakers = mdcOwner.address;
    const responseMakersEncodeRaw = await spvTest.encodeResponseMakers([
      defaultRessponseMakers,
    ]);
    const responseMakersHash = keccak256(responseMakersEncodeRaw);

    const makerPublicInputData: PublicInputData = {
      // with replace reason
      ...publicInputData,
      from: victim.address,
      to: signers[0].address,
      mdc_contract_address: makerTest.address, // mdc not same
      manage_contract_address: orManager.address, // manager not same
      max_verify_challenge_dest_tx_second:
        BigNumber.from(99999999999999).toHexString(), // max verify time too small
      max_verify_challenge_src_tx_second:
        BigNumber.from(99999999999999).toHexString(), // max verify time too small
      min_verify_challenge_dest_tx_second: BigNumber.from(0).toHexString(), // min verify time too long
      min_verify_challenge_src_tx_second: BigNumber.from(0).toHexString(), // min verify time too long
      mdc_current_column_array_hash: columnArrayHash, // dealer & ebc not same
      amount: BigNumber.from(victimLostAmount), // security code base on ebc & dealer, they both changed
      mdc_rule_root_slot: verifyInfo.slots[6].key, // ebc not same
      mdc_rule_version_slot: verifyInfo.slots[7].key, // ebc not same
      // mdc_column_array_hash_slot: verifyInfo.slots[3].key,
      // mdc_response_makers_hash_slot: verifyInfo.slots[5].key,
      mdc_current_rule_value_hash: encodeHash, // rule not compatible
      mdc_current_response_makers_hash: responseMakersHash, // response maker not same
      manage_current_challenge_user_ratio: challengerRatio,
      // mdc_next_rule_enable_time: publicInputData.mdc_current_rule_enable_time,
    };

    // console.log('makerPublicInputData', makerPublicInputData);

    const rulesKey = calculateRuleKey(converRule(makerRule));
    const encodeRuleKey = utils.solidityPack(
      ['uint256', 'uint256', 'uint256', 'uint256'],
      [
        makerRule.chainId0,
        makerRule.chainId1,
        makerRule.token0,
        makerRule.token1,
      ],
    );
    const ruleKey = utils.keccak256(encodeRuleKey);
    expect(ruleKey).eq(rulesKey);

    const challenge: challengeInputInfo = {
      sourceTxTime: BigNumber.from(makerPublicInputData.time_stamp).toNumber(),
      sourceChainId: BigNumber.from(makerPublicInputData.chain_id).toNumber(),
      destChainId: BigNumber.from(makerRuleDestChain).toNumber(),
      sourceBlockNum: BigNumber.from(0).toNumber(),
      sourceTxIndex: BigNumber.from(makerPublicInputData.index).toNumber(),
      sourceTxHash: utils.hexZeroPad(
        BigNumber.from(makerPublicInputData.tx_hash).toHexString(),
        32,
      ),
      from: BigNumber.from(makerPublicInputData.from).toHexString(),
      freezeToken: makerPublicInputData.token,
      freezeAmount: BigNumber.from(makerPublicInputData.amount).mul(2),
      parentNodeNumOfTargetNode: 0,
    };
    // mainnet2eraSpv should be setting by manager
    await updateSpv(
      BigNumber.from(challenge.sourceChainId).toNumber(),
      mainnet2eraSpv.address,
      orManager,
    );
    const challengerList: SignerWithAddress[] = [
      signers[0],
      signers[1],
      signers[2],
      signers[3],
      signers[4],
      signers[5],
    ];
    const mdcBalanceBeforeCreateChallenge = await ethers.provider.getBalance(
      makerTest.address,
    );

    console.log(
      'mdcBalanceBeforeCreateChallenge',
      utils.formatEther(mdcBalanceBeforeCreateChallenge),
    );
    let freezeAmountTotal: BigNumberish = BigNumber.from(0);
    let minDeposit = utils.parseEther('0.005');
    const gasUsedList: BigNumber[] = [];

    const $_BeforeAll: BigNumber[] = await Promise.all(
      challengerList.map((challenger) =>
        ethers.provider
          .getBalance(challenger.address)
          .then((balance) => balance),
      ),
    );
    console.log(
      '$_BeforeAll',
      $_BeforeAll.map((b) => utils.formatEther(b)),
    );

    const victimBalanceBeforeChallenge = await ethers.provider.getBalance(
      victim.address,
    );

    let freezeAmountMDC: BigNumberish = BigNumber.from(0);

    for (const challenger of challengerList) {
      let challengeInfo: challengeInputInfo = challenge;
      if (
        challengerList.indexOf(challenger) === 2 ||
        challengerList.indexOf(challenger) === 3
      ) {
        challengeInfo = {
          ...challengeInfo,
          freezeAmount: BigNumber.from(challengeInfo.freezeAmount).add(
            challengerList.indexOf(challenger),
          ),
        };
      }
      const makerTestChallenge = new TestMakerDeposit__factory(
        challenger,
      ).attach(makerTest.address);
      gasUsedList.push(
        BigNumber.from(
          (
            await createChallenge(
              makerTestChallenge,
              challengeInfo,
              converRule(makerRule),
            )
          ).transactionfee,
        ),
      );
      freezeAmountTotal = freezeAmountTotal
        .add(minDeposit)
        .add(challengeInfo.freezeAmount);

      freezeAmountMDC = freezeAmountMDC
        .add(BigNumber.from(challengeInfo.freezeAmount).mul(2))
        .add(minDeposit);
    }

    const freezeTokenBefore = await makerTest.freezeAssets(
      constants.AddressZero,
    );

    expect(freezeAmountMDC).eq(freezeTokenBefore);

    const $_AfterCreate: BigNumber[] = await Promise.all(
      challengerList.map((challenger) =>
        ethers.provider
          .getBalance(challenger.address)
          .then((balance) => balance),
      ),
    );
    // console.log(
    //   '$_AfterCreate',
    //   $_AfterCreate.map((b) => utils.formatEther(b)),
    // );

    const $_feeSpend = $_BeforeAll.map((balance, idx) =>
      BigNumber.from(balance).sub(BigNumber.from($_AfterCreate[idx])),
    );

    const makerVerifySource = new TestMakerDeposit__factory(
      challengerList[1],
    ).attach(makerTest.address);

    const tx = await makerVerifySource
      .verifyChallengeSource(
        challengerList[1].address,
        mainnet2eraSpv.address,
        makerPublicInputData.chain_id,
        makerPublicInputData,
        rawData,
        rlpRawdata,
        {
          maxPriorityFeePerGas: 1,
        },
      )
      .then((t: any) => t.wait());

    expect(tx.status).to.be.eq(1);

    $_feeSpend[1] = $_feeSpend[1].add(
      BigNumber.from(
        (await calculateTxGas(tx, 'verifyChallengeSourceTx ', true))
          .transactionfee,
      ),
    );

    console.log(
      '$_feeSpend-afterVerifySource',
      $_feeSpend.map((b) => utils.formatEther(b)),
    );

    // check contract balance
    const mdcBalanceAfterCreateChallenge = await ethers.provider.getBalance(
      makerTest.address,
    );

    expect(BigNumber.from(mdcBalanceAfterCreateChallenge)).eq(
      BigNumber.from(mdcBalanceBeforeCreateChallenge).add(freezeAmountTotal),
    );

    await mineXTimes(14400);

    const challengeList = challengeManager.getChallengeInfoList();
    await liquidateChallenge(
      makerTest,
      challengeList,
      challengerList.map((c) => c.address),
    );
    expect(challengeManager.getChallengeInfoList().length).eq(0);

    const $_AfterLiqui: BigNumber[] = await Promise.all(
      challengerList.map((challenger) =>
        ethers.provider
          .getBalance(challenger.address)
          .then((balance) => balance),
      ),
    );
    console.log(
      '$_AfterLiqui',
      $_AfterLiqui.map((b) => utils.formatEther(b)),
    );

    const $_returnToChallenger = $_AfterLiqui.map((balance, idx) =>
      BigNumber.from(balance).sub(BigNumber.from($_AfterCreate[idx])),
    );
    console.log(
      '$_returnToChallenger',
      $_returnToChallenger.map((b) => utils.formatEther(b)),
    );

    const $_challengerProfit = $_returnToChallenger.map((balance, idx) =>
      balance
        .sub(challenge.freezeAmount)
        .sub(BigNumber.from(utils.parseEther('0.005'))),
    );
    console.log(
      '$_challengerProfit',
      $_challengerProfit.map((b) => utils.formatEther(b)),
    );

    const $_victimBalanceAfterChallenge = await ethers.provider.getBalance(
      victim.address,
    );

    const $_victimGain = $_victimBalanceAfterChallenge.sub(
      victimBalanceBeforeChallenge,
    );

    const amountShouldGet = BigNumber.from(victimLostAmount)
      .mul(challengerRatio)
      .div(challengerRatio100);

    const freezeTokenLeft = await makerTest.freezeAssets(constants.AddressZero);
    console.log(
      "victim's lost amount:",
      utils.formatEther(victimLostAmount),
      'challenge return amount:',
      utils.formatEther($_victimGain),
    );

    expect($_challengerProfit[$_challengerProfit.length - 1]).eq(0);
    expect($_challengerProfit[$_challengerProfit.length - 2]).eq(0);
    expect($_challengerProfit[$_challengerProfit.length - 3].toString()).eq(
      BigNumber.from(0)
        .sub(
          BigNumber.from(victimLostAmount)
            .mul(2)
            .add(BigNumber.from(utils.parseEther('0.005'))),
        )
        .toString(),
    );
    expect($_challengerProfit[$_challengerProfit.length - 4].toString()).eq(
      BigNumber.from(0)
        .sub(
          BigNumber.from(victimLostAmount)
            .mul(2)
            .add(BigNumber.from(utils.parseEther('0.005'))),
        )
        .toString(),
    );
    expect($_challengerProfit[1]).greaterThanOrEqual(
      BigNumber.from(amountShouldGet),
    );
    expect(amountShouldGet).eq($_victimGain.sub(victimLostAmount));
    expect(freezeTokenLeft).eq(0);
  });

  it('Challenge and verifyDestTx', async function () {
    const verifyDestSigner = signers[7];
    const liquidaionSigner = signers[8];
    const { factoryAddress, mdcAddress } = await deployMDC(
      verifyDestSigner,
      process.env['OR_MANAGER_ADDRESS']!,
      mdc_test_impl.address,
    );

    const makerTest = new TestMakerDeposit__factory(verifyDestSigner).attach(
      mdcAddress,
    );

    const victim = signers[signers.length - 1];
    const challengerRatio100 = 1000000; // 1000000 = 100%
    const challengerRatio = 300000;
    console.log('victim:', victim.address);
    const amount = utils.parseEther('10');
    await deployer.sendTransaction({
      to: makerTest.address,
      value: amount,
    });

    const columnArray = {
      dealers: [mdcOwner.address],
      ebcs: [process.env['EVENT_BINDING_CONTRACT']!],
      chainIds: [5, 420, 280, 300, 11155111],
    };
    await orManager
      .updateSpvDataContract(spvData.address)
      .then((t) => t.wait());
    await orManager
      .updateSpvDataInjectOwner(deployer.address)
      .then((t) => t.wait());

    await orManager.updatePriorityFee(1);

    challengeManager.initialize();

    let defaultRule: BigNumberish[] = [
      300,
      11155111,
      1,
      1,
      0,
      0,
      20000000000,
      20000000000,
      BigNumber.from('100000000000000000000'),
      BigNumber.from('100000000000000000000'),
      10000000,
      20000000,
      1,
      1,
      604800,
      604800,
      42,
      49,
    ];
    const formatDefaultRule = formatRule(defaultRule);
    await updateMakerRule(makerTest, ebc.address, makerRule);
    await orManager.updateDecoderAddress(rlpDecoder.address);
    expect(await orManager.getRulesDecoder()).eq(rlpDecoder.address);
    const publicInputData: PublicInputData =
      await mainnet2eraSpv.parseSourceTxProof(m2eSourceProof);

    const publicInputDataDest: PublicInputDataDest =
      await mainnet2eraSpv.parseDestTxProof(m2eDestProof);

    // await mockSpvData(
    //   spvData,
    //   Array.from(
    //     new Set(
    //       publicInputDataDest.merkle_roots.concat(publicInputData.merkle_roots),
    //     ),
    //   ),
    // );

    // {
    //   const { encodeHash } = getRLPEncodeMakerRuleHash(defaultRule);
    //   expect(publicInputData).not.null;
    //   expect(encodeHash).eql(publicInputData.mdc_current_rule_value_hash);
    // }

    const challengeColumnArray: columnArray = {
      ...columnArray,
      dealers: [mdcOwner.address],
      ebcs: [ebc.address],
    };

    const verifyTimeMax =
      utils.hexZeroPad(BigNumber.from(9999999).toHexString(), 8) +
      utils.hexZeroPad('0x00', 8).slice(2) +
      utils.hexZeroPad(BigNumber.from(8888888).toHexString(), 8).slice(2) +
      utils.hexZeroPad('0x00', 8).slice(2);

    const { rawData, columnArrayHash } = await getRawDataNew(
      challengeColumnArray,
      ebc.address,
    );

    const price = makerRule.minPrice0.mul(3).toString().slice(0, -5);
    const victimLostAmount =
      price +
      getSecurityCode(
        challengeColumnArray,
        ebc.address,
        mdcOwner.address,
        parseInt(makerRuleDestChain.toString()),
      );
    console.log('victimLostAmount', utils.formatEther(victimLostAmount));

    const verifyinfoBase: VerifyinfoBase = {
      chainIdSource: makerRuleSourceChain,
      freeTokenSource: makerRule.token0.toHexString(),
      chainIdDest: makerRuleDestChain,
      freeTokenDest: makerRule.token1.toHexString(),
      ebc: ebc.address,
    };

    // get related slots & values of maker/manager contract
    const verifyInfo = await getVerifyinfo(
      makerTest,
      orManager,
      verifyinfoBase,
    );
    // default rule not work in uint test , replace with new rule
    const { rlpRawdata, encodeHash } = getRLPEncodeMakerRuleHash(
      converRule(makerRule),
    );
    const RLPDecodeRule: RuleStruct = await rlpDecoder.decodeRule(rlpRawdata);
    expect(converRule(RLPDecodeRule)).deep.equals(converRule(makerRule));
    const defaultRessponseMakers = mdcOwner.address;
    const responseMakersEncodeRaw = await spvTest.encodeResponseMakers([
      defaultRessponseMakers,
    ]);
    const responseMakersHash = keccak256(responseMakersEncodeRaw);

    const makerPublicInputData: PublicInputData = {
      // with replace reason
      ...publicInputData,
      from: victim.address,
      to: verifyDestSigner.address,
      mdc_contract_address: makerTest.address, // mdc not same
      manage_contract_address: orManager.address, // manager not same
      max_verify_challenge_dest_tx_second:
        BigNumber.from(99999999999999).toHexString(), // max verify time too small
      max_verify_challenge_src_tx_second:
        BigNumber.from(99999999999999).toHexString(), // max verify time too small
      min_verify_challenge_dest_tx_second: BigNumber.from(0).toHexString(), // min verify time too long
      min_verify_challenge_src_tx_second: BigNumber.from(0).toHexString(), // min verify time too long
      mdc_current_column_array_hash: columnArrayHash, // dealer & ebc not same
      amount: BigNumber.from(victimLostAmount), // security code base on ebc & dealer, they both changed
      mdc_rule_root_slot: verifyInfo.slots[6].key, // ebc not same
      mdc_rule_version_slot: verifyInfo.slots[7].key, // ebc not same
      // mdc_column_array_hash_slot: verifyInfo.slots[3].key,
      // mdc_response_makers_hash_slot: verifyInfo.slots[5].key,
      mdc_current_rule_value_hash: encodeHash, // rule not compatible
      mdc_current_response_makers_hash: responseMakersHash, // response maker not same
      manage_current_challenge_user_ratio: challengerRatio,
      // mdc_next_rule_enable_time: publicInputData.mdc_current_rule_enable_time,
    };

    // console.log('makerPublicInputData', makerPublicInputData);

    const rulesKey = calculateRuleKey(converRule(makerRule));
    const encodeRuleKey = utils.solidityPack(
      ['uint256', 'uint256', 'uint256', 'uint256'],
      [
        makerRule.chainId0,
        makerRule.chainId1,
        makerRule.token0,
        makerRule.token1,
      ],
    );
    const ruleKey = utils.keccak256(encodeRuleKey);
    expect(ruleKey).eq(rulesKey);

    const challenge: challengeInputInfo = {
      sourceTxTime: BigNumber.from(makerPublicInputData.time_stamp).toNumber(),
      sourceChainId: BigNumber.from(makerPublicInputData.chain_id).toNumber(),
      destChainId: BigNumber.from(makerRuleDestChain).toNumber(),
      sourceBlockNum: BigNumber.from(0).toNumber(),
      sourceTxIndex: BigNumber.from(makerPublicInputData.index).toNumber(),
      sourceTxHash: utils.hexZeroPad(
        BigNumber.from(makerPublicInputData.tx_hash).toHexString(),
        32,
      ),
      from: BigNumber.from(makerPublicInputData.from).toHexString(),
      freezeToken: makerPublicInputData.token,
      freezeAmount: BigNumber.from(makerPublicInputData.amount).mul(2),
      parentNodeNumOfTargetNode: 0,
    };
    // mainnet2eraSpv should be setting by manager
    await updateSpv(
      BigNumber.from(challenge.sourceChainId).toNumber(),
      mainnet2eraSpv.address,
      orManager,
    );
    const challengerList: SignerWithAddress[] = [
      signers[0],
      signers[1],
      signers[2],
      signers[3],
      signers[4],
      signers[5],
    ];
    const mdcBalanceBeforeCreateChallenge = await ethers.provider.getBalance(
      makerTest.address,
    );

    console.log(
      'mdcBalanceBeforeCreateChallenge',
      utils.formatEther(mdcBalanceBeforeCreateChallenge),
    );
    let freezeAmountTotal: BigNumberish = BigNumber.from(0);
    let minDeposit = utils.parseEther('0.005');
    const gasUsedList: BigNumber[] = [];

    const $_BeforeAll: BigNumber[] = await Promise.all(
      challengerList.map((challenger) =>
        ethers.provider
          .getBalance(challenger.address)
          .then((balance) => balance),
      ),
    );
    console.log(
      '$_BeforeAll',
      $_BeforeAll.map((b) => utils.formatEther(b)),
    );

    const victimBalanceBeforeChallenge = await ethers.provider.getBalance(
      victim.address,
    );

    let freezeAmountMDC: BigNumberish = BigNumber.from(0);

    for (const challenger of challengerList) {
      let challengeInfo: challengeInputInfo = challenge;
      if (
        challengerList.indexOf(challenger) === 2 ||
        challengerList.indexOf(challenger) === 3
      ) {
        challengeInfo = {
          ...challengeInfo,
          freezeAmount: BigNumber.from(challengeInfo.freezeAmount).add(
            challengerList.indexOf(challenger),
          ),
        };
      }
      const makerTestChallenge = new TestMakerDeposit__factory(
        challenger,
      ).attach(makerTest.address);
      gasUsedList.push(
        BigNumber.from(
          (
            await createChallenge(
              makerTestChallenge,
              challengeInfo,
              converRule(makerRule),
            )
          ).transactionfee,
        ),
      );
      freezeAmountTotal = freezeAmountTotal
        .add(minDeposit)
        .add(challengeInfo.freezeAmount);

      freezeAmountMDC = freezeAmountMDC
        .add(BigNumber.from(challengeInfo.freezeAmount).mul(2))
        .add(minDeposit);
    }

    const freezeTokenBefore = await makerTest.freezeAssets(
      constants.AddressZero,
    );

    expect(freezeAmountMDC).eq(freezeTokenBefore);

    const $_AfterCreate: BigNumber[] = await Promise.all(
      challengerList.map((challenger) =>
        ethers.provider
          .getBalance(challenger.address)
          .then((balance) => balance),
      ),
    );

    const $_feeSpend = $_BeforeAll.map((balance, idx) =>
      BigNumber.from(balance).sub(BigNumber.from($_AfterCreate[idx])),
    );

    const makerVerifySource = new TestMakerDeposit__factory(
      challengerList[1],
    ).attach(makerTest.address);

    const tx = await makerVerifySource
      .verifyChallengeSource(
        challengerList[1].address,
        mainnet2eraSpv.address,
        makerPublicInputData.chain_id,
        makerPublicInputData,
        rawData,
        rlpRawdata,
        {
          maxPriorityFeePerGas: 1,
        },
      )
      .then((t: any) => t.wait());

    expect(tx.status).to.be.eq(1);

    $_feeSpend[1] = $_feeSpend[1].add(
      BigNumber.from(
        (await calculateTxGas(tx, 'verifyChallengeSourceTx ', true))
          .transactionfee,
      ),
    );

    // check contract balance
    const mdcBalanceAfterCreateChallenge = await ethers.provider.getBalance(
      makerTest.address,
    );

    expect(BigNumber.from(mdcBalanceAfterCreateChallenge)).eq(
      BigNumber.from(mdcBalanceBeforeCreateChallenge).add(freezeAmountTotal),
    );

    const destAmount = await spvTest.calculateDestAmount(
      makerRule,
      ebc.address,
      makerPublicInputData.chain_id,
      makerPublicInputData.amount,
    );

    const verifiedDataHashData: BigNumberish[] = [
      makerPublicInputData.min_verify_challenge_dest_tx_second,
      makerPublicInputData.max_verify_challenge_dest_tx_second,
      makerPublicInputData.nonce,
      makerRuleDestChain,
      makerPublicInputData.from,
      constants.AddressZero,
      destAmount,
      makerPublicInputData.mdc_current_response_makers_hash,
      makerRule.responseTime0,
    ];

    const verifiedDataHash = keccak256(
      solidityPack(
        [
          'uint256',
          'uint256',
          'uint256',
          'uint256',
          'uint256',
          'uint256',
          'uint256',
          'uint256',
          'uint256',
        ],
        verifiedDataHashData,
      ),
    );

    await mineXTimes(2);

    const verifiedDataInfo: VerifiedDataInfo = {
      minChallengeSecond: verifiedDataHashData[0],
      maxChallengeSecond: verifiedDataHashData[1],
      nonce: verifiedDataHashData[2],
      destChainId: verifiedDataHashData[3],
      from: verifiedDataHashData[4],
      destToken: verifiedDataHashData[5],
      destAmount: verifiedDataHashData[6],
      responseMakersHash: verifiedDataHashData[7],
      responseTime: verifiedDataHashData[8],
    };
    // console.log(
    //   'verifiedDataInfo',
    //   verifiedDataInfo,
    //   'hash:',
    //   verifiedDataHash,
    // );
    expect(verifiedDataHash).eq(tx.events[0].args.result.verifiedDataHash0!);

    const makerPublicInputDataDest: PublicInputDataDest = {
      ...publicInputDataDest,
      // chain_id: makerRule.chainId1.toHexString(), // align with makerRule
      token: makerRule.token0.toHexString(), // align with makerRule
      from: mdcOwner.address,
      to: makerPublicInputData.from,
      amount: BigNumber.from(verifiedDataInfo.destAmount).add(
        verifiedDataInfo.nonce,
      ),
    };

    const txDest = await makerTest
      .verifyChallengeDest(
        challengerList[1].address,
        mainnet2eraSpv.address,
        challenge.sourceChainId,
        challenge.sourceTxHash,
        // m2eDestProof,
        verifiedDataInfo,
        responseMakersEncodeRaw,
        makerPublicInputDataDest,
      )
      .then((t: any) => t.wait());
    expect(txDest.status).to.be.eq(1);
    // await calculateTxGas(txDest, 'verifyChallengeDestTx ');

    $_feeSpend[1] = $_feeSpend[1].add(
      BigNumber.from(
        (await calculateTxGas(txDest, 'verifyChallengeDestTx ', true))
          .transactionfee,
      ),
    );

    // console.log(
    //   '$_feeSpend-afterVerifyDest',
    //   $_feeSpend.map((b) => utils.formatEther(b)),
    // );

    const $_AfterVerifyDest: BigNumber[] = await Promise.all(
      challengerList.map((challenger) =>
        ethers.provider
          .getBalance(challenger.address)
          .then((balance) => balance),
      ),
    );
    // console.log(
    //   '_AfterVerifyDest',
    //   $_AfterVerifyDest.map((b) => utils.formatEther(b)),
    // );

    const challengeList = challengeManager.getChallengeInfoList();
    await liquidateChallenge(
      makerTest,
      challengeList,
      challengerList.map((c) => c.address),
    );
    expect(challengeManager.getChallengeInfoList().length).eq(0);

    const balanceAfterList: bigint[] = await Promise.all(
      challengerList.map((challenger) =>
        ethers.provider
          .getBalance(challenger.address)
          .then((balance) => balance.toBigInt()),
      ),
    );

    // console.log(
    //   'balanceAfterList',
    //   balanceAfterList.map((b) => utils.formatEther(b)),
    // );

    const freezeTokenAfter = await makerTest.freezeAssets(
      constants.AddressZero,
    );
    expect(freezeTokenAfter).eq(0);
    expect(balanceAfterList).deep.equals($_AfterVerifyDest);
  });
});
