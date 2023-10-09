// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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
        uint64 chainId;
        address token;
        address user;
        uint256 amount;
        uint256 debt;
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
        bool _isRight;
        MergeValueType mergeType;
        uint8 currentZeroCount;
        bytes32 currentBaseNode;
        bytes32 currentZeroBits;

        if (leaves_bitmap.isZero()) {
            return
                keccak256(
                    abi.encode(
                        MERGE_ZEROS, //MERGE_ZEROS == 2
                        keccak256(abi.encode(0, key.parentPath(0), v)),
                        key.getBit(0) ? key.clearBit(0) : key,
                        0
                    )
                ) == root;
        }

        if (!(v.isZero() || startIndex == 0)) {
            mergeType = MergeValueType.MERGE_WITH_ZERO;
            currentZeroCount = startIndex;
            currentBaseNode = keccak256(abi.encode(0, key.parentPath(0), v));
            currentZeroBits = firstZeroBits;
        }

        for (uint i = startIndex; ; ) {
            unchecked {
                iReverse = MAX_TREE_LEVEL - i;
            }
            parent_path = key.parentPath(i);
            _isRight = key.isRight(iReverse);

            if (leaves_bitmap.getBit(iReverse)) {
                if (mergeType == MergeValueType.MERGE_WITH_ZERO) {
                    currentBaseNode = keccak256(
                        abi.encode(MERGE_ZEROS, currentBaseNode, currentZeroBits, currentZeroCount)
                    );
                }

                currentBaseNode = keccak256(
                    abi.encode(
                        MERGE_NORMAL,
                        i,
                        parent_path,
                        _isRight ? siblings[n] : currentBaseNode,
                        _isRight ? currentBaseNode : siblings[n]
                    )
                );
                mergeType = MergeValueType.VALUE;

                unchecked {
                    n += 1;
                }
            } else {
                if (n > 0) {
                    if (mergeType == MergeValueType.VALUE) {
                        currentZeroCount = 1;
                        currentZeroBits = _isRight ? bytes32(0).setBit(MAX_TREE_LEVEL - i) : bytes32(0);
                        currentBaseNode = keccak256(abi.encode(i, parent_path, currentBaseNode));
                    } else if (mergeType == MergeValueType.MERGE_WITH_ZERO) {
                        unchecked {
                            currentZeroCount = currentZeroCount + 1;
                        }
                        currentZeroBits = _isRight ? currentZeroBits.setBit(MAX_TREE_LEVEL - i) : currentZeroBits;
                    } else {
                        revert InvalidMergeValue();
                    }
                    mergeType = MergeValueType.MERGE_WITH_ZERO;
                }
            }

            key = parent_path;

            if (i == MAX_TREE_LEVEL) {
                break;
            }

            unchecked {
                i += 1;
            }
        }

        if (mergeType == MergeValueType.VALUE) {
            return currentBaseNode == root;
        } else if (mergeType == MergeValueType.MERGE_WITH_ZERO) {
            return
                keccak256(
                    abi.encode(
                        MERGE_ZEROS, //MERGE_ZEROS == 2
                        currentBaseNode,
                        currentZeroBits,
                        currentZeroCount
                    )
                ) == root;
        }

        return false;
    }
}
