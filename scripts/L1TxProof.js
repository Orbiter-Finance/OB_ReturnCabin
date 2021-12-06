const { keccak, encode, toBuffer } = require('eth-util-lite')
const { Block } = require('@ethereumjs/block')
const { BaseTrie } = require('merkle-patricia-tree')
const blockFromRpc = require('@ethereumjs/block/dist/from-rpc').default

// import { Block, BlockHeader } from '@ethereumjs/block'
const Common = require('@ethereumjs/common').default

const fs = require('fs')

const common = new Common({
  chain: 'mainnet',
  hardfork: 'london',
  eips: [1559, 2718, 2930],
})

async function transactionProof_mod(filePath, index) {
  let rpcBlock = JSON.parse(fs.readFileSync(filePath)).result

  // // console.log(filePath)
  // console.log(rpcBlock.transactions[0])

  // let targetTx = rpcBlock.transactions[index]
  // console.log(targetTx)
  // console.log(common)
  let abc = blockFromRpc(rpcBlock, [], { common })

  await abc.validateTransactionsTrie()

  let proof = await BaseTrie.createProof(abc.txTrie, encode(index))

  // console.log("proof",proof)

  // abc.validateTransactionsTrie().then((tx)=>{
  //     // console.log(tx)
  //     // console.log(abc.txTrie.root)
  //     // console.log(abc.header.transactionsTrie)
  //     abc.txTrie.findPath(encode(index)).then((dc)=>{
  //         // let [_,__,stack] = dc
  //         // console.log(dc)
  //         // console.log(dc.stack)
  //         // console.log(dc.stack[0]['_branches'])
  //         // console.log("abc",keccak(encode(dc.stack[0]["_branches"])))
  //         // console.log(stack)
  //         BaseTrie.createProof(abc.txTrie,encode(index)).then((nnn)=>{
  //             // console.log('nnn',nnn)
  //             // BaseTrie.fromProof(nnn)
  //             // BaseTrie.verifyProof(abc.txTrie.root,encode(index),nnn).then((mmm)=>{
  //             //     console.log('mmm',mmm)
  //             // })
  //             return nnn;
  //         })

  //     })
  // })

  // return {
  //     header: abc.header,
  //     txProof:  proof,
  //     txIndex: index,
  // }

  return {
    blockHash: '',
    proofBlob: '',
  }

  // let tree = new Trie();

  // await Promise.all(rpcBlock.transactions.map((siblingTx, index) => {
  //   let siblingPath = encode(index)
  //   if (index == 0) {
  //     console.log(siblingTx)
  //     console.log('bb',Transaction.fromRpc(siblingTx))
  //   }
  //   let serializedSiblingTx = Transaction.fromRpc(siblingTx).serialize()
  //   if (index == 0) {
  //     console.log("serializedSiblingTx",serializedSiblingTx)
  //   }
  //   return promisfy(tree.put, tree)(siblingPath, serializedSiblingTx)
  // }))

  // let [_,__,stack] = await promisfy(tree.findPath, tree)(encode(index))

  // // console.log(Header.fromRpc(rpcBlock))
  // return {
  //   header:  Header.fromRpc(rpcBlock),
  //   txProof:  Proof.fromStack(stack),
  //   txIndex: index,
  // }
  // return "aa"
}

// async function validateTxProof(blockHash,proofBlob){
//     // verify trustedBlockHash

//     let proof = decodeProofBlob(proofBlob);

//     if (keccak256(proof.rlpBlockHeader) != blockHash) {
//         revert();
//         return false;
//     }

//     let rlpTx = validateMPTProof(proof.txRootHash, proof.mptKey, proof.stack);

//     return{
//         result: "",
//         index: "",
//         t: ""
//     }
// }

// blocknumber: 13415559
// let resp = transactionProof_mod('/Users/hwb/Documents/code/WorkSpace_0xbb/orbiter-v2-contract/test/BlockJsonFile/0x0b963d785005ee2d25cb078daba5dd5cae1b376707ac53533d8ad638f9cb9659.json',2)
transactionProof_mod(
  '/Users/zhouxy/work/project/orbiter/project/contract/Orbiter_V2/test/BlockJsonFile/block_13415559.json',
  2,
).then((proof) => {
  console.log('resp', proof)
  console.log('headerhash', proof.header.hash())
})
