// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

// import "hardhat/console.sol";

library MerkleTreeLib {
    /***************************** 
     * In SMT verification we use three different MergeValueType
     * and we define those three types in the enumeration structure below
    mergeType --> 0
    struct type1 {     
        bytes32 value;            
    }                   

    mergeType --> 1
    struct type2 {       
        uint8 zeroCount;  
        bytes32 baseNode; 
        bytes32 zeroBits; 
    }                     

    mergeType --> 2
    struct type3 {    
        uint8 height;  
        bytes32 key;   
        bytes32 value; 
    }                           
    *****************************/

    enum MergeValueType {
        VALUE,
        MERGE_WITH_ZERO,
        SHORT_CUT
    }

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

    uint8 internal constant MERGE_NORMAL = 1;
    uint8 internal constant MERGE_ZEROS = 2;
    uint8 internal constant MAX_TREE_LEVEL = 255;

    function isRight(bytes32 _hash, uint height) internal pure returns (bool) {
        return getBit(_hash, height);
    }

    function setBit(bytes32 bitmap, uint index) internal pure returns (bytes32) {
        return bytes32(uint256(bitmap) | (1 << (index & 0xff)));
    }

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

    function isZero(bytes32 value) internal pure returns (bool) {
        bool result;
        assembly {
            result := eq(value, 0)
        }
        return result;
    }

    function isZero(uint256 value) internal pure returns (bool) {
        bool result;
        assembly {
            result := eq(value, 0)
        }
        return result;
    }
}
