// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct TestStorageStruct {
    uint128 u128_1;
    uint128 u128_2;
    uint128 u128_3;
}

contract TestStorage {
    uint private _u256;

    uint64 private _u64_1;
    uint64 private _u64_2;
    uint64 private _u64_3;
    uint64 private _u64_4;

    uint128 private _u128_1;
    uint128 private _u128_2;

    uint128[] private _array;

    mapping(uint32 => uint) private _mapping;

    mapping(uint32 => TestStorageStruct) private _mappingStruct;

    function updateU256(uint256 u256_) external {
        _u256 = u256_;
    }

    function updateU64s(uint64 u64_1_, uint64 u64_2_, uint64 u64_3_, uint64 u64_4_) external {
        _u64_1 = u64_1_;
        _u64_2 = u64_2_;
        _u64_3 = u64_3_;
        _u64_4 = u64_4_;
    }

    function updateU128s(uint128 u128_1_, uint128 u128_2_) external {
        _u128_1 = u128_1_;
        _u128_2 = u128_2_;
    }

    function updateArray(uint128[] memory array_, uint[] memory indexs) external {
        unchecked {
            for (uint i = 0; i < array_.length; i++) {
                if (i < indexs.length) {
                    _array[indexs[i]] = array_[i];
                } else {
                    _array.push(array_[i]);
                }
            }
        }
    }

    function updateMapping(uint32 key, uint value) external {
        _mapping[key] = value;
    }

    function updateMappingStruct(uint32 key, TestStorageStruct memory struct_) external {
        _mappingStruct[key] = struct_;
    }

    function calcSecondKey(uint position, uint sub) external pure returns (bytes32) {
        bytes32 k = keccak256(abi.encode(sub, position));
        return k;
    }
}
