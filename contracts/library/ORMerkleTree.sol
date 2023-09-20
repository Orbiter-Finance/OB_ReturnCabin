// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {MerkleTreeLib} from "./MerkleTreeLib.sol";

library MerkleTreeVerification {
    using MerkleTreeLib for uint256;
    using MerkleTreeLib for bytes32;
    using MerkleTreeLib for MerkleTreeLib.MergeValue;

    error InvalidMergeValue();

    function verify(
        bytes32 key,
        bytes32 v,
        uint256 leaves_bitmap,
        bytes32 root,
        bytes32 firstZeroBits,
        uint8 startIndex,
        MerkleTreeLib.MergeValue[] calldata siblings
    ) internal pure returns (bool) {
        bytes32 current_path = key;
        bytes32 parent_path;
        uint8 n = 0;
        uint iReverse;
        MerkleTreeLib.MergeValue memory current_v;
        MerkleTreeLib.MergeValue memory zero;

        if (!(v.isZero() || startIndex == 0)) {
            current_v.mergeType = MerkleTreeLib.MergeValueType.MERGE_WITH_ZERO;
            current_v.mergeValue.value1 = startIndex;
            current_v.mergeValue.value2 = keccak256(abi.encode(0, key.parentPath(0), v));
            current_v.mergeValue.value3 = firstZeroBits;
        }

        for (uint i = startIndex; i <= MerkleTreeLib.MAX_TREE_LEVEL; ) {
            unchecked {
                iReverse = MerkleTreeLib.MAX_TREE_LEVEL - i;
            }
            parent_path = current_path.parentPath(i);
            if (leaves_bitmap.getBit(iReverse)) {
                if (current_path.isRight(iReverse)) {
                    merge(uint8(i), parent_path, siblings[n], current_v, current_v);
                } else {
                    merge(uint8(i), parent_path, current_v, siblings[n], current_v);
                }
                unchecked {
                    n += 1;
                }
            } else {
                if (n > 0) {
                    if (current_path.isRight(iReverse)) {
                        merge(uint8(i), parent_path, zero, current_v, current_v);
                    } else {
                        merge(uint8(i), parent_path, current_v, zero, current_v);
                    }
                }
            }

            current_path = parent_path;
            unchecked {
                i += 1;
            }
        }
        return current_v.getHash() == root;
    }

    function merge(
        uint8 height,
        bytes32 nodeKey,
        MerkleTreeLib.MergeValue memory lhs,
        MerkleTreeLib.MergeValue memory rhs,
        MerkleTreeLib.MergeValue memory v
    ) internal pure {
        if (lhs.mergeValue.value2.isZero() && rhs.mergeValue.value2.isZero()) {
            // return same value
        } else if (lhs.mergeValue.value2.isZero()) {
            mergeWithZero(height, nodeKey, rhs, v, true);
        } else if (rhs.mergeValue.value2.isZero()) {
            mergeWithZero(height, nodeKey, lhs, v, false);
        } else {
            bytes32 hashValueLeft;
            bytes32 hashValueRight;
            if (lhs.mergeType == MerkleTreeLib.MergeValueType.VALUE) {
                hashValueLeft = lhs.mergeValue.value2;
            } else {
                hashValueLeft = keccak256(
                    abi.encode(
                        MerkleTreeLib.MERGE_ZEROS,
                        lhs.mergeValue.value2, // baseNode
                        lhs.mergeValue.value3, // zeroBits
                        lhs.mergeValue.value1 // zeroCount
                    )
                );
            }
            if (rhs.mergeType == MerkleTreeLib.MergeValueType.VALUE) {
                hashValueRight = rhs.mergeValue.value2;
            } else {
                hashValueRight = keccak256(
                    abi.encode(
                        MerkleTreeLib.MERGE_ZEROS,
                        rhs.mergeValue.value2, // baseNode
                        rhs.mergeValue.value3, // zeroBits
                        rhs.mergeValue.value1 // zeroCount
                    )
                );
            }
            bytes32 hashValue = keccak256(
                abi.encode(MerkleTreeLib.MERGE_NORMAL, height, nodeKey, hashValueLeft, hashValueRight)
            );
            v.setValue(hashValue);
        }
    }

    function mergeWithZero(
        uint8 height,
        bytes32 nodeKey,
        MerkleTreeLib.MergeValue memory value,
        MerkleTreeLib.MergeValue memory v,
        bool setBit
    ) public pure {
        if (value.mergeType == MerkleTreeLib.MergeValueType.VALUE) {
            bytes32 zeroBits = setBit ? bytes32(0).setBit(MerkleTreeLib.MAX_TREE_LEVEL - height) : bytes32(0);
            bytes32 baseNode = hashBaseNode(height, nodeKey, value.mergeValue.value2);
            v.setMergeWithZero(1, baseNode, zeroBits);
        } else if (value.mergeType == MerkleTreeLib.MergeValueType.MERGE_WITH_ZERO) {
            bytes32 zeroBits = setBit
                ? value.mergeValue.value3.setBit(MerkleTreeLib.MAX_TREE_LEVEL - height)
                : value.mergeValue.value3;
            unchecked {
                v.setMergeWithZero(value.mergeValue.value1 + 1, value.mergeValue.value2, zeroBits);
            }
        } else {
            revert InvalidMergeValue();
        }
    }

    function hashBaseNode(uint8 height, bytes32 key, bytes32 value) public pure returns (bytes32) {
        return keccak256(abi.encode(height, key, value));
    }
}
