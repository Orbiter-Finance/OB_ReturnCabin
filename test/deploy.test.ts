import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import {
  TestToken,
  TestToken__factory,
  OREventBinding__factory,
  OREventBinding,
} from '../typechain-types';
import { expect } from 'chai';
import { formatEther } from 'ethers/lib/utils';
import { initTestToken, testToken } from './lib/mockData';

describe.skip('Test ebc', () => {
  let ebc: OREventBinding;
  let signers: SignerWithAddress[];

  before(async function () {
    signers = await ethers.getSigners();
  });

  it('deploy ebc should succeed', async function () {
    ebc = await new OREventBinding__factory(signers[0]).deploy();
    console.log('Address of Orbiter ebc:', ebc.address);
  });
});

describe.skip('Test deploy token', () => {
  let signers: SignerWithAddress[];
  let mdcOwner: SignerWithAddress;
  let testToken1: TestToken;
  let testToken2: TestToken;

  before(async function () {
    signers = await ethers.getSigners();
    mdcOwner = signers[0];

    if (process.env['DAI'] != undefined) {
      testToken1 = new TestToken__factory(mdcOwner).attach(process.env['DAI']);
    } else {
      testToken1 = await new TestToken__factory(mdcOwner).deploy(
        'Orbiter DAI',
        'ODAI',
      );
      await testToken1.deployed();
    }

    // if (process.env['OUSDC'] != undefined) {
    //   testToken2 = new TestToken__factory(mdcOwner).attach(
    //     process.env['OUSDC'],
    //   );
    // } else {
    //   testToken2 = await new TestToken__factory(mdcOwner).deploy(
    //     'Orbiter USDC',
    //     'OUSDC',
    //   );
    //   await testToken2.deployed();
    // }

    // await hre.run("verify:verify", {
    //   address: testToken1.address,
    //   constructorArguments: ["Orbiter USDT", "OUSDT"],
    // });

    // await hre.run("verify:verify", {
    //   address: testToken2.address,
    //   constructorArguments: ["Orbiter USDC", "OUSDC"],
    // });

    // await verifyContract(testToken1.address, ["Orbiter USDT", "OUSDT"]);
    // await verifyContract(testToken2.address, ["Orbiter USDC", "OUSDC"]);

    console.log('Address of Orbiter DAI:', testToken1.address);
    // console.log('Address of Orbiter DAI:', testToken2.address);
  });

  it('contract testToken should be deployed', async function () {
    expect(testToken1.address).to.not.equal(0);
    const balance = await testToken1.balanceOf(mdcOwner.address);
    const name = await testToken1.name();
    const symbol = await testToken1.symbol();
    console.log(
      `Name: ${name}, Symbol: ${symbol}, balance: ${formatEther(
        balance,
      )}, decimal: ${await testToken1.decimals()}`,
    );
  });

  // it('contract USDC should be deployed', async function () {
  //   expect(testToken2.address).to.not.equal(0);
  //   const balance = await testToken2.balanceOf(mdcOwner.address);
  //   console.log('Balance of mdcOwner:', formatEther(balance));
  //   const name = await testToken2.name();
  //   const symbol = await testToken2.symbol();
  //   console.log(
  //     `Name: ${name}, Symbol: ${symbol}, balance: ${formatEther(
  //       balance,
  //     )}, decimal: ${await testToken2.decimals()}`,
  //   );
  // });

  // it("should Mint 1000 tokens", async function () {
  //   await testToken.mint(1000000);
  //   const balance = await testToken.balanceOf(mdcOwner.address);
  //   console.log('Balance of mdcOwner:', formatEther(balance));
  // });
});

describe('Test mint token', () => {
  let signers: SignerWithAddress[];
  let mdcOwner: SignerWithAddress;
  let testToken1: TestToken;
  let testToken2: TestToken;

  before(async function () {
    signers = await ethers.getSigners();
    mdcOwner = signers[1];
    initTestToken();
  });

  it('mint token', async function () {
    console.log(`mint signer: ${mdcOwner.address}`);
    // await Promise.all

    testToken.MAINNET_TOKEN.map(async (tokenAddress) => {
      console.log(`mint tokenAddress: ${tokenAddress}`);
      const testToken1 = new TestToken__factory(mdcOwner).attach(tokenAddress);
      await testToken1.mint(1000000);
      const balance = await testToken1.balanceOf(mdcOwner.address);
      const name = await testToken1.name();
      const symbol = await testToken1.symbol();
      console.log(
        `Name: ${name}, Symbol: ${symbol}, balance: ${formatEther(
          balance,
        )}, decimal: ${await testToken1.decimals()}`,
      );
      expect(balance).to.equal(1000000);
    });
  });
});
