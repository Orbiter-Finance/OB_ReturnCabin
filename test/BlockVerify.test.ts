import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers, network } from 'hardhat';

import { expect } from 'chai';
import { BigNumber, utils } from 'ethers';
import { BaseTrie } from 'merkle-patricia-tree';
import { TestToken, TestToken__factory } from '../typechain-types';

// Warnning: This test does not take into account enough edge cases, it only applies to EIP1559 transactions of Hardhat network
describe('BlockVerify', () => {
  let signers: SignerWithAddress[];
  let testToken: TestToken;

  before(async function () {
    signers = await ethers.getSigners();

    // const value = utils.parseEther('0.001');
    // const sendTx = await signers[0].sendTransaction({
    //   to: signers[1].address,
    //   value,
    // });
    // await sendTx.wait();
    // console.warn('sendTx.hash:', sendTx.hash);

    // const _node = (network.provider as any)._wrapped._wrapped._wrapped._node;
    // const _vm = _node._vm;
    // console.warn('_vm:', _vm);
    // console.warn(
    //   '_vm._common._chainParams.genesis:',
    //   _vm._common._chainParams.genesis,
    // );

    // const tree = new BaseTrie();
    // console.warn('signers.length:', signers.length);

    // for (const signer of signers) {
    //   // const key = Buffer.from(utils.arrayify(utils.RLP.encode(signer.address)));
    //   const key = Buffer.from(utils.arrayify(signer.address));
    //   const nonce = await signer.getTransactionCount();
    //   const balance = await signer.getBalance();

    //   console.warn('signer.address:', signer.address);

    //   const accountEncode = utils.RLP.encode([
    //     utils.stripZeros(BigNumber.from(nonce).toHexString()),
    //     balance.toHexString(),
    //     new BaseTrie().root,
    //     utils.keccak256('0x'),
    //   ]);

    //   const value = Buffer.from(utils.arrayify(accountEncode));

    //   await tree.put(key, value);
    // }
    // console.warn('tree.root:', utils.hexlify(tree.root));

    // const block = await network.provider.send('eth_getBlockByNumber', [
    //   'latest',
    //   true,
    // ]);
    // console.warn('block:', block);

    testToken = await new TestToken__factory(signers[0]).deploy();
    await testToken.deployed();
    console.warn('testToken.address:', testToken.address);
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

      const txEncode = utils.RLP.encode(
        fields.map((f) => {
          if (f == 'accessList') return tx[f];

          // @ts-ignore
          if (tx[f] == '0x') return tx[f];

          // @ts-ignore
          return utils.stripZeros(BigNumber.from(tx[f]).toHexString());
        }),
      );

      const value = Buffer.from(
        utils.stripZeros(
          utils.hexConcat([BigNumber.from(tx.type).toHexString(), txEncode]),
        ),
      );

      expect(tx.hash).eq(utils.keccak256(value));

      const key = Buffer.from(
        utils.arrayify(
          utils.RLP.encode(
            utils.stripZeros(
              BigNumber.from(item.transactionIndex).toHexString(),
            ),
          ),
        ),
      );
      await tree.put(key, value);
    }

    expect(utils.hexlify(tree.root)).eq(block.transactionsRoot);
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

      const receiptEncode = utils.RLP.encode(
        fields.map((f) => {
          if (f == 'logs') {
            return _receipt[f].map((l) => [l.address, l.topics, l.data]);
          }
          if (f == 'logsBloom') return _receipt[f];

          // @ts-ignore
          if (_receipt[f] == '0x') return _receipt[f];

          // @ts-ignore
          return utils.stripZeros(BigNumber.from(_receipt[f]).toHexString());
        }),
      );

      const value = Buffer.from(
        utils.stripZeros(
          utils.hexConcat([
            BigNumber.from(_receipt.type).toHexString(),
            receiptEncode,
          ]),
        ),
      );

      const key = Buffer.from(
        utils.arrayify(
          utils.RLP.encode(
            utils.stripZeros(
              BigNumber.from(item.transactionIndex).toHexString(),
            ),
          ),
        ),
      );

      await tree.put(key, value);
    }

    expect(utils.hexlify(tree.root)).eq(block.receiptsRoot);
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

    const blockEncode = utils.RLP.encode(
      fields.map((f) => {
        if (f == 'logsBloom') return block[f];
        if (f == 'nonce') return block[f];

        // @ts-ignore
        if (block[f] == '0x') return block[f];

        // @ts-ignore
        return utils.stripZeros(BigNumber.from(block[f]).toHexString());
      }),
    );

    const blockHash = utils.keccak256(blockEncode);
    expect(blockHash).eq(block.hash);
  });
});
