const { rlp } = require("ethereumjs-util");
// const { Block } = require('@ethereumjs/block')
// const Trie = require('merkle-patricia-tree').SecureTrie
const blockFromRpc = require("@ethereumjs/block/dist/from-rpc").default;

const Common = require("@ethereumjs/common").default;

const fs = require("fs");

const axios = require("axios");

var Web3 = require("web3");
var web3 = new Web3(
  new Web3.providers.HttpProvider(
    "https://eth-mainnet.alchemyapi.io/v2/XXXXXXXXXXX"
  )
); // your web3 provider
var abiDecoder = require("abi-decoder");

// var ABI = require('./zksyncABI.json') // abi of your contract
var ABI = require("./zksyncProxyABI.json"); // abi of your contract

const httpEndUrl = {
  main: "https://api.zksync.io/api/v0.2",
  rinkeby: "https://rinkeby-api.zksync.io/api/v0.2"
};

const common = new Common({
  chain: "mainnet",
  hardfork: "london",
  eips: [1559, 2718, 2930]
});

async function createProof(stack) {
  const p = stack.map((stackElem) => {
    return stackElem.serialize();
  });
  return p;
}

async function transactionProof_mod(txid, isMain) {
  // get_zkTransaciont_info
  const zkTransacitonInfoUrl =
    (isMain ? httpEndUrl.main : httpEndUrl.rinkeby) +
    "/transactions/" +
    txid +
    "/data";
  console.log("zkTransacitonInfoUrl =", zkTransacitonInfoUrl);
  let transaction_response;
  try {
    transaction_response = await axios.get(zkTransacitonInfoUrl);
  } catch (error) {
    console.log("error =", error);
    return;
  }
  let transactionInfo = DecodeZkInfo(transaction_response);
  console.log("transactionInfo =", transactionInfo);
  if (!transactionInfo) {
    console.log("GetTransactionInfoError");
    return;
  }
  // get_zk_blockInfo
  const zk_blockNumber = transactionInfo.tx.blockNumber;
  const zkBlockInfoUrl =
    (isMain ? httpEndUrl.main : httpEndUrl.rinkeby) +
    "/blocks/" +
    zk_blockNumber;
  console.log("zkBlockInfoUrl =", zkBlockInfoUrl);
  let blockNum_response;
  try {
    blockNum_response = await axios.get(zkBlockInfoUrl);
  } catch (error) {
    console.log("error =", error);
    return;
  }

  let blockData = DecodeZkInfo(blockNum_response);
  if (!blockData) {
    console.log("GetBlockDataError");
    return;
  }
  console.log("blockData =", blockData);

  let commitTxHash = blockData.commitTxHash;
  let verifyTxHash = blockData.verifyTxHash;
  let newStateRoot = blockData.newStateRoot;

  console.log("commitTxHash =", commitTxHash);
  console.log("verifyTxHash =", verifyTxHash);
  console.log("newStateRoot =", newStateRoot);

  // contract = web3.eth.contract(
  //   '0x204c6BADaD00Ef326dE0921A940D8267060d1033',
  //   ABI,
  // )

  // (func_obj, func_params) = contract.decode_function_input(tx.input)

  await web3.eth.getTransaction(commitTxHash, async function (err, tx) {
    abiDecoder.addABI(ABI);
    let tx_data = tx.input;

    let decoded_data = abiDecoder.decodeMethod(tx_data);
    console.log("......");
    console.log(decoded_data);
    console.log("-------");
    // console.log(tx_data)

    // let params = decoded_data.params
    // let param_values = []
    // for (i in params) {
    //   // loop to print parameters without unnecessary info
    //   param_values.push(params[i].name + ' : ' + params[i].value)
    // }
    // console.log(param_values)
  });

  // await web3.eth.getTransaction(commitTxHash, function (err, tx) {
  //   let tx_data = tx.input
  //   console.log(tx_data)
  //   let input_data = '0x' + tx_data.slice(10) // get only data without function selector
  //   let params = web3.eth.abi.decodeParameters(
  //     ['bytes32', 'string', 'string', 'string'],
  //     input_data,
  //   )
  //   console.log(params)
  // })
}

function DecodeZkInfo(response) {
  if (response.status === 200) {
    var respData = response.data;
    if (respData.status === "success") {
      return respData.result;
    } else {
      console.log("DecodeZkInfoError");
      return 0;
    }
  } else {
    console.log("DecodeZkInfoError");
    return 0;
  }
}

module.exports = async function () {
  let data = await transactionProof_mod(
    "0x992ab3dd81fb2c98bfcce69b439ed6f061dce20304003433ede499ac0d5ac1ce",
    true
  );
  return data;
};
