// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IORMerkleTree {
    /***************************** 
     * Considering that there are three types of sparse Merkel leaf nodes, 
     * to save gas, we reuse a structure to store these three types
     * and we use mergeType to declare which type of MergeValue
    mergeType --> 0
    struct Value1 {              struct MergeValueSingle {
                                    uint8 value1;
        bytes32 value;  -------->   bytes32 value2;
                                    bytes32 value3;
    }                            }

    mergeType --> 1
    struct Value2 {              struct MergeValueSingle {
        uint8 zeroCount;  ------->  uint8 value1;
        bytes32 baseNode; ------->  bytes32 value2;
        bytes32 zeroBits; ------->  bytes32 value3;
    }                            }

    mergeType --> 2
    struct Value3 {              struct MergeValueSingle {
        uint8 height;  ------->     uint8 value1;
        bytes32 key;   ------->     bytes32 value2;
        bytes32 value; ------->     bytes32 value3;
    }                           }
    *****************************/

    struct SMTLeaf {
        SMTKey key;
        SMTValue value;
    }

    struct SMTKey {
        uint64 chainId;
        address token;
        address user;
    }

    struct SMTValue {
        address token;
        uint64 chainId;
        uint256 amount;
        uint256 debt;
    }

    struct MergeValueSingle {
        uint8 value1;
        bytes32 value2;
        bytes32 value3;
    }

    struct MergeValue {
        MergeValueType mergeType;
        MergeValueSingle mergeValue;
    }

    enum MergeValueType {
        VALUE,
        MERGE_WITH_ZERO,
        SHORT_CUT
    }
}
