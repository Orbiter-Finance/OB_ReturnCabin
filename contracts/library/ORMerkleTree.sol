// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {MerkleTreeLib} from "./MerkleTreeLib.sol";

library MerkleTreeVerification {
    using MerkleTreeLib for uint256;
    using MerkleTreeLib for bytes32;

    error InvalidMergeValue();

    function verify(
        bytes32 key,
        bytes32 v,
        uint256 leaves_bitmap,
        bytes32 root,
        bytes32 firstZeroBits,
        uint8 startIndex,
        bytes32[] calldata siblings
    ) internal pure returns (bool) {
        bytes32 parent_path;
        uint iReverse;
        uint8 n;
        bool isRight;
        MerkleTreeLib.MergeValueType mergeType;
        uint8 currentZeroCount;
        bytes32 currentBaseNode;
        bytes32 currentZeroBits;

        if (leaves_bitmap.isZero()) {
            return
                keccak256(
                    abi.encode(
                        MerkleTreeLib.MERGE_ZEROS, //MERGE_ZEROS == 2
                        keccak256(abi.encode(0, key.parentPath(0), v)),
                        key.getBit(MerkleTreeLib.MAX_TREE_LEVEL) ? key.clearBit(MerkleTreeLib.MAX_TREE_LEVEL) : key,
                        0
                    )
                ) == root;
        }

        if (!(v.isZero() || startIndex == 0)) {
            mergeType = MerkleTreeLib.MergeValueType.MERGE_WITH_ZERO;
            currentZeroCount = startIndex;
            currentBaseNode = keccak256(abi.encode(0, key.parentPath(0), v));
            currentZeroBits = firstZeroBits;
        }

        for (uint i = startIndex; ; ) {
            unchecked {
                iReverse = MerkleTreeLib.MAX_TREE_LEVEL - i;
            }
            parent_path = key.parentPath(i);
            isRight = key.isRight(iReverse);

            if (leaves_bitmap.getBit(iReverse)) {
                if (mergeType == MerkleTreeLib.MergeValueType.MERGE_WITH_ZERO) {
                    currentBaseNode = keccak256(
                        abi.encode(MerkleTreeLib.MERGE_ZEROS, currentBaseNode, currentZeroBits, currentZeroCount)
                    );
                }

                currentBaseNode = keccak256(
                    abi.encode(
                        MerkleTreeLib.MERGE_NORMAL,
                        i,
                        parent_path,
                        isRight ? siblings[n] : currentBaseNode,
                        isRight ? currentBaseNode : siblings[n]
                    )
                );
                mergeType = MerkleTreeLib.MergeValueType.VALUE;

                unchecked {
                    n += 1;
                }
            } else {
                if (n > 0) {
                    if (mergeType == MerkleTreeLib.MergeValueType.VALUE) {
                        currentZeroCount = 1;
                        currentZeroBits = isRight ? bytes32(0).setBit(MerkleTreeLib.MAX_TREE_LEVEL - i) : bytes32(0);
                        currentBaseNode = keccak256(abi.encode(i, parent_path, currentBaseNode));
                    } else if (mergeType == MerkleTreeLib.MergeValueType.MERGE_WITH_ZERO) {
                        unchecked {
                            currentZeroCount = currentZeroCount + 1;
                        }
                        currentZeroBits = isRight
                            ? currentZeroBits.setBit(MerkleTreeLib.MAX_TREE_LEVEL - i)
                            : currentZeroBits;
                    } else {
                        revert InvalidMergeValue();
                    }
                    mergeType = MerkleTreeLib.MergeValueType.MERGE_WITH_ZERO;
                }
            }

            key = parent_path;

            if (i == MerkleTreeLib.MAX_TREE_LEVEL) {
                break;
            }

            unchecked {
                i += 1;
            }
        }

        if (mergeType == MerkleTreeLib.MergeValueType.VALUE) {
            return currentBaseNode == root;
        } else if (mergeType == MerkleTreeLib.MergeValueType.MERGE_WITH_ZERO) {
            return
                keccak256(
                    abi.encode(
                        MerkleTreeLib.MERGE_ZEROS, //MERGE_ZEROS == 2
                        currentBaseNode,
                        currentZeroBits,
                        currentZeroCount
                    )
                ) == root;
        }

        return false;
    }
}
