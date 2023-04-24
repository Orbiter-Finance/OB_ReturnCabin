import * as ethers from 'ethers';
import {
    Transaction,
} from "@ethereumjs/tx";
async function recoverAddress1() {
    // const transactionHash = { "hash": "0xfe3ba2d6a1b5bdb62405a80a0dae619231a4823ca98b5433c23a52372e98f80e", "type": 2, "accessList": [], "blockHash": "0x522390500cc34f28962248ed5183de5932a3fea53e4148cac8fe2991ee3dd498", "blockNumber": 17043609, "transactionIndex": 118, "confirmations": 914, "from": "0x5F927395213ee6b95dE97bDdCb1b2B1C0F16844F", "gasPrice": { "type": "BigNumber", "hex": "0x06d4e48c98" }, "maxPriorityFeePerGas": { "type": "BigNumber", "hex": "0x00" }, "maxFeePerGas": { "type": "BigNumber", "hex": "0x06d4e48c98" }, "gasLimit": { "type": "BigNumber", "hex": "0x5208" }, "to": "0xdDf4C5025D1A5742cF12F74eEC246d4432c295e4", "value": { "type": "BigNumber", "hex": "0x62fd362a195b8c" }, "nonce": 19301, "data": "0x", "r": "0xaf6af34a62ea5f0a7bffbeb8b5a427693d6c697f7c292b2d48972340f859d426", "s": "0x63b84f8d4facd3acdb273dfa991f4e8269a5ba3b05e840523892ad1eae2c9603", "v": 1, "creates": null, "chainId": 1 }
    let tx2: any = {}
    const transactionHash:any = {
        "blockHash": "0x8ce2f27ad1fc24a13ddf9f77e1759a66e93c2a92914b1c995d60bc93d8f7a7e7",
        "blockNumber": "0xde3677",
        "hash": "0xc7848e32e71318480a1696c8ffba93ca1d460f452d33b88b6aeed1843984e21c",
        "from": "0x151409521fc4af3dbace6d97fd4148a44bf07300",
        "gas": "0x5208",
        "gasPrice": "0x41112a242",
        "input": "0x",
        "nonce": "0x74",
        "r": "0xb50762767b2ac9f6241223145834ec38b3176394bf52c72ff937d398b16f128d",
        "s": "0x38e56a32b01abab3ffe2b4aea75d85cd7b03b82da5c4d09b03f452e2eed8fb18",
        "to": "0x8a700fdb6121a57c59736041d9aa21dfd8820660",
        "transactionIndex": "0xcb",
        "type": 0,
        "v": "0x26",
        "value": "0x16345785d8a0000"
    }
    console.log(transactionHash);
    const expandedSig: any = {
        r: transactionHash.r,
        s: transactionHash.s,
        v: transactionHash.v
    }

    const signature = ethers.utils.joinSignature(expandedSig);
    console.log('signature:', signature)
    switch (transactionHash.type) {
        case 0:
            tx2 = {
                gasPrice: transactionHash.gasPrice,
                gasLimit: transactionHash.gasLimit,
                value: transactionHash.value,
                nonce: transactionHash.nonce,
                data: transactionHash.data,
                chainId: transactionHash.chainId,
                to: transactionHash.to
            };
            break;
        case 2:
            tx2 = {
                gasLimit: transactionHash.gasLimit,
                value: transactionHash.value,
                nonce: transactionHash.nonce,
                data: transactionHash.data,
                chainId: transactionHash.chainId,
                to: transactionHash.to,
                type: 2,
                maxFeePerGas: transactionHash.maxFeePerGas,
                maxPriorityFeePerGas: transactionHash.maxPriorityFeePerGas
            }
            break;
        default:
            throw "Unsupported transactionHash type";
    }
    const rstransactionHash = await ethers.utils.resolveProperties(tx2)
    console.log('rstransactionHash:', rstransactionHash);
    const raw = ethers.utils.serializeTransaction(tx2) // returns RLP encoded transactionHash
    const msgHash = ethers.utils.keccak256(raw) // as specified by ECDSA
    console.log('raw', raw)
    console.log('msgHash', msgHash)
    const msgBytes = ethers.utils.arrayify(msgHash) // create binary hash
    const sender = ethers.utils.recoverAddress(msgBytes, signature);
    console.log(`signer：${sender}`);
    return sender
}
async function recoverAddress2() {
    const txRaw = Transaction.fromSerializedTx(
        Buffer.from(
            "f86f83031bb085724c0d16e782f618945a873a4aa853302449a92d57b54378d4a50014588802c68af0bb140000802da01ca7ab64ae5515cd5902e3824a79cd497a0d92b9bf970400c118366f67b0a3cea06f66440c20b5d84be2aaab657222bcee7d27923942c5c58e8e2210c657b52f9b",
            "hex"
        )
    );
    console.log(txRaw.getSenderAddress().toString(), '===');
    const sender = txRaw.getSenderAddress().toString();
    return sender
}

recoverAddress1();