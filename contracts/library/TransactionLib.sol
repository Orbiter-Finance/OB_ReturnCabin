// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;
import "./BytesLib.sol";
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

    struct DecodeTransaction {
        OperationsLib.Transaction transaction;
        bytes input;
    }

    struct TxInfo {
        bytes[] txInfo; //l1->l2 [l1] l2->l1 [l1,op] [l1,zktx,zkrollup]
        bytes extra;
    }

    struct BlockInfo {
        uint8 isTrack;
        uint64 blockNumber;
        bytes32 blockHash;
        bytes32 txRootHash;
        bytes32 txHash;
        bytes32 trackBlockHash;
        bytes sequence;
        bytes headerRLP;
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

    function decodeRLPBytes(bytes memory decodeBytes)
        internal
        pure
        returns (
            OperationsLib.ProventhParams memory params,
            bytes1 crossPrefix,
            bytes1 rollupPrefix
        )
    {
        bytes memory decodeBytesNoPrefix;
        (decodeBytesNoPrefix, crossPrefix, rollupPrefix) = processPrefix(decodeBytes);
        RLPReader.RLPItem[] memory decodeItem = decodeBytesNoPrefix.toRlpItem().toList();
        uint256 decodeItemLength = decodeItem.length;
        require(decodeItemLength == 3);
        unchecked {
            for (uint256 index = 0; index < decodeItemLength; ++index) {
                if (index == 0) {
                    RLPReader.RLPItem[] memory txInfoItem = decodeItem[index].toList();
                    uint256 itemLength = txInfoItem.length;
                    bytes[] memory txInfo = new bytes[](itemLength);
                    for (uint256 txInfoIndex = 0; txInfoIndex < itemLength; ++txInfoIndex) {
                        txInfo[txInfoIndex] = txInfoItem[txInfoIndex].toBytes();
                    }
                    params.txInfo = decodeTxInfo(txInfo, rollupPrefix);
                } else if (index == 1) {
                    RLPReader.RLPItem[] memory proofItem = decodeItem[index].toList();
                    uint256 itemLength = proofItem.length;
                    bytes[][] memory proof = new bytes[][](itemLength);
                    for (uint256 proofItemIndex = 0; proofItemIndex < itemLength; ++proofItemIndex) {
                        RLPReader.RLPItem[] memory proofDetailItem = proofItem[proofItemIndex].toList();
                        uint256 proofItemLength = proofDetailItem.length;
                        bytes[] memory proofDetail = new bytes[](proofItemLength);
                        for (uint256 proofDetailIndex = 0; proofDetailIndex < proofItemLength; ++proofDetailIndex) {
                            proofDetail[proofDetailIndex] = proofDetailItem[proofDetailIndex].toBytes();
                        }
                        proof[proofItemIndex] = proofDetail;
                    }
                    params.proof = proof;
                } else if (index == 2) {
                    params.blockInfo = decodeBlockInfo(decodeItem[index]);
                }
            }
        }
    }

    function decodeTxInfo(bytes[] memory txInfoList, bytes1 rollupPrefix)
        internal
        pure
        returns (TransactionLib.TxInfo memory decodeTx)
    {
        uint256 length = txInfoList.length;
        if (rollupPrefix == Zk_Rollup) ++length;
        bytes[] memory txInfo = new bytes[](length);
        bytes memory extra;
        unchecked {
            for (uint256 txInfoListIndex = 0; txInfoListIndex < txInfoList.length; ++txInfoListIndex) {
                RLPReader.RLPItem[] memory txInfoItem = txInfoList[txInfoListIndex].toRlpItem().toList();
                if (txInfoListIndex == 1) {
                    //l2
                    if (rollupPrefix == Zk_Rollup) {
                        //zk
                        RLPReader.RLPItem[] memory zkTxInfoItem = txInfoItem[0].toBytes().toRlpItem().toList();
                        txInfo[txInfoListIndex] = zkTxInfoItem[1].toBytes(); //tx
                        txInfo[txInfoListIndex + 1] = zkTxInfoItem[0].toBytes(); //rollup
                    } else if (rollupPrefix == Optimistic_Rollup) {
                        txInfo[txInfoListIndex] = txInfoItem[0].toBytes();
                    }
                } else {
                    //l1
                    txInfo[txInfoListIndex] = txInfoItem[0].toBytes();
                }
                extra = txInfoItem[1].toBytes();
            }
        }

        decodeTx.txInfo = txInfo;
        decodeTx.extra = extra;
    }

    function decodeBlockInfo(RLPReader.RLPItem memory blockRLP) internal pure returns (BlockInfo memory blockInfo) {
        RLPReader.RLPItem[] memory blockItem = blockRLP.toBytes().toRlpItem().toList();
        blockInfo.headerRLP = blockItem[0].toBytes();

        bytes memory blockInfoBytes = blockItem[1].toBytes();
        blockInfo.isTrack = blockInfoBytes.toUint8(0); //0:no 1:yes

        blockInfo.blockNumber = blockInfoBytes.toUint64(1);
        blockInfo.blockHash = blockInfoBytes.toBytes32(9);
        blockInfo.txRootHash = blockInfoBytes.toBytes32(41);
        blockInfo.txHash = blockInfoBytes.toBytes32(73);
        if (blockInfo.isTrack == 1) {
            blockInfo.trackBlockHash = blockInfoBytes.toBytes32(105);
            blockInfo.sequence = blockInfoBytes.slice(137, blockInfoBytes.length - 137);
        } else {
            blockInfo.trackBlockHash = blockInfo.blockHash;
            blockInfo.sequence = blockInfoBytes.slice(105, blockInfoBytes.length - 105);
        }
    }
}
