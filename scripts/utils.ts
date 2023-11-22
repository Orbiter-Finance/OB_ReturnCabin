/* eslint-disable prettier/prettier */
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import chalk from 'chalk';
import { exec } from 'child_process';
import { promisify } from 'util';
import {
  TestSpv__factory,
  ORChallengeSpv__factory,
  ORChallengeSpv,
  ORMakerDeposit,
  contracts,
} from '../typechain-types';
import { PromiseOrValue } from '../typechain-types/common';
import { BigNumber } from 'ethers';
import { getMinEnableTime } from '../test/utils.test';
import { promises } from 'dns';

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

export const deploySPVs = async (
  deployer: SignerWithAddress,
): Promise<string> => {
  const mdcOwner = deployer;
  const verifyDestBytesCode = await compile_yul(
    'contracts/zkp/goerliDestSpvVerifier.yul',
  );

  const verifierDestFactory = new ethers.ContractFactory(
    VerifierAbi,
    verifyDestBytesCode,
    mdcOwner,
  );

  const verifySourceBytesCode = await compile_yul(
    'contracts/zkp/goerliSourceSpvVerifier.yul',
  );

  const verifierSourceFactory = new ethers.ContractFactory(
    VerifierAbi,
    verifySourceBytesCode,
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
