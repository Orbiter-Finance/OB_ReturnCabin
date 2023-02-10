// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "solidity-rlp/contracts/RLPReader.sol";
import "./interface/IORProventh.sol";
import "./library/BytesUtil.sol";
import "./library/MerkleLib.sol";
import "./library/Operation.sol";
import {InvalidProofOfInclusion, L1InputNotContainL2Tx, InvalidRootHash, InvalidBlockHash, InvalidTxHash, InvalidTxInfo} from "./library/Error.sol";
import "./library/TransactionLib.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";
import "hardhat/console.sol";

contract ORProventh is IORProventh, Initializable, OwnableUpgradeable {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    using BytesLib for bytes;
    using BytesUtil for bytes;

    // bytes32 public userTreeRootHash = 0xf064e5136311e29602148eaeae16ae35ac3387d3cf3bee30fd907a342c08f698;
    // bytes32 public nodeDataRootHash = 0x9c807909d4dae064933061088fbaf31310913320c2602a84cdbf657f8b82292e;
    bytes32 public userTreeRootHash;
    bytes32 public nodeDataRootHash;

    function initialize() external initializer {
        __Ownable_init();
    }

    function updateUserTreeHash(bytes32 _rootHash) external override onlyOwner {
        userTreeRootHash = _rootHash;
    }

    function updateNodeTreeHash(bytes32 _rootHash) external override onlyOwner {
        nodeDataRootHash = _rootHash;
    }

    /**
     * Verify that the L2 transaction is associated with the L1 transaction.
     */
    function verifyL2AndL1Tx(
        TransactionLib.TxInfo memory txInfo,
        bytes[] memory proof,
        bytes1 rollupPrefix
    ) internal view {
        if (rollupPrefix == Optimistic_Rollup) {
            bytes memory l2RLPTxHash = txInfo.txInfo[1];
            bytes memory l1SubRLPTxhash = txInfo.txInfo[0];

            bytes32 userTreeKey = keccak256(abi.encodePacked(keccak256(l2RLPTxHash), keccak256(l1SubRLPTxhash)));

            // validateL2userTreeRootAndProof
            bytes32 userTreeExpectRootHash = keccak256(proof[0]);
            if (userTreeRootHash != userTreeExpectRootHash) {
                revert InvalidRootHash(userTreeRootHash, userTreeExpectRootHash);
            }

            // validateL2RLPTxInfoAndProof
            RLPReader.RLPItem[] memory proof_txinfo_rlp = proof[proof.length - 1].toRlpItem().toList();
            bytes32 userTreeExpectValue = bytes32(proof_txinfo_rlp[proof_txinfo_rlp.length - 1].toUint());
            bytes32 userTreeValue = keccak256(l2RLPTxHash);
            if (userTreeValue != userTreeExpectValue) {
                revert("userTreeValue Invalid");
            }

            verifyProofOfInclusion(userTreeRootHash, MerkleLib.decodeNibbles(abi.encodePacked(userTreeKey), 0), proof);
        } else if (rollupPrefix == Zk_Rollup) {
            // bytes memory zkTxBytes = txInfo.txInfo[1];
            bytes memory zkRollupBytes = txInfo.txInfo[2];

            TransactionLib.DecodeTransaction memory l1SubTransaction = TransactionLib.decodeTransaction(
                txInfo,
                L1ToL2_Cross,
                rollupPrefix
            );
            // console.logBytes32(sha256(zkTxBytes));
            if (!l1SubTransaction.input.contains(zkRollupBytes)) {
                revert L1InputNotContainL2Tx();
            }
        }
    }

    // dev :For testing use
    function verifyTestBytes(bytes memory b) internal pure returns (bytes memory) {
        RLPReader.RLPItem[] memory decodeItem = b.toRlpItem().toList();
        require(decodeItem.length == 2, "length");

        bytes memory bytesRLP = decodeItem[0].toBytes();

        return bytesRLP;
    }

    function verifyBytes(bytes memory b) internal view returns (bytes memory) {
        RLPReader.RLPItem[] memory decodeItem = b.toRlpItem().toList();
        require(decodeItem.length == 2, "length");

        bytes memory bytesRLP = decodeItem[0].toBytes();

        RLPReader.RLPItem[] memory proofDetailItem = decodeItem[1].toList();
        uint256 proofDetailItemLength = proofDetailItem.length;

        bytes[] memory bytesProof = new bytes[](proofDetailItemLength);
        unchecked {
            for (uint256 proofDetailIndex = 0; proofDetailIndex < proofDetailItemLength; ++proofDetailIndex) {
                bytesProof[proofDetailIndex] = proofDetailItem[proofDetailIndex].toBytes();
            }
        }

        // validate dataTreeRootAndProof
        bytes32 dataTreeExpectRootHash = keccak256(bytesProof[0]);
        if (nodeDataRootHash != dataTreeExpectRootHash) {
            revert InvalidRootHash(nodeDataRootHash, dataTreeExpectRootHash);
        }

        // validateDataRLPTxInfoAndProof
        RLPReader.RLPItem[] memory proof_txinfo_rlp = bytesProof[bytesProof.length - 1].toRlpItem().toList();
        bytes32 dataTreeExpectValue = bytes32(proof_txinfo_rlp[proof_txinfo_rlp.length - 1].toUint());
        bytes32 dataTreeValue = keccak256(bytesRLP);
        if (dataTreeValue != dataTreeExpectValue) {
            revert("dataTreeValue Invalid");
        }

        verifyProofOfInclusion(
            nodeDataRootHash,
            MerkleLib.decodeNibbles(abi.encodePacked(dataTreeValue), 0),
            bytesProof
        );

        return bytesRLP;
    }

    function decodeBytes(bytes memory b) internal pure returns (ValidateParams memory params) {
        RLPReader.RLPItem[] memory decodeItem = b.toRlpItem().toList();
        require(decodeItem.length == 4);
        unchecked {
            for (uint256 index = 0; index < decodeItem.length; ++index) {
                if (index == 0) {
                    RLPReader.RLPItem[] memory txInfoItem = decodeItem[index].toList();
                    uint256 itemLength = txInfoItem.length;
                    bytes[] memory txInfo = new bytes[](itemLength);
                    for (uint256 txInfoIndex = 0; txInfoIndex < itemLength; ++txInfoIndex) {
                        txInfo[txInfoIndex] = txInfoItem[txInfoIndex].toBytes();
                    }
                    params.txInfo = txInfo;
                } else if (index == 1) {
                    RLPReader.RLPItem[] memory proofItem = decodeItem[index].toList();
                    uint256 itemLength = proofItem.length;
                    bytes[][] memory proof = new bytes[][](itemLength);
                    for (uint256 proofItemIndex = 0; proofItemIndex < itemLength; ++proofItemIndex) {
                        RLPReader.RLPItem[] memory proofDetailItem = proofItem[proofItemIndex].toList();
                        uint256 itemLength = proofDetailItem.length;
                        bytes[] memory proofDetail = new bytes[](itemLength);
                        for (uint256 proofDetailIndex = 0; proofDetailIndex < itemLength; ++proofDetailIndex) {
                            proofDetail[proofDetailIndex] = proofDetailItem[proofDetailIndex].toBytes();
                        }
                        proof[proofItemIndex] = proofDetail;
                    }
                    params.proof = proof;
                } else if (index == 2) {
                    RLPReader.RLPItem[] memory blockItem = decodeItem[index].toList();
                    uint256 itemLength = blockItem.length;
                    bytes[] memory blocks = new bytes[](itemLength);
                    for (uint256 blockItemIndex = 0; blockItemIndex < itemLength; ++blockItemIndex) {
                        blocks[blockItemIndex] = blockItem[blockItemIndex].toBytes();
                    }
                    params.blockInfo = blocks;
                } else if (index == 3) {
                    RLPReader.RLPItem[] memory seqItem = decodeItem[index].toList();
                    uint256 itemLength = seqItem.length;
                    bytes[] memory seq = new bytes[](itemLength);
                    for (uint256 seqItemIndex = 0; seqItemIndex < itemLength; ++seqItemIndex) {
                        seq[seqItemIndex] = seqItem[seqItemIndex].toBytes();
                    }
                    params.sequence = seq;
                }
            }
        }
    }

    function decodeTxInfo(bytes[] memory txInfoList, bytes1 rollupPrefix)
        internal
        pure
        returns (TransactionLib.TxInfo memory txInfo)
    {
        uint256 length = txInfoList.length;
        if (rollupPrefix == Zk_Rollup) ++length;
        bytes[] memory t = new bytes[](length);
        bytes memory extra;
        unchecked {
            for (uint256 txInfoListIndex = 0; txInfoListIndex < txInfoList.length; ++txInfoListIndex) {
                RLPReader.RLPItem[] memory txInfoItem = txInfoList[txInfoListIndex].toRlpItem().toList();
                if (txInfoListIndex == 1) {
                    //l2
                    if (rollupPrefix == Zk_Rollup) {
                        //zk
                        RLPReader.RLPItem[] memory zkTxInfoItem = txInfoItem[0].toBytes().toRlpItem().toList();
                        t[txInfoListIndex] = zkTxInfoItem[1].toBytes(); //tx
                        t[txInfoListIndex + 1] = zkTxInfoItem[0].toBytes(); //rollup
                    } else if (rollupPrefix == Optimistic_Rollup) {
                        t[txInfoListIndex] = txInfoItem[0].toBytes();
                    }
                } else {
                    //l1
                    t[txInfoListIndex] = txInfoItem[0].toBytes();
                }
                extra = txInfoItem[1].toBytes();
            }
        }

        txInfo.txInfo = t;
        txInfo.extra = extra;
    }

    function startValidate(bytes calldata validateBytes)
        external
        view
        override
        returns (OperationsLib.Transaction memory transaction)
    {
        bytes memory verifyNoProof = verifyTestBytes(validateBytes);

        (bytes memory bytesNoPrefix, bytes1 crossPrefix, bytes1 rollupPrefix) = TransactionLib.processPrefix(
            verifyNoProof
        );

        ValidateParams memory params = decodeBytes(bytesNoPrefix);
        TransactionLib.TxInfo memory txInfo = decodeTxInfo(params.txInfo, rollupPrefix);

        require(params.txInfo.length == 1 || params.txInfo.length == 2, "txInfo is invalid");

        require(params.blockInfo.length == 5 || params.blockInfo.length == 6, "blockInfo is invalid");

        require(params.proof.length == 1 || params.proof.length == 2, "proof is invaild");

        require(params.sequence.length == 1, "sequence is invaild");

        if (crossPrefix == L2ToL1_Cross) {
            uint256 proofIndex = 1;
            if (rollupPrefix == Zk_Rollup) proofIndex = 0;
            verifyL2AndL1Tx(txInfo, params.proof[proofIndex], rollupPrefix);
        }

        verifyTxInfoAndTxHash(txInfo.txInfo[0], params.blockInfo);
        verifyTxInfoAndProof(txInfo.txInfo[0], params.proof[0]);

        bytes32 txRootHash = verifyRootHashAndProof(params.proof[0], params.blockInfo);

        verifyBlockInfoAndBlockHash(params.blockInfo);

        verifyProofOfInclusion(txRootHash, MerkleLib.decodeNibbles(params.sequence[0], 0), params.proof[0]);

        // Check the relationship between the verified block and the current block
        // verifyBlockHash(params.blockInfo);

        TransactionLib.DecodeTransaction memory t = TransactionLib.decodeTransaction(txInfo, crossPrefix, rollupPrefix);
        transaction = t.transaction;
    }

    function verifyBlockHash(bytes[] memory blockInfo) internal view {
        RLPReader.RLPItem memory blockNumber = blockInfo[4].toRlpItem();
        uint256 blockNumberPast = blockNumber.toUint();
        bytes32 blockHashPast = bytes32(blockInfo[5]);
        require(block.number - blockNumberPast < 256, "blockNumberPast more than 256");
        bytes32 expectBlockHash = blockhash(blockNumberPast);
        if (blockHashPast != expectBlockHash) {
            revert InvalidBlockHash(expectBlockHash, blockHashPast);
        }
    }

    /**
     * Verify that TxInfo and TxHash are consistent
     */
    function verifyTxInfoAndTxHash(bytes memory rlpTxInfo, bytes[] memory blockInfo) internal pure {
        bytes32 TxHash = keccak256(rlpTxInfo);

        bytes32 blockInfo_subTxHash = bytes32(blockInfo[2]);

        if (blockInfo_subTxHash != TxHash) {
            revert InvalidTxHash(TxHash, blockInfo_subTxHash);
        }
    }

    /**
     * Verify that TxInfo and TxProof are consistent
     */
    function verifyTxInfoAndProof(bytes memory rlpTxInfo, bytes[] memory proof) internal pure {
        bytes memory proof_last_child = proof[proof.length - 1];

        RLPReader.RLPItem[] memory proof_txinfo_rlp = proof_last_child.toRlpItem().toList();

        bytes32 proofTxInfo = keccak256(proof_txinfo_rlp[proof_txinfo_rlp.length - 1].toBytes());
        bytes32 TxInfo = keccak256(rlpTxInfo);

        if (proofTxInfo != TxInfo) {
            revert InvalidTxInfo();
        }
    }

    /**
     * Verify that RootHash and Proof are consistent
     */
    function verifyRootHashAndProof(bytes[] memory proof, bytes[] memory blockInfo) internal pure returns (bytes32) {
        bytes memory proof_first_child = proof[0];
        bytes32 proof_txRootHash = keccak256(proof_first_child);

        bytes32 blockInfo_txRootHash = bytes32(blockInfo[1]);
        if (proof_txRootHash != blockInfo_txRootHash) {
            revert InvalidRootHash(proof_txRootHash, blockInfo_txRootHash);
        }
        return blockInfo_txRootHash;
    }

    /**
     * Verify that BlockInfo and BlockHash are consistent
     */
    function verifyBlockInfoAndBlockHash(bytes[] memory blockInfo) internal pure {
        bytes32 blockInfoBlockHash = bytes32(blockInfo[0]);
        bytes32 rawBlockHash = keccak256(blockInfo[3]);
        if (blockInfoBlockHash != rawBlockHash) {
            revert InvalidBlockHash(rawBlockHash, blockInfoBlockHash);
        }
    }

    function verifyProofOfInclusion(
        bytes32 rootHash,
        bytes memory mptKey,
        bytes[] memory proof
    ) internal pure {
        bytes memory result = MerkleLib.verifyProof(rootHash, mptKey, proof);
        if (result.length == 0) {
            //empty node
            revert InvalidProofOfInclusion();
        }
    }
}
