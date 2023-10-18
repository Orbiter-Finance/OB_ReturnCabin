import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';

import { mine } from '@nomicfoundation/hardhat-network-helpers';
import { assert, expect } from 'chai';
import {
  IORSpvData,
  ORManager,
  ORManager__factory,
  ORSpvData,
  ORSpvData__factory,
} from '../typechain-types';
import { BigNumber } from 'ethers';
import { testReverted, testRevertedOwner } from './utils.test';
import { id } from 'ethers/lib/utils';

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

  it('Function orManager.updateSpvDataContract should success', async function () {
    const events = (
      await orManager
        .updateSpvDataContract(orSpvData.address)
        .then((t) => t.wait())
    ).events!;

    const args = events[0].args!;
    expect(args.spvDataContract).to.deep.eq(orSpvData.address);
  });

  it('Function orManager.updateSpvBlockInterval should success', async function () {
    const spvBlockInterval = BigNumber.from(40);

    await testRevertedOwner(
      orManager.connect(signers[2]).updateSpvBlockInterval(spvBlockInterval),
    );
    await testReverted(
      orSpvData.updateBlockInterval(spvBlockInterval),
      'Forbidden: caller is not the manager',
    );

    const events = (
      await orManager
        .updateSpvBlockInterval(spvBlockInterval)
        .then((t) => t.wait())
    ).events!;

    // Cross contract events do not automatically parse parameters
    expect(BigNumber.from(events[0].data)).to.deep.eq(spvBlockInterval);

    const storageValue = await orSpvData.getBlockInterval();
    expect(storageValue).to.deep.eq(spvBlockInterval);
  });

  it('Function saveHistoryBlocks should success', async function () {
    // Only hardhat local network
    await mine(1000);

    const receipt = await orSpvData.saveHistoryBlocks().then((t) => t.wait());
    const events = receipt.events!;

    const blockInterval = await orSpvData.getBlockInterval();

    for (let i = 256, ei = 0; i > 0; i--) {
      const blockNumber = receipt.blockNumber - i;
      if (blockNumber % blockInterval.toNumber() === 0) {
        expect(BigNumber.from(blockNumber)).to.deep.eq(
          events[ei].args?.['blockNumber'],
        );

        const blockHash = await orSpvData.getBlockHash(blockNumber);
        expect(BigNumber.from(blockHash)).not.deep.eq(BigNumber.from(0));

        ei++;
      }
    }
  });

  it('A', async function () {
    const eventHistoryBlockSavedKey = id('HistoryBlockSaved(uint256,bytes32)');

    const blockInterval = await orSpvData.getBlockInterval();

    const startBlockNumber = BigNumber.from(
      (
        await orSpvData.provider.getLogs({
          address: orSpvData.address,
          fromBlock: 0,
          toBlock: 'latest',
          topics: [eventHistoryBlockSavedKey],
        })
      ).pop()?.topics[1],
    );

    await testRevertedOwner(
      orManager
        .connect(signers[2])
        .injectSpvBlocks(
          startBlockNumber.sub(blockInterval),
          startBlockNumber,
          [],
        ),
    );
    await testReverted(
      orSpvData.injectBlocksByManager(
        startBlockNumber.sub(blockInterval),
        startBlockNumber,
        [],
      ),
      'Forbidden: caller is not the manager',
    );
    await testReverted(
      orManager.injectSpvBlocks(startBlockNumber, startBlockNumber, []),
      'SNLE',
    );
    await testReverted(
      orManager.injectSpvBlocks(startBlockNumber.add(1), startBlockNumber, []),
      'SNLE',
    );
    await testReverted(
      orManager.injectSpvBlocks(
        startBlockNumber.sub(blockInterval.sub(1)),
        startBlockNumber,
        [],
      ),
      'SZ',
    );
    await testReverted(
      orManager.injectSpvBlocks(
        startBlockNumber,
        startBlockNumber.add(blockInterval.sub(1)),
        [],
      ),
      'EZ',
    );

    // Only hardhat local network
    await mine(1000);

    await orSpvData.saveHistoryBlocks().then((t) => t.wait());

    const endBlock = (
      await orSpvData.provider.getLogs({
        address: orSpvData.address,
        fromBlock: startBlockNumber.add(1000).toHexString(),
        toBlock: 'latest',
        topics: [eventHistoryBlockSavedKey],
      })
    ).shift();
    const endBlockNumber = BigNumber.from(endBlock?.topics[1]);
    const endBlockHash = endBlock?.data!;

    const injectionBlocks: IORSpvData.InjectionBlockStruct[] = [];
    for (let i = 0; i < 2; i++) {
      const _blockNumber = startBlockNumber.add(blockInterval.mul(i + 1));
      const _blockHash = (
        await orSpvData.provider.getBlock(_blockNumber.toHexString())
      ).hash;
      injectionBlocks.push({
        blockNumber: _blockNumber,
        blockHash: _blockHash,
      });
    }

    await testReverted(
      orManager.injectSpvBlocks(
        endBlockNumber,
        endBlockNumber.add(blockInterval),
        injectionBlocks,
      ),
      'SGEIB',
    );
    await testReverted(
      orManager.injectSpvBlocks(
        startBlockNumber,
        endBlockNumber,
        injectionBlocks.concat([
          {
            blockNumber: endBlockNumber.toNumber(),
            blockHash: endBlockHash,
          },
        ]),
      ),
      'ELEIB',
    );
  });
});
