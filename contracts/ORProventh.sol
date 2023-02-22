// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "solidity-rlp/contracts/RLPReader.sol";
import "./interface/IORProventh.sol";
import "./library/BytesLib.sol";
import "./library/MerkleLib.sol";
import "./library/Operation.sol";
import {InvalidProofOfInclusion, L1InputNotContainL2Tx, InvalidRootHash, InvalidBlockHash, InvalidTxHash, InvalidTxInfo, MaxTrackBlockNumber} from "./library/Error.sol";
import "./library/TransactionLib.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ORProventh is IORProventh, Initializable, OwnableUpgradeable {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    using BytesLib for bytes;

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
        TransactionLib.BlockInfo memory blockInfo,
        bytes[] memory proof,
        bytes1 rollupPrefix
    ) internal view {
        if (rollupPrefix == Optimistic_Rollup) {
            bytes32 l2RLPTxHash = keccak256(txInfo.txInfo[1]);

            if (l2RLPTxHash != blockInfo.l2TxHash) {
                revert InvalidTxHash(blockInfo.l2TxHash, l2RLPTxHash);
            }

            bytes32 userTreeKey = keccak256(abi.encodePacked(l2RLPTxHash, blockInfo.l1TxHash));

            verifyRootHashAndProof(userTreeRootHash, proof);
            verifyTxHashAndSelfProof(l2RLPTxHash, proof);
            verifyProofOfInclusion(userTreeRootHash, MerkleLib.decodeNibbles(abi.encodePacked(userTreeKey), 0), proof);
        } else if (rollupPrefix == Zk_Rollup) {
            bytes32 l2TxHash = sha256(txInfo.txInfo[1]);
            bytes memory zkRollupBytes = txInfo.txInfo[2];

            if (l2TxHash != blockInfo.l2TxHash) {
                revert InvalidTxHash(blockInfo.l2TxHash, l2TxHash);
            }

            TransactionLib.DecodeTransaction memory l1SubTransaction = TransactionLib.decodeTransaction(
                txInfo,
                L1ToL2_Cross,
                rollupPrefix
            );
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

        verifyRootHashAndProof(nodeDataRootHash, bytesProof);

        bytes32 dataTreeValue = keccak256(bytesRLP);
        verifyTxHashAndSelfProof(dataTreeValue, bytesProof);

        verifyProofOfInclusion(
            nodeDataRootHash,
            MerkleLib.decodeNibbles(abi.encodePacked(dataTreeValue), 0),
            bytesProof
        );

        return bytesRLP;
    }

    function startValidate(bytes calldata validateBytes)
        external
        view
        override
        returns (OperationsLib.Transaction memory transaction)
    {
        bytes memory verifyResult = verifyTestBytes(validateBytes);
        (OperationsLib.ProventhParams memory params, bytes1 crossPrefix, bytes1 rollupPrefix) = TransactionLib
            .decodeRLPBytes(verifyResult);

        params.txInfo.txInfo[0] = verifyTxHashAndProof(params.blockInfo.l1TxHash, params.proof[0]);

        if (crossPrefix == L2ToL1_Cross) {
            uint256 proofIndex = 1;
            if (rollupPrefix == Zk_Rollup) proofIndex = 0;
            verifyL2AndL1Tx(params.txInfo, params.blockInfo, params.proof[proofIndex], rollupPrefix);
        }

        verifyRootHashAndProof(params.blockInfo.transactionsRoot, params.proof[0]);

        verifyBlockHeaderAndBlockHash(params.blockInfo);

        verifyProofOfInclusion(
            params.blockInfo.transactionsRoot,
            MerkleLib.decodeNibbles(params.blockInfo.sequence, 0),
            params.proof[0]
        );

        // Check the relationship between the verified block and the current block
        // verifyBlockHash(params.blockInfo);

        TransactionLib.DecodeTransaction memory _decodeTransaction = TransactionLib.decodeTransaction(
            params.txInfo,
            crossPrefix,
            rollupPrefix
        );
        transaction = _decodeTransaction.transaction;
    }

    function verifyBlockHash(TransactionLib.BlockInfo memory blockInfo) internal view {
        uint256 trackBlockNumber = blockInfo.blockNumber;
        bytes32 trackBlockHash = blockInfo.trackBlockHash;
        if (block.number - trackBlockNumber > 256) {
            revert MaxTrackBlockNumber();
        }
        bytes32 expectBlockHash = blockhash(trackBlockNumber);
        if (trackBlockHash != expectBlockHash) {
            revert InvalidBlockHash(expectBlockHash, trackBlockHash);
        }
    }

    /**
     * Verify that TxHash and TxProof are consistent
     */
    function verifyTxHashAndProof(bytes32 txHash, bytes[] memory proof) internal pure returns (bytes memory txInfoRLP) {
        bytes memory nodeValue = proof[proof.length - 1];

        RLPReader.RLPItem[] memory nodeItem = nodeValue.toRlpItem().toList();
        txInfoRLP = nodeItem[nodeItem.length - 1].toBytes();

        bytes32 proofTxHash = keccak256(txInfoRLP);
        if (proofTxHash != txHash) {
            revert InvalidTxHash(txHash, proofTxHash);
        }
    }

    /**
     * Verify that TxHash and SelfProof are consistent
     * Applicable to custom MPT trees
     */
    function verifyTxHashAndSelfProof(bytes32 txHash, bytes[] memory proof) internal pure {
        RLPReader.RLPItem[] memory nodeValue = proof[proof.length - 1].toRlpItem().toList();
        bytes32 proofTxHash = bytes32(nodeValue[nodeValue.length - 1].toUint());

        if (proofTxHash != txHash) {
            revert InvalidTxHash(txHash, proofTxHash);
        }
    }

    /**
     * Verify that BlockHeader and BlockHash are consistent
     */
    function verifyBlockHeaderAndBlockHash(TransactionLib.BlockInfo memory blockInfo) internal pure {
        bytes32 blockHeaderHash = keccak256(blockInfo.headerRLP);

        if (blockInfo.blockHash != blockHeaderHash) {
            revert InvalidBlockHash(blockHeaderHash, blockInfo.blockHash);
        }
    }

    /**
     * Verify that RootHash and Proof are consistent
     */
    function verifyRootHashAndProof(bytes32 rootHash, bytes[] memory proof) internal pure {
        bytes memory rootHashProof = proof[0];
        bytes32 proof_transactionsRoot = keccak256(rootHashProof);

        if (proof_transactionsRoot != rootHash) {
            revert InvalidRootHash(proof_transactionsRoot, rootHash);
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
