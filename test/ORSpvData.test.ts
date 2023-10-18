import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';

import { mine } from '@nomicfoundation/hardhat-network-helpers';
import { assert, expect } from 'chai';
import {
  ORManager,
  ORManager__factory,
  ORSpvData,
  ORSpvData__factory,
} from '../typechain-types';
import { BigNumber } from 'ethers';

describe('ORSpvData', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orSpvData: ORSpvData;

  before(async function () {
    signers = await ethers.getSigners();

    const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
    assert(
      !!envORManagerAddress,
      'Env miss [OR_MANAGER_ADDRESS]. You may need to test ORManager.test.ts first. Example: npx hardhat test test/ORManager.test.ts test/ORSpvData.test.ts',
    );

    orManager = await new ORManager__factory(signers[0])
      .attach(envORManagerAddress)
      .deployed();

    orSpvData = await new ORSpvData__factory(signers[0]).deploy(
      envORManagerAddress,
    );
    console.log('orSpvData.address:', orSpvData.address);

    await orSpvData.deployed();
  });

  it("ORSpvData's functions prefixed with _ should be private", async function () {
    for (const key in orSpvData.functions) {
      expect(key.replace(/^_/, '')).eq(key);
    }
  });

  it('Function  should success', async function () {});

  it('Function saveHistoryBlock should success', async function () {
    // Only hardhat local network
    await mine(1000);

    const receipt = await orSpvData.saveHistoryBlock().then((t) => t.wait());
    const events = receipt.events!;

    const blockInterval = (await orSpvData.getBlockInterval()).toNumber();

    for (let i = 256, ei = 0; i > 0; i--) {
      const blockNumber = receipt.blockNumber - i;
      if (blockNumber % blockInterval === 0) {
        expect(BigNumber.from(blockNumber)).to.deep.eq(
          events[ei].args?.['blockNumber'],
        );

        const blockHash = await orSpvData.getBlockHash(blockNumber);
        expect(BigNumber.from(blockHash)).not.deep.eq(BigNumber.from(0));

        ei++;
      }
    }
  });
});
