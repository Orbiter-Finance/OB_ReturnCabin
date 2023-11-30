/* eslint-disable prettier/prettier */
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import chalk from 'chalk';
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import {
  TestSpv__factory,
  ORChallengeSpv__factory,
  ORChallengeSpv,
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
} from '../typechain-types';
import { PromiseOrValue } from '../typechain-types/common';
import { BigNumber, BigNumberish, BytesLike, constants, utils } from 'ethers';
import { createChallenge, getMinEnableTime } from '../test/utils.test';
import { promises } from 'dns';
import { random } from 'lodash';
import { defaultResponseTime } from '../test/lib/mockData';
import { expect } from 'chai';

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
          .readFileSync(
            'test/example/era2mainnetSpvVerifier.proof.source',
            'utf-8',
          )
          .replace(/\t|\n|\v|\r|\f/g, ''),
    );

    verifyDestProof = utils.arrayify(
      '0x' +
        fs
          .readFileSync(
            'test/example/era2mainnetSpvVerifier.proof.dest',
            'utf-8',
          )
          .replace(/\t|\n|\v|\r|\f/g, ''),
    );
  }
  return {
    verifySourceProof,
    verifyDestProof,
  };
};

export const deploySPVs = async (
  deployer: SignerWithAddress,
  spvType: SPVTypeEnum = SPVTypeEnum.mainnet2era,
): Promise<string> => {
  const mdcOwner = deployer;
  let verifyDestBytesCode;
  let verifySourceBytesCode;
  if (spvType == SPVTypeEnum.mainnet2era) {
    verifyDestBytesCode = await compile_yul(
      'contracts/zkp/mainnet2eraSpvVerifier.DestTx.yul',
    );

    verifySourceBytesCode = await compile_yul(
      'contracts/zkp/mainnet2eraSpvVerifier.SourceTx.yul',
    );
  } else if (spvType == SPVTypeEnum.era2mainnet) {
    verifyDestBytesCode = await compile_yul(
      'contracts/zkp/era2mainnetSpvVerifier.DestTx.yul',
    );

    verifySourceBytesCode = await compile_yul(
      'contracts/zkp/era2mainnetSpvVerifier.SourceTx.yul',
    );
  }

  const verifierDestFactory = new ethers.ContractFactory(
    VerifierAbi,
    verifyDestBytesCode!,
    mdcOwner,
  );

  const verifierSourceFactory = new ethers.ContractFactory(
    VerifierAbi,
    verifySourceBytesCode!,
    mdcOwner,
  );

  const spvSource: { address: PromiseOrValue<string> } =
    await verifierSourceFactory.deploy();

  const spvDest: { address: PromiseOrValue<string> } =
    await verifierDestFactory.deploy();

  const spv: ORChallengeSpv = await new ORChallengeSpv__factory(
    mdcOwner,
  ).deploy(spvSource.address, spvDest.address);
  await spv.deployed();
  process.env['SPV_ADDRESS'] = spv.address;

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
  factoryOwner: SignerWithAddress,
  mdcOwner: SignerWithAddress,
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
    .connect(mdcOwner)
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
    5,
    280,
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
  deployer: SignerWithAddress,
  mdcOwner: SignerWithAddress,
) => {
  if (process.env['OR_MANAGER_ADDRESS'] == undefined) {
    const orManager = await new ORManager__factory(deployer).deploy(
      deployer.address,
    );
    await orManager.deployed();
    console.log('orManager deployed to:', orManager.address);
    process.env['OR_MANAGER_ADDRESS'] = orManager.address;
  }

  if (process.env['OR_MDC_TEST'] == undefined) {
    const makerTest_impl = await new TestMakerDeposit__factory(
      mdcOwner,
    ).deploy();
    await makerTest_impl.deployed();

    const { factoryAddress, mdcAddress } = await deployMDC(
      deployer,
      mdcOwner,
      process.env['OR_MANAGER_ADDRESS']!,
      makerTest_impl.address,
    );
    process.env['OR_MDC_TEST'] = mdcAddress;
    console.log('test factory deployed to:', factoryAddress);
  }

  if (process.env['OR_MDC'] == undefined) {
    const mdc_impl = await new ORMakerDeposit__factory(mdcOwner).deploy();
    await mdc_impl.deployed();

    const { factoryAddress, mdcAddress } = await deployMDC(
      deployer,
      mdcOwner,
      process.env['OR_MANAGER_ADDRESS']!,
      mdc_impl.address,
    );
    process.env['OR_MDC'] = mdcAddress;
    console.log('MDC deployed to:', factoryAddress);
  }

  if (process.env['EVENT_BINDING_CONTRACT'] == undefined) {
    const ebc = await new OREventBinding__factory(deployer).deploy();
    await ebc.deployed();
    console.log('ebc deployed to:', ebc.address);
    process.env['EVENT_BINDING_CONTRACT'] = ebc.address;
  }

  if (process.env['RLP_DECODER_ADDRESS'] == undefined) {
    const rlpDecoder = await new RLPDecoder__factory(deployer).deploy();
    await rlpDecoder.deployed();
    console.log('rlpDecoder deployed to:', rlpDecoder.address);
    process.env['RLP_DECODER_ADDRESS'] = rlpDecoder.address;
  }

  if (process.env['SPV_TEST_ADDRESS'] == undefined) {
    const spvTest = await new TestSpv__factory(mdcOwner).deploy(
      constants.AddressZero,
    );
    console.log('spvTest deployed to:', spvTest.address);
    process.env['SPV_TEST_ADDRESS'] = spvTest.address;
  }

  if (process.env['SPV_ADDRESS'] == undefined) {
    const spvaddress = await deploySPVs(deployer);
    console.log('spv deployed to:', spvaddress);
    process.env['SPV_ADDRESS'] = spvaddress;
  }

  // OR_SPV_DATA_ADRESS
  if (process.env['OR_SPV_DATA_ADRESS'] == undefined) {
    const orSpvData = await new ORSpvData__factory(deployer).deploy(
      process.env['OR_MANAGER_ADDRESS']!,
      deployer.address,
    );
    console.log('orSpvData deployed to:', orSpvData.address);
    process.env['OR_SPV_DATA_ADRESS'] = orSpvData.address;
  }

  return {
    orManager: process.env['OR_MANAGER_ADDRESS']!,
    orMDC: process.env['OR_MDC_TEST']!,
    eventBinding: process.env['EVENT_BINDING_CONTRACT']!,
    rlpDecoder: process.env['RLP_DECODER_ADDRESS']!,
    spvTest: process.env['SPV_TEST_ADDRESS']!,
    spv: process.env['SPV_ADDRESS']!,
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
