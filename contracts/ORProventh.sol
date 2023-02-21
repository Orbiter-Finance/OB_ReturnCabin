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
import "hardhat/console.sol";

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
        bytes[] memory proof,
        bytes1 rollupPrefix
    ) internal view {
        if (rollupPrefix == Optimistic_Rollup) {
            bytes memory l2RLPTxHash = txInfo.txInfo[1];
            bytes memory l1SubRLPTxhash = txInfo.txInfo[0];

            bytes32 userTreeKey = keccak256(abi.encodePacked(keccak256(l2RLPTxHash), keccak256(l1SubRLPTxhash)));

            // validateL2userTreeRootAndProof
            verifyRootHashAndProof(proof, userTreeRootHash);

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
        verifyRootHashAndProof(bytesProof, nodeDataRootHash);

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

    function startValidate(bytes calldata validateBytes)
        external
        view
        override
        returns (OperationsLib.Transaction memory transaction)
    {
        bytes memory verifyResult = verifyTestBytes(validateBytes);

        (OperationsLib.ProventhParams memory params, bytes1 crossPrefix, bytes1 rollupPrefix) = TransactionLib
            .decodeRLPBytes(verifyResult);

        if (crossPrefix == L2ToL1_Cross) {
            uint256 proofIndex = 1;
            if (rollupPrefix == Zk_Rollup) proofIndex = 0;
            verifyL2AndL1Tx(params.txInfo, params.proof[proofIndex], rollupPrefix);
        }

        verifyTxInfoAndTxHash(params.txInfo.txInfo[0], params.blockInfo.txHash);
        verifyTxInfoAndProof(params.txInfo.txInfo[0], params.proof[0]);

        bytes32 txRootHash = verifyRootHashAndProof(params.proof[0], params.blockInfo.txRootHash);

        verifyBlockInfoAndBlockHash(params.blockInfo);

        verifyProofOfInclusion(txRootHash, MerkleLib.decodeNibbles(params.blockInfo.sequence, 0), params.proof[0]);

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
     * Verify that TxInfo and TxHash are consistent
     */
    function verifyTxInfoAndTxHash(bytes memory rlpTxInfo, bytes32 blockInfoTxHash) internal pure {
        bytes32 txHash = keccak256(rlpTxInfo);
        if (blockInfoTxHash != txHash) {
            revert InvalidTxHash(txHash, blockInfoTxHash);
        }
    }

    /**
     * Verify that TxInfo and TxProof are consistent
     */
    function verifyTxInfoAndProof(bytes memory rlpTxInfo, bytes[] memory proof) internal pure {
        bytes memory proof_last_child = proof[proof.length - 1];

        RLPReader.RLPItem[] memory proof_txinfo_rlp = proof_last_child.toRlpItem().toList();

        bytes32 proofTxHash = keccak256(proof_txinfo_rlp[proof_txinfo_rlp.length - 1].toBytes());
        bytes32 txHash = keccak256(rlpTxInfo);
        if (proofTxHash != txHash) {
            revert InvalidTxInfo();
        }
    }

    /**
     * Verify that RootHash and Proof are consistent
     */
    function verifyRootHashAndProof(bytes[] memory proof, bytes32 rootHash) internal pure returns (bytes32) {
        bytes memory rootHashProof = proof[0];
        bytes32 proof_txRootHash = keccak256(rootHashProof);
        if (proof_txRootHash != rootHash) {
            revert InvalidRootHash(proof_txRootHash, rootHash);
        }
        return rootHash;
    }

    /**
     * Verify that BlockInfo and BlockHash are consistent
     */
    function verifyBlockInfoAndBlockHash(TransactionLib.BlockInfo memory blockInfo) internal pure {
        bytes32 blockHeaderHash = keccak256(blockInfo.headerRLP);
        if (blockInfo.blockHash != blockHeaderHash) {
            revert InvalidBlockHash(blockHeaderHash, blockInfo.blockHash);
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
