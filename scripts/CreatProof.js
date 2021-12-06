const { keccak, encode, toBuffer } = require('eth-util-lite')
const { promisfy } = require('promisfy')

const { BaseTrie } = require('merkle-patricia-tree')

const Rpc = require('isomorphic-rpc')

const { Header, Proof, Transaction } = require('eth-object')

// import * as fs from 'fs';
const fs = require('fs')

class GetProof {
  constructor(rpcProvider = 'https://mainnet.infura.io') {
    this.rpc = new Rpc(rpcProvider)
    this.eth_getProof = this.rpc.eth_getProof
  }

  async transactionProof(txHash) {
    // get transcation data
    let targetTx = await this.rpc.eth_getTransactionByHash(txHash)
    if (!targetTx) {
      throw new Error('Tx not found. Use archive node')
    }
    let rpcBlock = await this.rpc.eth_getBlockByHash(targetTx.blockHash, true)

    console.log(rpcBlock)

    let tree = new BaseTrie()

    await Promise.all(
      rpcBlock.transactions.map((siblingTx, index) => {
        let siblingPath = encode(index)
        let serializedSiblingTx = Transaction.fromRpc(siblingTx).serialize()
        return promisfy(tree.put, tree)(siblingPath, serializedSiblingTx)
      }),
    )

    let [_, __, stack] = await promisfy(
      tree.findPath,
      tree,
    )(encode(targetTx.transactionIndex))

    return {
      header: Header.fromRpc(rpcBlock),
      txProof: Proof.fromStack(stack),
      txIndex: targetTx.transactionIndex,
    }
  }

  async transactionProof_mod(filePath, index) {
    let rpcBlock = JSON.parse(fs.readFileSync(filePath)).result

    // console.log(filePath)
    // console.log(rpcBlock)

    // let targetTx = rpcBlock.transactions[index]
    // console.log(targetTx)

    let tree = new BaseTrie()

    await Promise.all(
      rpcBlock.transactions.map((siblingTx, index) => {
        let siblingPath = encode(index)
        if (index == 0) {
          console.log(siblingTx)
          console.log('bb', Transaction.fromRpc(siblingTx))
        }
        let serializedSiblingTx = Transaction.fromRpc(siblingTx).serialize()
        if (index == 0) {
          console.log('serializedSiblingTx', serializedSiblingTx)
        }
        return promisfy(tree.put, tree)(siblingPath, serializedSiblingTx)
      }),
    )

    let [_, __, stack] = await promisfy(tree.findPath, tree)(encode(index))

    // console.log(Header.fromRpc(rpcBlock))
    return {
      header: Header.fromRpc(rpcBlock),
      txProof: Proof.fromStack(stack),
      txIndex: index,
    }
  }
}

const TXS_ROOT_INDEX = 4 // within header

class VerifyProof {
  static getBlockHashFromHeader(header) {
    // console.log(header)
    // console.log(encode(header))
    // console.log(keccak(encode(header)))
    return keccak(encode(header))
  }
  static getTxsRootFromHeader(header) {
    // console.log(header)
    return this.getElemFromHeaderAt(header, TXS_ROOT_INDEX)
  }
  static getElemFromHeaderAt(header, indexOfRoot) {
    return header[indexOfRoot]
  }
  static getRootFromProof(proof) {
    return keccak(encode(proof[0]))
  }

  static async getTxFromTxProofAt(proof, indexOfTx) {
    let txBuffer = await this.proofContainsValueAt(proof, encode(indexOfTx))
    // console.log(txBuffer)
    return Transaction.fromBuffer(txBuffer)
  }
  static async proofContainsValueAt(proof, path) {
    return new Promise((accept, reject) => {
      let encodedProof = []
      for (let i = 0; i < proof.length; i++) {
        encodedProof.push(encode(proof[i]))
      }
      //   console.log(encodedProof)
      Trie.verifyProof(
        toBuffer(this.getRootFromProof(proof)),
        path,
        encodedProof,
        (e, r) => {
          if (e) {
            return reject(e)
          } else {
            return accept(r)
          }
        },
      )
    })
  }
}

class GetAndVerify {
  constructor(rpcProvider = 'https://mainnet.infura.io') {
    this.get = new GetProof(rpcProvider)
  }

  async txAgainstBlockHash(txHash, trustedBlockHash) {
    let resp = await this.get.transactionProof(txHash)
    let blockHashFromHeader = VerifyProof.getBlockHashFromHeader(resp.header)
    if (!toBuffer(trustedBlockHash).equals(blockHashFromHeader))
      throw new Error('BlockHash mismatch')
    let txRootFromHeader = VerifyProof.getTxsRootFromHeader(resp.header)
    let txRootFromProof = VerifyProof.getRootFromProof(resp.txProof)
    if (!txRootFromHeader.equals(txRootFromProof))
      throw new Error('TxRoot mismatch')
    return VerifyProof.getTxFromTxProofAt(resp.txProof, resp.txIndex)
  }
}

////////////////////////////////////////////////////////////////
//test
////////////////////////////////////////////////////////////////

async function test_transactionProof_mod() {
  // console.log('ddd')
  let getProof = new GetProof(
    'https://mainnet.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad',
  )
  // getProof.transactionProof_mod('/Users/hwb/Documents/code/WorkSpace_0xbb/orbiter-v2-contract/test/BlockJsonFile/0x0b963d785005ee2d25cb078daba5dd5cae1b376707ac53533d8ad638f9cb9659.json',2).then((tx)=>{
  //     // // console.log(tx["header"][14].toString('hex'))
  //     // console.log(tx)
  // });

  // let resp = await getProof.transactionProof_mod('/Users/hwb/Documents/code/WorkSpace_0xbb/orbiter-v2-contract/test/BlockJsonFile/0x0b963d785005ee2d25cb078daba5dd5cae1b376707ac53533d8ad638f9cb9659.json',2)
  // let trustedBlockHash = "0x0b963d785005ee2d25cb078daba5dd5cae1b376707ac53533d8ad638f9cb9659"
  // console.log("resp",resp)
  // console.log("resp.head",resp.header)

  // blocknumber: 13415559
  let resp = await getProof.transactionProof_mod(
    '/Users/hwb/Documents/code/WorkSpace_0xbb/orbiter-v2-contract/test/BlockJsonFile/block_13415559.json',
    2,
  )
  let trustedBlockHash =
    '0x155f785ea11b9e527ae4af0c9ea222157197b31ea766609b4d587b2402606335'

  let blockHashFromHeader = VerifyProof.getBlockHashFromHeader(resp.header)
  console.log('resp.header', resp.header)
  console.log('blockHashFromHeader', blockHashFromHeader)
  console.log('trustedBlockHash', trustedBlockHash)
  if (!toBuffer(trustedBlockHash).equals(blockHashFromHeader))
    throw new Error('BlockHash mismatch')
  // console.log(trustedBlockHash, blockHashFromHeader)

  let txRootFromHeader = VerifyProof.getTxsRootFromHeader(resp.header)
  let txRootFromProof = VerifyProof.getRootFromProof(resp.txProof)

  console.log(txRootFromHeader, txRootFromProof)

  if (!txRootFromHeader.equals(txRootFromProof))
    throw new Error('TxRoot mismatch')

  let fff = await VerifyProof.getTxFromTxProofAt(resp.txProof, resp.txIndex)
  // console.log(fff)
  return fff
}

async function test_getProof() {
  getProof
    .transactionProof(
      '0x6760c6de4a5969e3f1830ead616519a19a96653e9e71e1a5bc49dcdbefd86b63',
    )
    .then((tx) => {
      // // console.log(tx)
      // console.log(tx["header"][14].toString('hex'))
      // // console.log(VerifyProof.getStateRootFromHeader(tx["header"]).toString('hex'))
    })
}

async function test_ProofAndVerify() {
  let pv = new GetAndVerify(
    'https://mainnet.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad',
  )
  // let tx = pv.txAgainstBlockHash(
  //     "0xde83b34f13c9d60223279d7482299dd7a113089389015fc3eaa2f1f17acc02bf",
  //     "0x0b963d785005ee2d25cb078daba5dd5cae1b376707ac53533d8ad638f9cb9659")

  // blockNumber: 13415559
  let tx = pv.txAgainstBlockHash(
    '0xb8d9f0e212d7d59e992007f8e60feb27d367bc466ff99b9ea00fd394cf7bad93',
    '0x155f785ea11b9e527ae4af0c9ea222157197b31ea766609b4d587b2402606335',
  )

  console.log(tx)
}

async function test() {
  // console.log("test hello world")
}

async function main() {
  // test_ProofAndVerify()
  test_transactionProof_mod()
}

// main()
//     .then(() => process.exit(0))
//     .catch((error) => {
//         // console.error(error);
//         process.exit(1);
// });
main()
