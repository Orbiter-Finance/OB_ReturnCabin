const { rlp } = require('ethereumjs-util')
// const { Block } = require('@ethereumjs/block')
// const Trie = require('merkle-patricia-tree').SecureTrie
const blockFromRpc = require('@ethereumjs/block/dist/from-rpc').default

const Common = require('@ethereumjs/common').default

const fs = require('fs')

const common = new Common({
  chain: 'mainnet',
  hardfork: 'london',
  eips: [1559, 2718, 2930],
})

async function createProof(stack) {
  const p = stack.map((stackElem) => {
    return stackElem.serialize()
  })
  return p
}

async function transactionProof_mod(filePath, index) {
  let rpcBlock = JSON.parse(fs.readFileSync(filePath)).result

  let abc = blockFromRpc(rpcBlock, [], { common })

  await abc.validateTransactionsTrie()
  let proofpath = await abc.txTrie.findPath(rlp.encode(index))
  let raw = abc.header.raw()
  let txinfo = abc.transactions[index]
  let proofwithMyfunc = await createProof(proofpath.stack)

  let raw_rlp = rlp.encode(raw)
  let blockHash = abc.hash()
  let txRootHash = abc.header.transactionsTrie
  let newHeader = [blockHash, txRootHash, raw_rlp]
  return {
    txinfoRLP: txinfo.serialize(),
    proof: proofwithMyfunc,
    header: newHeader,
    rlpIndex: rlp.encode(3),
  }
}

module.exports = async function () {
  let data = await transactionProof_mod(
    '/Users/zhouxy/work/project/orbiter/project/contract/V2-contracts/test/BlockJsonFile/block_13415559.json',
    3,
  )
  return data
}
