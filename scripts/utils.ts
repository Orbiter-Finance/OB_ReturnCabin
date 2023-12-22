/* eslint-disable prettier/prettier */
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import chalk from 'chalk';
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import {
  TestSpv__factory,
  ORChallengeSpvMainnet2Era__factory,
  ORChallengeSpvMainnet2Era,
  ORMakerDeposit,
  contracts,
  ORMDCFactory__factory,
  TestMakerDeposit,
  ORMakerDeposit__factory,
  TestMakerDeposit__factory,
  OREventBinding__factory,
  ORManager__factory,
  RLPDecoder__factory,
  ORManager,
  ORSpvData__factory,
  ORChallengeSpvEra2Mainnet__factory,
  ORChallengeSpvEra2Mainnet,
  ORFeeManager__factory,
} from '../typechain-types';
import { PromiseOrValue } from '../typechain-types/common';
import {
  BigNumber,
  BigNumberish,
  BytesLike,
  Signer,
  Wallet,
  constants,
  utils,
} from 'ethers';
import { createChallenge, getMinEnableTime } from '../test/utils.test';
import { promises } from 'dns';
import { random } from 'lodash';
import { defaultResponseTime } from '../test/lib/mockData';
import { expect } from 'chai';
import { deploy } from './deploy';

export function printContract(title: string, content?: string) {
  console.info(chalk.red(title, chalk.underline.green(content || '')));
}
export function printSuccess(title: string, content?: string) {
  console.info(chalk.gray(title), content || '');
}
export function printAddress(title: string, content?: string) {
  console.info(chalk.red(title, chalk.underline.blue(content || '')));
}
export function printHash(title: string, content?: string) {
  console.info(chalk.gray(title, chalk.underline.blue(content || '')));
}

const executeCommand = async (command: string): Promise<string> => {
  const execAsync = promisify(exec);
  try {
    const { stdout, stderr } = await execAsync(command);
    if (stderr) {
      throw new Error(stderr);
    }
    return stdout;
  } catch (error) {
    throw new Error(`Failed to execute command: ${error}`);
  }
};

export const compile_yul = async (codePath: string): Promise<string> => {
  const cmd = `solc --bin --yul --optimize-runs 200 ${codePath}`;
  // console.log(`cmdString ${cmd}`);

  const output = await executeCommand(cmd);
  const string_slice = output.split(/[\s\n]/);
  const evm_compiled_code = string_slice[string_slice.length - 2];

  return evm_compiled_code;
};

export const compile_sol = async (codePath: string): Promise<string> => {
  const cmd = `solc --bin --ignore-missing --optimize-runs 10 ${codePath}`;
  // console.log(`cmdString ${cmd}`);

  const output = await executeCommand(cmd);
  const string_slice = output.split(/[\s\n]/);
  const evm_compiled_code = string_slice[string_slice.length - 2];

  return evm_compiled_code;
};

export const VerifierAbi = [
  {
    payable: true,
    stateMutability: 'payable',
    type: 'fallback',
  },
];

export const verifierSolAbi = [
  {
    inputs: [
      {
        internalType: 'uint256[]',
        name: 'pubInputs',
        type: 'uint256[]',
      },
      {
        internalType: 'bytes',
        name: 'proof',
        type: 'bytes',
      },
      {
        internalType: 'bool',
        name: 'success',
        type: 'bool',
      },
      {
        internalType: 'bytes32[1033]',
        name: 'transcript',
        type: 'bytes32[1033]',
      },
    ],
    name: 'verifyPartial',
    outputs: [
      {
        internalType: 'bool',
        name: '',
        type: 'bool',
      },
      {
        internalType: 'bytes32[1033]',
        name: '',
        type: 'bytes32[1033]',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
];

export const verifierRouterAbi = [
  {
    internalType: 'address[]',
    name: '_verifierLogicParts',
    type: 'address[]',
  },
];

export enum SPVTypeEnum {
  mainnet2era = 0,
  era2mainnet = 1,
}

export const getSpvProof = (spvType: SPVTypeEnum = SPVTypeEnum.mainnet2era) => {
  let verifySourceProof: BytesLike = '0x';
  let verifyDestProof: BytesLike = '0x';
  if (spvType == SPVTypeEnum.mainnet2era) {
    verifySourceProof = utils.arrayify(
      '0x' +
        fs
          .readFileSync('test/example/mainnet2era.proof.source', 'utf-8')
          .replace(/\t|\n|\v|\r|\f/g, ''),
    );

    verifyDestProof = utils.arrayify(
      '0x' +
        fs
          .readFileSync('test/example/mainnet2era.proof.dest', 'utf-8')
          .replace(/\t|\n|\v|\r|\f/g, ''),
    );
  } else if (spvType == SPVTypeEnum.era2mainnet) {
    verifySourceProof = utils.arrayify(
      '0x' +
        fs
          .readFileSync('test/example/era2mainnet.proof.source', 'utf-8')
          .replace(/\t|\n|\v|\r|\f/g, ''),
    );

    verifyDestProof = utils.arrayify(
      '0x' +
        fs
          .readFileSync('test/example/era2mainnet.proof.dest', 'utf-8')
          .replace(/\t|\n|\v|\r|\f/g, ''),
    );
  }
  return {
    verifySourceProof,
    verifyDestProof,
  };
};

export interface updateSpvType {
  sourceTx: boolean;
  destTx: boolean;
}

export const deploySpvYul = async (
  bytesCode: string,
  deployer: Wallet | SignerWithAddress,
): Promise<string> => {
  const verifierFactory = new ethers.ContractFactory(
    VerifierAbi,
    bytesCode!,
    deployer,
  );

  const spvSource: { address: PromiseOrValue<string> } =
    await verifierFactory.deploy();
  return spvSource.address;
};

export const hotUpdateSpvVerifier = async (
  spv: ORChallengeSpvMainnet2Era | ORChallengeSpvEra2Mainnet,
  updateType: updateSpvType,
  spvType: SPVTypeEnum = SPVTypeEnum.mainnet2era,
  deployer: SignerWithAddress,
): Promise<void> => {
  let sourceTxVerifier: string;
  let destTxVerifier: string;
  await spv.getSpvVerifierAddr().then((currVerifier) => {
    sourceTxVerifier = currVerifier[0];
    destTxVerifier = currVerifier[1];
    console.log(
      'before update,',
      'current sourceTxVerifier:',
      currVerifier[0],
      'destTxVerifier:',
      currVerifier[1],
    );
  });
  if (updateType.sourceTx == true) {
    const verifySourceBytesCode =
      spvType == SPVTypeEnum.mainnet2era
        ? await compile_yul('contracts/zkp/mainnet2eraSpvVerifier.SourceTx.yul')
        : await compile_yul(
            'contracts/zkp/era2mainnetSpvVerifier.SourceTx.yul',
          );

    sourceTxVerifier = await deploySpvYul(verifySourceBytesCode!, deployer);
    console.log('new sourceTxVerifier:', sourceTxVerifier);
  }

  if (updateType.destTx == true) {
    const verifyDestBytesCode =
      spvType == SPVTypeEnum.mainnet2era
        ? await compile_yul('contracts/zkp/mainnet2eraSpvVerifier.DestTx.yul')
        : await compile_yul('contracts/zkp/era2mainnetSpvVerifier.DestTx.yul');
    destTxVerifier = await deploySpvYul(verifyDestBytesCode!, deployer);
    console.log('new destTxVerifier:', destTxVerifier);
  }

  await spv.setSpvVerifierAddr(sourceTxVerifier!, destTxVerifier!).then((t) => {
    t.wait(2);
  });

  await spv.getSpvVerifierAddr().then((currVerifier) => {
    console.log(
      'after update,',
      'current sourceTxVerifier:',
      currVerifier[0],
      'destTxVerifier:',
      currVerifier[1],
    );
  });
};

export const deploySPVs = async (
  deployer: Wallet | SignerWithAddress,
  spvType: SPVTypeEnum = SPVTypeEnum.mainnet2era,
): Promise<string> => {
  let verifyDestBytesCode;
  let verifySourceBytesCode;
  let contractFactory;
  if (spvType == SPVTypeEnum.mainnet2era) {
    contractFactory = ORChallengeSpvMainnet2Era__factory;
    verifyDestBytesCode = await compile_yul(
      'contracts/zkp/mainnet2eraSpvVerifier.DestTx.yul',
    );

    verifySourceBytesCode = await compile_yul(
      'contracts/zkp/mainnet2eraSpvVerifier.SourceTx.yul',
    );
  } else if (spvType == SPVTypeEnum.era2mainnet) {
    contractFactory = ORChallengeSpvEra2Mainnet__factory;
    verifyDestBytesCode = await compile_yul(
      'contracts/zkp/era2mainnetSpvVerifier.DestTx.yul',
    );

    verifySourceBytesCode = await compile_yul(
      'contracts/zkp/era2mainnetSpvVerifier.SourceTx.yul',
    );
  }

  const spvSourceAddress = await deploySpvYul(verifySourceBytesCode!, deployer);
  const spvDestAddress = await deploySpvYul(verifyDestBytesCode!, deployer);

  const spv: ORChallengeSpvMainnet2Era = await new contractFactory!(
    deployer,
  ).deploy(spvSourceAddress, spvDestAddress);
  console.log(
    'Address of sourceTxVerifier:',
    spvSourceAddress,
    'destTxVerifier:',
    spvDestAddress,
  );

  await spv.deployed();
  return spv.address;
};

export const MIN_ENABLE_DELAY = 120; // Unit: second
export const calculateEnableTime = async (
  contract: any,
): Promise<BigNumber> => {
  const currentRootwithVersion = await contract.getVersionAndEnableTime();
  const statuses = await ethers.provider.getBlock('latest');
  const oldTimeStamp =
    statuses.timestamp > currentRootwithVersion.enableTime.toNumber()
      ? statuses.timestamp
      : currentRootwithVersion.enableTime.toNumber();
  return getMinEnableTime(BigNumber.from(oldTimeStamp));
};

export const deployMDC = async (
  factoryOwner: Wallet | SignerWithAddress,
  orManagerAddress: string,
  orMakerDeposit_implAddress: string,
  oldfactoryAddress?: string,
) => {
  let orMDCFactory;
  if (oldfactoryAddress == undefined) {
    orMDCFactory = await new ORMDCFactory__factory(factoryOwner).deploy(
      orManagerAddress,
      orMakerDeposit_implAddress,
    );
    await orMDCFactory.deployed();
  } else {
    orMDCFactory = new ORMDCFactory__factory(factoryOwner).attach(
      oldfactoryAddress,
    );
  }

  const { events } = await orMDCFactory
    .connect(factoryOwner)
    .createMDC()
    .then((t) => t.wait());
  const mdcAddress = events?.[0].args?.mdc;
  const factoryAddress = orMDCFactory.address;
  return {
    factoryAddress,
    mdcAddress,
  };
};

export const createRandomChallenge = async (
  orMakerDeposit: ORMakerDeposit | TestMakerDeposit,
  chainId: BigNumber,
) => {
  const latestBlockRes = await orMakerDeposit.provider?.getBlock('latest');
  const sourceTxTime = random(latestBlockRes.timestamp - defaultResponseTime);
  const sourceChainId = chainId;
  const sourceBlockNum = random(latestBlockRes.number);
  const sourceTxIndex = random(1000);
  const sourceTxHash = utils.keccak256(await orMakerDeposit.owner());
  const challengeInputInfo = {
    sourceTxTime: sourceTxTime,
    sourceChainId: sourceChainId,
    destChainId: sourceChainId.add(1),
    sourceBlockNum: sourceBlockNum,
    sourceTxIndex: sourceTxIndex,
    sourceTxHash: sourceTxHash,
    from: await orMakerDeposit.owner(),
    freezeToken: constants.AddressZero,
    freezeAmount: utils.parseEther('0.000001'),
    parentNodeNumOfTargetNode: 0,
  };
  const randomMakerRule: BigNumberish[] = [
    sourceChainId,
    random(BigNumber.from(sourceChainId).toNumber() - 1),
    1,
    1,
    0,
    0,
    10000000000,
    10000000000,
    BigNumber.from('100000000000000000000'),
    BigNumber.from('100000000000000000000'),
    10000000000,
    20000000000,
    1,
    1,
    604800,
    604800,
    32,
    31,
  ];

  await createChallenge(orMakerDeposit, challengeInputInfo, randomMakerRule);
};

export const deployContracts = async (
  deployer: Wallet | SignerWithAddress,
  deployTestContracts: boolean = false,
) => {
  let currBlk;
  if (process.env['OR_MANAGER_ADDRESS'] == undefined) {
    currBlk = await ethers.provider.getBlockNumber();
    const orManager = await new ORManager__factory(deployer).deploy(
      deployer.address,
    );
    await orManager.deployed();
    console.log(
      `Address of orManager: ${orManager.address}, deployed blockNumber: ${currBlk} `,
    );
    process.env['OR_MANAGER_ADDRESS'] = orManager.address;
  } else {
    console.log('existing orManager:', process.env['OR_MANAGER_ADDRESS']!);
  }

  if (process.env['OR_MDC_TEST'] == undefined && deployTestContracts) {
    const makerTest_impl = await new TestMakerDeposit__factory(
      deployer,
    ).deploy();
    await makerTest_impl.deployed();
    process.env['OR_MDC_TEST_IMPL'] = makerTest_impl.address;
    console.log('Address of makerTest_impl:', makerTest_impl.address);

    const { factoryAddress, mdcAddress } = await deployMDC(
      deployer,
      process.env['OR_MANAGER_ADDRESS']!,
      makerTest_impl.address,
    );
    process.env['OR_MDC_TEST'] = mdcAddress;
    process.env['OR_MDC_FACTORY_TEST'] = factoryAddress;
    console.log('Address of test factory:', factoryAddress);
    console.log('Address of test MDC:', mdcAddress);
  } else {
    if (deployTestContracts) {
      console.log('existing test MDC:', process.env['OR_MDC_TEST']!);
      console.log(
        'existing test factory:',
        process.env['OR_MDC_FACTORY_TEST']!,
      );
    }
  }

  if (process.env['OR_MDC_FACTORY_ADDRESS'] == undefined) {
    currBlk = await ethers.provider.getBlockNumber();
    const mdc_impl = await new ORMakerDeposit__factory(deployer).deploy();
    await mdc_impl.deployed();
    process.env['OR_MDC_IMPL'] = mdc_impl.address;
    console.log('Address of mdc_impl:', mdc_impl.address);

    const orMDCFactory = await new ORMDCFactory__factory(deployer).deploy(
      process.env['OR_MANAGER_ADDRESS'],
      mdc_impl.address,
    );
    await orMDCFactory.deployed();
    if (deployTestContracts) {
      const { mdcAddress } = await deployMDC(
        deployer,
        process.env['OR_MANAGER_ADDRESS']!,
        mdc_impl.address,
        orMDCFactory.address,
      );
      process.env['OR_MDC'] = mdcAddress;
      console.log('Address of MDC:', mdcAddress);
    }

    process.env['OR_MDC_FACTORY_ADDRESS'] = orMDCFactory.address;
    console.log(
      `Address of orMDCFactory: ${orMDCFactory.address}, deployed blockNumber: ${currBlk} `,
    );
  } else {
    if (deployTestContracts && process.env['OR_MDC'] != undefined) {
      console.log('existing MDC:', process.env['OR_MDC']!);
    }
    console.log('existing factory:', process.env['OR_MDC_FACTORY_ADDRESS']!);
  }

  if (process.env['EVENT_BINDING_CONTRACT'] == undefined) {
    const ebc = await new OREventBinding__factory(deployer).deploy();
    await ebc.deployed();
    console.log('Address of ebc:', ebc.address);
    process.env['EVENT_BINDING_CONTRACT'] = ebc.address;
  } else {
    console.log('existing ebc:', process.env['EVENT_BINDING_CONTRACT']!);
  }

  if (process.env['RLP_DECODER_ADDRESS'] == undefined) {
    const rlpDecoder = await new RLPDecoder__factory(deployer).deploy();
    await rlpDecoder.deployed();
    console.log('Address of rlpDecoder:', rlpDecoder.address);
    process.env['RLP_DECODER_ADDRESS'] = rlpDecoder.address;
  } else {
    console.log('existing rlpDecoder:', process.env['RLP_DECODER_ADDRESS']!);
  }

  if (process.env['SPV_TEST_ADDRESS'] == undefined && deployTestContracts) {
    const spvTest = await new TestSpv__factory(deployer).deploy(
      constants.AddressZero,
    );
    console.log('Address of spvTest:', spvTest.address);
    process.env['SPV_TEST_ADDRESS'] = spvTest.address;
  } else {
    if (deployTestContracts)
      console.log('existing spvTest:', process.env['SPV_TEST_ADDRESS']!);
  }

  if (process.env['SPV_ADDRESS'] == undefined) {
    const spvaddress = await deploySPVs(deployer, SPVTypeEnum.mainnet2era);
    console.log('Address of spv(mainnet->era):', spvaddress);
    process.env['SPV_ADDRESS'] = spvaddress;
  } else {
    console.log('existing spv:', process.env['SPV_ADDRESS']!);
  }

  if (process.env['SPV_ADDRESS_ERA'] == undefined) {
    const spvaddress = await deploySPVs(deployer, SPVTypeEnum.era2mainnet);
    console.log('Address of spv(era->mainnet):', spvaddress);
    process.env['SPV_ADDRESS_ERA'] = spvaddress;
  } else {
    console.log('existing spv(era->mainnet):', process.env['SPV_ADDRESS_ERA']!);
  }

  // OR_SPV_DATA_ADRESS
  if (process.env['OR_SPV_DATA_ADRESS'] == undefined) {
    currBlk = await ethers.provider.getBlockNumber();
    const orSpvData = await new ORSpvData__factory(deployer).deploy(
      process.env['OR_MANAGER_ADDRESS']!,
      deployer.address,
    );
    console.log(
      `Address of orSpvData: ${orSpvData.address}, deployed blockNumber: ${currBlk} `,
    );
    process.env['OR_SPV_DATA_ADRESS'] = orSpvData.address;
  } else {
    console.log('existing orSpvData:', process.env['OR_SPV_DATA_ADRESS']!);
  }

  if (process.env['OR_FEE_MANAGER_ADDRESS'] == undefined) {
    currBlk = await ethers.provider.getBlockNumber();
    const feeManager = await new ORFeeManager__factory(deployer).deploy(
      deployer.address,
      process.env['OR_MANAGER_ADDRESS'],
    );
    await feeManager.deployed();
    console.log(
      `Address of feeManager: ${feeManager.address}, deployed blockNumber: ${currBlk}`,
    );
  }

  return {
    orManager: process.env['OR_MANAGER_ADDRESS']!,
    orMakerDeposit_impl: process.env['OR_MDC_IMPL']!,
    orMDCFactory: process.env['OR_MDC_FACTORY_ADDRESS']!,
    orMDC: process.env['OR_MDC_TEST']!,
    eventBinding: process.env['EVENT_BINDING_CONTRACT']!,
    rlpDecoder: process.env['RLP_DECODER_ADDRESS']!,
    spvTest: process.env['SPV_TEST_ADDRESS']!,
    spv: process.env['SPV_ADDRESS']!,
    spvERA: process.env['SPV_ADDRESS_ERA']!,
    orSpvData: process.env['OR_SPV_DATA_ADRESS']!,
  };
};

export const managerUpdateEBC = async (orManager: ORManager, ebc: string) => {
  if (await orManager.ebcIncludes(ebc)) {
    console.log('ebc already included');
    return;
  } else {
    await orManager.updateEbcs([ebc], [true]);
  }
};

export const testReverted = async (
  val: any,
  message: string,
): Promise<void> => {
  await expect(val).to.revertedWith(message);
};
