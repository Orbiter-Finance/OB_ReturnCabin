// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "solidity-bytes-utils/contracts/BytesLib.sol";
import "solidity-rlp/contracts/RLPReader.sol";
import "./Operation.sol";
// Rollup Types
bytes1 constant None_Rollup = 0xc0;
bytes1 constant Optimistic_Rollup = 0xc1;
bytes1 constant Zk_Rollup = 0xc2;

// Cross Types
bytes1 constant L1ToL2_Cross = 0x9a;
bytes1 constant L2ToL1_Cross = 0x9b;

// EIP
bytes1 constant EIP_2718 = 0x00;
bytes1 constant EIP_1559 = 0x02;
bytes1 constant EIP_2930 = 0x03;

library TransactionLib {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    using BytesLib for bytes;
    // struct Transaction {
    //     address from;
    //     address to;
    //     address tokenAddress;
    //     bytes32 txHash;
    //     bytes32 blockHash;
    //     uint256 blockNumber;
    //     uint256 chainId;
    //     uint256 nonce;
    //     uint256 gas;
    //     uint256 gasPrice;
    //     uint256 value;
    //     uint256 transactionIndex;
    //     uint256 timeStamp;
    // }

    struct DecodeTransaction {
        OperationsLib.Transaction transaction;
        bytes input;
    }

    struct TxInfo {
        bytes[] txInfo; //l1->l2 [l1] l2->l1 [l1,op] [l1,zktx,zkrollup]
        bytes extra;
    }

    function decodeTransaction(
        TxInfo memory txInfo,
        bytes1 crossPrefix,
        bytes1 rollupPrefix
    ) internal pure returns (DecodeTransaction memory decodeTx) {
        uint256 txInfoIndex;
        uint256 extraItemType;
        if (crossPrefix == L1ToL2_Cross && rollupPrefix == None_Rollup) {
            //L1
            txInfoIndex = 0;
            extraItemType = 0;
        } else if (crossPrefix == L1ToL2_Cross && rollupPrefix == Zk_Rollup) {
            // L1 Zk
            txInfoIndex = 0;
            extraItemType = 1;
        } else if (crossPrefix == L2ToL1_Cross && rollupPrefix == Optimistic_Rollup) {
            // L2 Op
            txInfoIndex = 1;
            extraItemType = 0;
        } else if (crossPrefix == L2ToL1_Cross && rollupPrefix == Zk_Rollup) {
            // L2 Zk
            txInfoIndex = 1;
            extraItemType = 0;
        }
        RLPReader.RLPItem[] memory extraItem = txInfo.extra.toRlpItem().toList();

        bytes1 EIP_Prefix = bytes1(uint8(extraItem[extraItemType].toUint()));
        bytes memory txInfoWithPrefix = txInfo.txInfo[txInfoIndex];
        if (EIP_Prefix == EIP_1559) {
            (bytes memory _txInfo, , ) = processPrefix(txInfoWithPrefix);
            RLPReader.RLPItem[] memory txInfoFields = _txInfo.toRlpItem().toList();
            decodeTx.transaction = OperationsLib.Transaction(
                extraItem[5].toAddress(), //From
                txInfoFields[5].toAddress(), //To
                extraItem[9].toAddress(), //TokenAddress
                keccak256(txInfoWithPrefix), //Hash
                bytes32(extraItem[2].toUint()), //BlockHash
                extraItem[3].toUint(), //BlockNumber
                extraItem[4].toUint(), //ChainID
                txInfoFields[1].toUint(), //Nonce
                txInfoFields[4].toUint(), //GasLimit
                extraItem[6].toUint(), //GasPrice
                txInfoFields[6].toUint(), //Value
                extraItem[7].toUint(), //TransactionIndex
                extraItem[8].toUint() //timeStamp
            );
            decodeTx.input = txInfoFields[7].toBytes(); //Input
        } else if (EIP_Prefix == EIP_2718) {
            RLPReader.RLPItem[] memory txInfoFields = txInfo.txInfo[txInfoIndex].toRlpItem().toList();
            decodeTx.transaction = OperationsLib.Transaction(
                extraItem[5].toAddress(), //From
                txInfoFields[3].toAddress(), //To
                extraItem[9].toAddress(), //TokenAddress
                keccak256(txInfoWithPrefix), //Hash
                bytes32(extraItem[2].toUint()), //BlockHash
                extraItem[3].toUint(), //BlockNumber
                extraItem[4].toUint(), //ChainID
                txInfoFields[0].toUint(), //Nonce
                txInfoFields[2].toUint(), //GasLimit
                extraItem[6].toUint(), //GasPrice
                txInfoFields[4].toUint(), //Value
                extraItem[7].toUint(), //TransactionIndex
                extraItem[8].toUint() //timeStamp
            );
            decodeTx.input = txInfoFields[5].toBytes(); //Input
        } else if (EIP_Prefix == Zk_Rollup) {
            decodeTx.transaction = OperationsLib.Transaction(
                extraItem[5].toAddress(), //From
                extraItem[10].toAddress(), //To
                extraItem[9].toAddress(), //TokenAddress
                sha256(txInfoWithPrefix), //Hash
                bytes32(extraItem[2].toUint()), //BlockHash
                extraItem[3].toUint(), //BlockNumber
                extraItem[4].toUint(), //ChainID
                extraItem[11].toUint(), //Nonce
                0, //GasLimit
                0, //GasPrice
                extraItem[12].toUint(), //Value
                0, //TransactionIndex
                extraItem[8].toUint() //timeStamp
            );
        }
    }

    function processPrefix(bytes memory rlpTxHashHasPrefix)
        internal
        pure
        returns (
            bytes memory rlpTxHash,
            bytes1 prefix,
            bytes1 prefixExtra
        )
    {
        prefix = rlpTxHashHasPrefix[0];
        if (prefix == L1ToL2_Cross || prefix == L2ToL1_Cross) {
            prefixExtra = rlpTxHashHasPrefix[1];
            if (prefixExtra == None_Rollup || prefixExtra == Optimistic_Rollup || prefixExtra == Zk_Rollup) {
                rlpTxHash = rlpTxHashHasPrefix.slice(2, rlpTxHashHasPrefix.length - 2);
            } else revert();
        } else if (prefix == EIP_1559) {
            rlpTxHash = rlpTxHashHasPrefix.slice(1, rlpTxHashHasPrefix.length - 1);
        } else {
            rlpTxHash = rlpTxHashHasPrefix;
        }
        return (rlpTxHash, prefix, prefixExtra);
    }
}
