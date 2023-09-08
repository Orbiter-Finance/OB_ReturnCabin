// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

// import "hardhat/console.sol";

library MerkleTreeLib {
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

    function isRight(bytes32 _hash, uint height) internal pure returns (bool) {
        return getBit(uint256(_hash), height);
    }

    function setBit(bytes32 bitmap, uint index) internal pure returns (bytes32) {
        return bytes32(uint256(bitmap) | (1 << (index & 0xff)));
    }

    // function setBit(bytes32 bitmap, uint index) internal view returns (bytes32) {
    //     bytes32 result;
    //     assembly {
    //         let bitmapUint := 0
    //         bitmapUint := or(bitmapUint, bitmap)

    //         let shifted := shl(and(index, 0xff), 1)
    //         result := or(bitmapUint, shifted)
    //     }
    //     return result;
    // }

    // function getBit(uint256 bitmap, uint index) internal pure returns (bool) {
    //     return ((bitmap & (1 << index)) > 0) ? true : false;
    // }

    // function getBit(bytes32 bitmap, uint index) internal pure returns (bool) {
    //     return ((uint256(bitmap) & (1 << index)) > 0) ? true : false;
    // }

    function getBit(uint256 bitmap, uint index) internal pure returns (bool) {
        bool result;
        assembly {
            let shifted := shl(index, 1)
            let temp := and(bitmap, shifted)

            result := iszero(iszero(temp))
        }
        return result;
    }

    function getBit(bytes32 bitmap, uint index) internal pure returns (bool) {
        bool result;
        assembly {
            let shifted := shl(index, 1)
            let temp := and(bitmap, shifted)

            result := iszero(iszero(temp))
        }
        return result;
    }

    function clearBit(bytes32 bitmap, uint index) internal pure returns (bytes32) {
        return bytes32(uint256(bitmap) & (~(1 << index)));
    }

    function copyBits(bytes32 bitmap, uint index) internal pure returns (bytes32) {
        return bytes32((uint256(bitmap) << index) >> index);
    }

    function parentPath(bytes32 path, uint height) internal pure returns (bytes32) {
        if (height == 255) {
            return bytes32(0);
        }
        unchecked {
            return copyBits(path, (height + 1));
        }
    }

    function searchIndex(uint256 bitmap) internal pure returns (uint) {
        unchecked {
            for (uint i = 255; i >= 0; i--) {
                if ((bitmap >> i) & 1 == 1) {
                    return (255 - i);
                }
            }
            return 0;
        }
    }

    function set_VALUE(MergeValue memory value, bytes32 newValue) internal pure {
        value.mergeType = MergeValueType.VALUE;
        value.mergeValue.value2 = newValue;
    }

    function set_MERGE_WITH_ZERO(
        MergeValue memory value,
        uint8 ZeroCount,
        bytes32 BaseNode,
        bytes32 ZeroBits
    ) internal pure {
        value.mergeType = MergeValueType.MERGE_WITH_ZERO;
        value.mergeValue.value1 = ZeroCount;
        value.mergeValue.value2 = BaseNode;
        value.mergeValue.value3 = ZeroBits;
    }

    function isZero(bytes32 value) internal pure returns (bool) {
        bool result;
        assembly {
            result := eq(value, 0)
        }
        return result;
    }

    function getHash(MerkleTreeLib.MergeValue memory mergeValue) internal pure returns (bytes32 hashValue) {
        if (mergeValue.mergeType == MerkleTreeLib.MergeValueType.VALUE) {
            hashValue = mergeValue.mergeValue.value2;
        } else if (mergeValue.mergeType == MerkleTreeLib.MergeValueType.MERGE_WITH_ZERO) {
            hashValue = keccak256(
                abi.encode(
                    2, //MERGE_ZEROS == 2
                    mergeValue.mergeValue.value2, // baseNode
                    mergeValue.mergeValue.value3, // zeroBits
                    mergeValue.mergeValue.value1 // zeroCount
                )
            );
            // return
            //     keccak256(
            //         abi.encode(
            //             MERGE_ZEROS,
            //             mergeValue.mergeValue.value2, // baseNode
            //             mergeValue.mergeValue.value3, // zeroBits
            //             mergeValue.mergeValue.value1 // zeroCount
            //         )
            //     );
        }
        // else {
        //     revert InvalidMergeValue();
        // }
    }

    function mergeWithZeroHash(MergeValue calldata mergeValue) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    2, //MERGE_ZEROS == 2
                    mergeValue.mergeValue.value2, // baseNode
                    mergeValue.mergeValue.value3, // zeroBits
                    mergeValue.mergeValue.value1 // zeroCount
                )
            );
    }

    function mergeWithZeroHashM(MergeValue memory mergeValue) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    2, //MERGE_ZEROS == 2
                    mergeValue.mergeValue.value2, // baseNode
                    mergeValue.mergeValue.value3, // zeroBits
                    mergeValue.mergeValue.value1 // zeroCount
                )
            );
    }

    function setSibling(MergeValue memory mergeValue, MergeValue calldata siblingmergeValue) internal pure {
        if (siblingmergeValue.mergeType == MergeValueType.VALUE) {
            mergeValue.mergeType = MergeValueType.VALUE;
            mergeValue.mergeValue.value2 = siblingmergeValue.mergeValue.value2;
        } else {
            mergeValue.mergeType = MergeValueType.MERGE_WITH_ZERO;
            mergeValue.mergeValue.value1 = siblingmergeValue.mergeValue.value1;
            mergeValue.mergeValue.value2 = siblingmergeValue.mergeValue.value2;
            mergeValue.mergeValue.value3 = siblingmergeValue.mergeValue.value3;
        }
    }

    function setCurrent(MergeValue memory mergeValue, MergeValue memory siblingmergeValue) internal pure {
        if (siblingmergeValue.mergeType == MergeValueType.VALUE) {
            mergeValue.mergeType = MergeValueType.VALUE;
            mergeValue.mergeValue.value2 = siblingmergeValue.mergeValue.value2;
        } else {
            mergeValue.mergeType = MergeValueType.MERGE_WITH_ZERO;
            mergeValue.mergeValue.value1 = siblingmergeValue.mergeValue.value1;
            mergeValue.mergeValue.value2 = siblingmergeValue.mergeValue.value2;
            mergeValue.mergeValue.value3 = siblingmergeValue.mergeValue.value3;
        }
    }
}
