import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers, network } from 'hardhat';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import {
  RLP,
  arrayify,
  hexConcat,
  hexZeroPad,
  hexlify,
  keccak256,
  stripZeros,
  zeroPad,
} from 'ethers/lib/utils';
import { BaseTrie } from 'merkle-patricia-tree';
import { TestToken, TestToken__factory } from '../typechain-types';

async function getTestTokenStroageRoot(
  testToken: TestToken,
  holders: string[],
) {
  const provider = testToken.provider;
  const address = testToken.address;

  const tree = new BaseTrie();

  for (const holder of holders) {
    const storageKey = keccak256(
      hexConcat([hexZeroPad(holder, 32), hexZeroPad('0x00', 32)]),
    );
    const storageValue = await provider.getStorageAt(address, storageKey);

    const key = Buffer.from(arrayify(keccak256(storageKey)));
    const value = Buffer.from(arrayify(RLP.encode(stripZeros(storageValue))));

    await tree.put(key, value);
  }

  {
    const storageKey = '0x01';
    const storageValue = await provider.getStorageAt(address, storageKey);
    console.warn('storageValue1:', storageValue);
    const key = Buffer.from(arrayify(keccak256(storageKey)));
    const value = Buffer.from(arrayify(RLP.encode(stripZeros(storageValue))));
    await tree.put(key, value);
  }

  {
    const storageKey = '0x02';
    const storageValue = await provider.getStorageAt(address, storageKey);
    console.warn('storageValue1:', storageValue);
    const key = Buffer.from(arrayify(keccak256(storageKey)));
    const value = Buffer.from(arrayify(RLP.encode(stripZeros(storageValue))));
    await tree.put(key, value);
  }

  // const storageKey3 = '0x03';
  // const storageValue3 = await provider.getStorageAt(address, storageKey3);
  // const key3 = Buffer.from(arrayify(keccak256(storageKey3)));
  // const value3 = Buffer.from(arrayify(RLP.encode(stripZeros(storageValue3))));
  // await tree.put(key3, value3);

  // const storageKey4 = '0x04';
  // const storageValue4 = await provider.getStorageAt(address, storageKey4);
  // const key4 = Buffer.from(arrayify(keccak256(storageKey4)));
  // const value4 = Buffer.from(arrayify(RLP.encode(stripZeros(storageValue4))));
  // await tree.put(key4, value4);

  console.warn('erc20 stroage root:', hexlify(tree.root));

  return hexlify(tree.root);
}

// Warnning: This test does not take into account enough edge cases, it only applies to EIP1559 transactions of Hardhat network
describe('BlockVerify', () => {
  let signers: SignerWithAddress[];
  let testToken: TestToken;

  before(async function () {
    signers = await ethers.getSigners();

    const tree = new BaseTrie();

    for (const signer of signers) {
      const key = Buffer.from(arrayify(keccak256(signer.address)));
      const nonce = await signer.getTransactionCount();
      const balance = await signer.getBalance();

      const accountEncode = RLP.encode([
        stripZeros(BigNumber.from(nonce).toHexString()),
        balance.toHexString(),
        new BaseTrie().root,
        keccak256('0x'),
      ]);

      const value = Buffer.from(arrayify(accountEncode));

      await tree.put(key, value);
    }

    // Hardhat-network fill 8 empty account
    for (let i = 1; i <= 8; i++) {
      const address = zeroPad(BigNumber.from(i).toHexString(), 20);
      const emptyAccountEncode = RLP.encode([
        '0x',
        '0x',
        new BaseTrie().root,
        keccak256('0x'),
      ]);

      const key = Buffer.from(arrayify(keccak256(address)));
      const value = Buffer.from(arrayify(emptyAccountEncode));
      await tree.put(key, value);
    }

    testToken = await new TestToken__factory(signers[0]).deploy();
    await testToken.deployed();
    console.warn('testToken.address:', testToken.address);

    const code = await signers[0].provider?.getCode(testToken.address);
    const testTokenStroageRoot = await getTestTokenStroageRoot(testToken, [
      signers[0].address,
    ]);
    const testTokenAccount = RLP.encode([
      '0x01',
      '0x',
      testTokenStroageRoot,
      keccak256(code || '0x'),
    ]);
    const key = Buffer.from(arrayify(keccak256(testToken.address)));
    const value = Buffer.from(arrayify(testTokenAccount));
    await tree.put(key, value);

    {
      const key1 = Buffer.from(arrayify(keccak256(signers[0].address)));
      const nonce1 = await signers[0].getTransactionCount();
      const balance1 = await signers[0].getBalance();
      const accountEncode1 = RLP.encode([
        stripZeros(BigNumber.from(nonce1).toHexString()),
        balance1.toHexString(),
        new BaseTrie().root,
        keccak256('0x'),
      ]);
      const value1 = Buffer.from(arrayify(accountEncode1));
      await tree.put(key1, value1);
    }

    const block = await network.provider.send('eth_getBlockByNumber', [
      'latest',
      true,
    ]);
    console.warn('block.stateRoot:', block.stateRoot);

    {
      const key2 = Buffer.from(arrayify(keccak256(block.miner)));
      const nonce2 = await signers[0].provider?.getTransactionCount(
        block.miner,
      );
      const balance2 = await signers[0].provider?.getBalance(block.miner);
      const accountEncode2 = RLP.encode([
        stripZeros(BigNumber.from(nonce2).toHexString()),
        balance2?.toHexString() || '0x',
        new BaseTrie().root,
        keccak256('0x'),
      ]);
      const value2 = Buffer.from(arrayify(accountEncode2));
      await tree.put(key2, value2);
    }

    console.warn('root:', hexlify(tree.root));

    process.exit(0);
  });

  it('TransactionsRoot should be calculated correctly', async function () {
    const receipt = await testToken
      .transfer(signers[1].address, '100')
      .then((t) => t.wait());

    const block = await network.provider.send('eth_getBlockByHash', [
      receipt.blockHash,
      true,
    ]);

    const tree = new BaseTrie();

    const fields = [
      'chainId',
      'nonce',
      'maxPriorityFeePerGas',
      'maxFeePerGas',
      'gasLimit',
      'to',
      'value',
      'data',
      'accessList',
      'v',
      'r',
      's',
    ];
    for (const item of block.transactions) {
      const tx = await signers[0].provider?.getTransaction(item.hash);
      if (!tx) continue;

      const txEncode = RLP.encode(
        fields.map((f) => {
          if (f == 'accessList') return tx[f];

          // @ts-ignore
          if (tx[f] == '0x') return tx[f];

          // @ts-ignore
          return stripZeros(BigNumber.from(tx[f]).toHexString());
        }),
      );

      const value = Buffer.from(
        stripZeros(
          hexConcat([BigNumber.from(tx.type).toHexString(), txEncode]),
        ),
      );

      expect(tx.hash).eq(keccak256(value));

      const key = Buffer.from(
        arrayify(
          RLP.encode(
            stripZeros(BigNumber.from(item.transactionIndex).toHexString()),
          ),
        ),
      );
      await tree.put(key, value);
    }

    expect(hexlify(tree.root)).eq(block.transactionsRoot);
  });

  it('ReceiptsRoot should be calculated correctly', async function () {
    const block = await network.provider.send('eth_getBlockByNumber', [
      'latest',
      true,
    ]);

    const tree = new BaseTrie();

    const fields = ['status', 'cumulativeGasUsed', 'logsBloom', 'logs'];
    for (const item of block.transactions) {
      const _receipt = await signers[0].provider?.getTransactionReceipt(
        item.hash,
      );
      if (!_receipt) continue;

      const receiptEncode = RLP.encode(
        fields.map((f) => {
          if (f == 'logs') {
            return _receipt[f].map((l) => [l.address, l.topics, l.data]);
          }
          if (f == 'logsBloom') return _receipt[f];

          // @ts-ignore
          if (_receipt[f] == '0x') return _receipt[f];

          // @ts-ignore
          return stripZeros(BigNumber.from(_receipt[f]).toHexString());
        }),
      );

      const value = Buffer.from(
        stripZeros(
          hexConcat([
            BigNumber.from(_receipt.type).toHexString(),
            receiptEncode,
          ]),
        ),
      );

      const key = Buffer.from(
        arrayify(
          RLP.encode(
            stripZeros(BigNumber.from(item.transactionIndex).toHexString()),
          ),
        ),
      );

      await tree.put(key, value);
    }

    expect(hexlify(tree.root)).eq(block.receiptsRoot);
  });

  it("Block's hash should be calculated correctly", async function () {
    const block = await network.provider.send('eth_getBlockByNumber', [
      'latest',
      true,
    ]);

    const fields = [
      'parentHash',
      'sha3Uncles',
      'miner',
      'stateRoot',
      'transactionsRoot',
      'receiptsRoot',
      'logsBloom',
      'difficulty',
      'number',
      'gasLimit',
      'gasUsed',
      'timestamp',
      'extraData',
      'mixHash',
      'nonce',
      'baseFeePerGas',
      'withdrawalsRoot',
    ];

    const blockEncode = RLP.encode(
      fields.map((f) => {
        if (f == 'logsBloom') return block[f];
        if (f == 'nonce') return block[f];

        // @ts-ignore
        if (block[f] == '0x') return block[f];

        // @ts-ignore
        return stripZeros(BigNumber.from(block[f]).toHexString());
      }),
    );

    const blockHash = keccak256(blockEncode);
    expect(blockHash).eq(block.hash);
  });
});
