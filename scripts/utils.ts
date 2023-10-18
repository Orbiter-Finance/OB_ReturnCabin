/* eslint-disable prettier/prettier */
import chalk from 'chalk';
import { exec } from 'child_process';
import { promisify } from 'util';

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
  console.log(`cmdString ${cmd}`);

  const output = await executeCommand(cmd);
  const string_slice = output.split(/[\s\n]/);
  const evm_compiled_code = string_slice[string_slice.length - 2];

  return evm_compiled_code;
};

export const VerifierAbi = [
  {
    "payable": true,
    "stateMutability": 'payable',
    "type": 'fallback',
  },
];
