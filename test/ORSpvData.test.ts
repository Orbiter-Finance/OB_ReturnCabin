import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers, network } from 'hardhat';

import { assert, expect } from 'chai';
import { ORSpvData, ORSpvData__factory } from '../typechain-types';
import { mine } from '@nomicfoundation/hardhat-network-helpers';

describe('ORSpvData', () => {
  let signers: SignerWithAddress[];
  let orSpvData: ORSpvData;

  before(async function () {
    signers = await ethers.getSigners();

    const envORManagerAddress = process.env['OR_MANAGER_ADDRESS'];
    console.log('envORManagerAddress:', envORManagerAddress);
    assert(
      !!envORManagerAddress,
      'Env miss [OR_MANAGER_ADDRESS]. You may need to test ORManager.test.ts first. Example: npx hardhat test test/ORManager.test.ts test/ORSpvData.test.ts',
    );

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

  it('Function saveHistoryBlock should success', async function () {
    // Only hardhat local network
    await mine(1000);

    const receipt = await orSpvData.saveHistoryBlock().then((t) => t.wait());
    const events = receipt.events!;

    receipt.blockNumber;

    console.warn('events2:', events);
  });
});
