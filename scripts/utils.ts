import chalk from 'chalk';
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
