import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';

import { mine, mineUpTo } from '@nomicfoundation/hardhat-network-helpers';
import { assert, expect } from 'chai';
import {
  IORSpvData,
  ORManager,
  ORManager__factory,
  ORSpvData,
  ORSpvData__factory,
} from '../typechain-types';
import { BigNumber, BigNumberish } from 'ethers';
import { testReverted, testRevertedOwner } from './utils.test';
import { defaultAbiCoder, id, keccak256 } from 'ethers/lib/utils';
import { MerkleTree } from 'merkletreejs';

describe('ORSpvData', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  let orSpvData: ORSpvData;
  let injectOwner: SignerWithAddress;

  const _calculateMerkleTree = async (
    startBlockNumber: BigNumberish,
    blockInterval: number,
  ) => {
    const leaves = await Promise.all(
      new Array(blockInterval)
        .fill(undefined)
        .map((_, index) =>
          orSpvData.provider
            .getBlock(BigNumber.from(startBlockNumber).add(index).toHexString())
            .then((b) => b.hash),
        ),
    );
    return new MerkleTree(leaves, keccak256);
  };

  before(async function () {
    signers = await ethers.getSigners();
    injectOwner = signers[3];

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

  it('Test ORManager.updateSpvBlockInterval should success', async function () {
    const spvBlockInterval = 200;

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

    const storageValue = await orSpvData.blockInterval();
    expect(storageValue).to.deep.eq(spvBlockInterval);
  });

  it('Function saveHistoryBlocksRoots should success', async function () {
    // Only hardhat local network
    await mineUpTo(1200);

    const receipt = await orSpvData
      .saveHistoryBlocksRoots()
      .then((t) => t.wait());
    const events = receipt.events!;
    const currentBlockNumber = receipt.blockNumber;

    const blockInterval = (await orSpvData.blockInterval()).toNumber();

    for (let i = 256, ei = 0; i > 0; i--) {
      const startBlockNumber = currentBlockNumber - i;
      if (
        startBlockNumber % blockInterval === 0 &&
        startBlockNumber + blockInterval < currentBlockNumber
      ) {
        expect(BigNumber.from(startBlockNumber)).to.deep.eq(
          events[ei].args?.['startBlockNumber'],
        );

        // Calculate block's hash root
        const merkleTree = await _calculateMerkleTree(
          startBlockNumber,
          blockInterval,
        );

        const blockHash = await orSpvData.getBlocksRoot(startBlockNumber);
        expect(BigNumber.from(blockHash)).to.eq(
          BigNumber.from(merkleTree.getHexRoot()),
        );

        ei++;
      }
    }
  });

  it('Test ORManager.updateSpvDataInjectOwner should success', async function () {
    await testRevertedOwner(
      orManager
        .connect(signers[2])
        .updateSpvDataInjectOwner(injectOwner.address),
    );
    await testReverted(
      orSpvData.updateInjectOwner(injectOwner.address),
      'Forbidden: caller is not the manager',
    );

    const events = (
      await orManager
        .updateSpvDataInjectOwner(injectOwner.address)
        .then((t) => t.wait())
    ).events!;

    // Cross contract events do not automatically parse parameters
    expect(BigNumber.from(events[0].data)).to.deep.eq(injectOwner.address);

    const storageValue = await orSpvData.injectOwner();
    expect(storageValue).to.deep.eq(injectOwner.address);
  });

  it('Function injectBlocksRoots should success', async function () {
    const eventHistoryBlockSavedKey = id(
      'HistoryBlocksRootSaved(uint256,bytes32,uint256)',
    );
    const blockInterval = (await orSpvData.blockInterval()).toNumber();
    const block0 = (
      await orSpvData.provider.getLogs({
        address: orSpvData.address,
        fromBlock: 0,
        toBlock: 'latest',
        topics: [eventHistoryBlockSavedKey],
      })
    ).pop();
    const blockNumber0 = BigNumber.from(block0?.topics[1]);
    const [blocksRoot0] = defaultAbiCoder.decode(
      ['bytes32', 'uint256'],
      block0?.data!,
    );

    await testReverted(
      orSpvData.injectBlocksRoots(
        blockNumber0.sub(blockInterval),
        blockNumber0,
        [],
      ),
      'Forbidden: caller is not the inject owner',
    );

    const connectedORSpvData = orSpvData.connect(injectOwner);

    await testReverted(
      connectedORSpvData.injectBlocksRoots(blockNumber0, blockNumber0, []),
      'SNLE',
    );
    await testReverted(
      connectedORSpvData.injectBlocksRoots(
        blockNumber0.add(1),
        blockNumber0,
        [],
      ),
      'SNLE',
    );
    await testReverted(
      connectedORSpvData.injectBlocksRoots(
        blockNumber0.sub(blockInterval - 1),
        blockNumber0,
        [],
      ),
      'SZ',
    );
    await testReverted(
      connectedORSpvData.injectBlocksRoots(
        blockNumber0,
        blockNumber0.add(blockInterval - 1),
        [],
      ),
      'EZ',
    );

    // Only hardhat local network
    const mineBlockNumber = blockInterval * 5;
    await mine(mineBlockNumber);

    await orSpvData.saveHistoryBlocksRoots().then((t) => t.wait());
    const block1 = (
      await orSpvData.provider.getLogs({
        address: orSpvData.address,
        fromBlock: blockNumber0.add(mineBlockNumber).toHexString(),
        toBlock: 'latest',
        topics: [eventHistoryBlockSavedKey],
      })
    ).shift();
    const blockNumber1 = BigNumber.from(block1?.topics[1]);
    const [blocksRoot1] = defaultAbiCoder.decode(
      ['bytes32', 'uint256'],
      block1?.data!,
    );
    const injectionBlocksRoots: IORSpvData.InjectionBlocksRootStruct[] = [];
    for (let i = 0; i < 2; i++) {
      const _blockNumber = blockNumber0.add(blockInterval * (i + 1));
      const merkleTree = await _calculateMerkleTree(
        blockNumber0,
        blockInterval,
      );

      injectionBlocksRoots.push({
        startBlockNumber: _blockNumber,
        blocksRoot: merkleTree.getHexRoot(),
      });
    }
    await testReverted(
      connectedORSpvData.injectBlocksRoots(blockNumber0, blockNumber1, [
        {
          startBlockNumber: blockNumber0,
          blocksRoot: blocksRoot0,
        },
      ]),
      'IBLE0',
    );
    await testReverted(
      connectedORSpvData.injectBlocksRoots(blockNumber0, blockNumber1, [
        {
          startBlockNumber: blockNumber1,
          blocksRoot: blocksRoot1,
        },
      ]),
      'IBGE1',
    );
    await testReverted(
      connectedORSpvData.injectBlocksRoots(blockNumber0, blockNumber1, [
        {
          startBlockNumber: blockNumber0.add(1),
          blocksRoot: injectionBlocksRoots[0].blocksRoot,
        },
      ]),
      'IIB',
    );

    console.log('Length of injectionBlocksRoots:', injectionBlocksRoots.length);

    const events = (
      await connectedORSpvData
        .injectBlocksRoots(blockNumber0, blockNumber1, injectionBlocksRoots)
        .then((t) => t.wait())
    ).events!;
    for (let i = 0; i < injectionBlocksRoots.length; i++) {
      expect(BigNumber.from(events[i].topics[1])).to.deep.eq(
        injectionBlocksRoots[i].startBlockNumber,
      );

      const [_blocksRoot] = defaultAbiCoder.decode(
        ['bytes32', 'uint256'],
        events[i].data,
      );
      expect(BigNumber.from(_blocksRoot)).to.deep.eq(
        BigNumber.from(injectionBlocksRoots[i].blocksRoot),
      );

      const _blockHash = await orSpvData.getBlocksRoot(
        injectionBlocksRoots[i].startBlockNumber,
      );
      expect(BigNumber.from(_blockHash)).not.deep.eq(BigNumber.from(0));
    }

    await testReverted(
      connectedORSpvData.injectBlocksRoots(
        blockNumber0,
        blockNumber1,
        injectionBlocksRoots,
      ),
      'BE',
    );
  });
});
