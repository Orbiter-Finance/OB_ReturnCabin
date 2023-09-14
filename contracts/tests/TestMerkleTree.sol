// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {MerkleTreeLib} from "../library/MerkleTreeLib.sol";

library MerkleTreeCalculate {
    using MerkleTreeLib for uint256;
    using MerkleTreeLib for bytes32;
    using MerkleTreeLib for MerkleTreeLib.MergeValue;

    function calculteFirstMergeValue(
        MerkleTreeLib.MergeValue memory mergeValue,
        bytes32 key,
        bytes32 value,
        uint8 height
    ) internal pure {
        if (value.isZero() || height == 0) {
            return;
        }
        mergeValue.mergeType = MerkleTreeLib.MergeValueType.MERGE_WITH_ZERO;
        mergeValue.mergeValue.value1 = height;
        mergeValue.mergeValue.value2 = keccak256(abi.encode(0, key.parentPath(0), value));
        processNextLevel(mergeValue, key, MerkleTreeLib.MAX_TREE_LEVEL - height);
    }

    function processNextLevel(
        MerkleTreeLib.MergeValue memory mergeValue,
        bytes32 zeroBits,
        uint iReverse
    ) internal pure {
        if (zeroBits.getBit(iReverse)) {
            zeroBits = zeroBits.clearBit(iReverse);
        }

        if (iReverse == 0) {
            mergeValue.mergeValue.value3 = zeroBits;
            return;
        }

        processNextLevel(mergeValue, zeroBits, iReverse - 1);
    }
}
