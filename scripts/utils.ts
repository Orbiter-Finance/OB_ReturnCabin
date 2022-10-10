import chalk from 'chalk';
import { ethers, upgrades } from 'hardhat';
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
export function loadOrDeployContract<T = any>(
  name: string,
  isProxy = false,
  ...params: any
) {
  if (process.env[name]) {
    return ethers.getContractAt(name, String(process.env[name])) as T;
  }
  return deploy(isProxy, name, ...params) as T;
}
export async function deploy<T = any>(
  deployProxy: boolean,
  name: string,
  ...params: any[]
) {
  let deployResult: T;
  const Contract = await ethers.getContractFactory(name);
  if (deployProxy) {
    deployResult = (await upgrades
      .deployProxy(Contract, params)
      .then((f) => f.deployed())) as T;
  } else {
    deployResult = (await Contract.deploy(...params).then((f: any) =>
      f.deployed(),
    )) as T;
  }
  printContract(name, (<any>deployResult).address);
  process.env[name] = (<any>deployResult).address;
  return deployResult;
}
