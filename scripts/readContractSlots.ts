/* eslint-disable prettier/prettier */
import { ethers } from 'hardhat';
import {
  OREventBinding__factory,
  ORMakerDeposit__factory,
  ORManager__factory,
} from '../typechain-types';

import { getVerifyinfo, VerifyinfoBase } from '../test/utils.test';
import { BigNumber, BigNumberish, constants } from 'ethers';
import { RuleStruct } from '../test/lib/rule';

export async function deploy() {
  const signers = await ethers.getSigners();
  const deployer = signers[0];

  // connect to orManager
  const orManager = new ORManager__factory(deployer).attach(
    process.env['OR_MANAGER_ADDRESS']!,
  );
  console.log('connect to orManager:', orManager.address);

  // connect to orMakerDeposit_impl
  const orMakerDeposit = new ORMakerDeposit__factory(deployer).attach(
    process.env['OR_MDC']!,
  );
  console.log('connect to orMakerDeposit:', orMakerDeposit.address);

  const ebc = new OREventBinding__factory(deployer).attach(
    process.env['EVENT_BINDING_CONTRACT']!,
  );
  console.log('connect to ebc:', ebc.address);

  const makerRule: RuleStruct = {
    chainId0: BigNumber.from(5),
    chainId1: BigNumber.from(280),
    status0: 1,
    status1: 1,
    token0: BigNumber.from(constants.AddressZero),
    token1: BigNumber.from(constants.AddressZero),
    minPrice0: BigNumber.from('10000000000'),
    minPrice1: BigNumber.from('10000000000'),
    maxPrice0: BigNumber.from('100000000000000000000'),
    maxPrice1: BigNumber.from('100000000000000000000'),
    withholdingFee0: BigNumber.from('10000000000'),
    withholdingFee1: BigNumber.from('20000000000'),
    tradingFee0: 1,
    tradingFee1: 1,
    responseTime0: 604800,
    responseTime1: 604800,
    compensationRatio0: 32,
    compensationRatio1: 31,
  };

  const verifyinfoBase: VerifyinfoBase = {
    chainIdSource: makerRule.chainId0,
    freeTokenSource: makerRule.token0.toHexString(),
    chainIdDest: makerRule.chainId1,
    freeTokenDest: makerRule.token1.toHexString(),
    ebc: ebc.address,
  };

  // get related slots & values of maker/manager contract
  const verifyInfo = await getVerifyinfo(
    orMakerDeposit,
    orManager,
    verifyinfoBase,
  );

  console.log('verifyInfo:', verifyInfo);
}

async function main() {
  await deploy();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
