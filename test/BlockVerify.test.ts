import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers, network } from 'hardhat';

import { TestToken, TestToken__factory } from '../typechain-types';
import { BigNumber, constants, utils } from 'ethers';
import { BaseTrie } from 'merkle-patricia-tree';
import { Account, BN } from 'ethereumjs-util';
import { expect } from 'chai';

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

    // const tree = new BaseTrie();
    // for (const signer of signers) {
    //   // const key = Buffer.from(utils.arrayify(utils.RLP.encode(signer.address)));
    //   const key = Buffer.from(utils.arrayify(signer.address));
    //   const nonce = await signer.getTransactionCount();
    //   const balance = await signer.getBalance();

    //   const account = new Account(
    //     new BN(BigNumber.from(nonce) + ''),
    //     new BN(BigNumber.from(balance) + ''),
    //   );

    //   await tree.put(key, account.serialize());
    // }
    // console.warn('tree.root:', utils.hexlify(tree.root));

    // const block = await network.provider.send('eth_getBlockByNumber', [
    //   'latest',
    //   true,
    // ]);
    // console.warn('block:', block);

    testToken = await new TestToken__factory(signers[0]).deploy();
    await testToken.deployed();

    // console.warn('testToken.address:', testToken.address);

    // const block2 = await network.provider.send('eth_getBlockByNumber', [
    //   'latest',
    //   true,
    // ]);
    // console.warn('block2:', block2);
  });

  it('TransactionsRoot should be calculated correctly', async function () {
    const receipt = await signers[0]
      .sendTransaction({
        to: signers[1].address,
        value: '100',
      })
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

    console.warn('block:', block);
  });

  it('ReceiptsRoot should be calculated correctly', async function () {
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

      const receipt = await signers[0].provider?.getTransactionReceipt(
        item.hash,
      );
      console.warn('receipt:', receipt);

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

    console.warn('block:', block);
  });
});
