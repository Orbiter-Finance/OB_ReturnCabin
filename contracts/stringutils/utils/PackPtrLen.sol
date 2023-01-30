// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

error PackedPtrLen__PtrOverflow();
error PackedPtrLen__LenOverflow();

/**
 * @title Pack ptr and len uint128 values into 1 uint256.
 * @dev ptr is left/MSB. len is right/LSB.
 */
library PackPtrLen {
    uint256 constant MAX = type(uint128).max;

    uint256 constant MASK_PTR = uint256(type(uint128).max) << 128;
    uint256 constant MASK_LEN = uint256(type(uint128).max);

    function pack(uint256 ptr, uint256 len) internal pure returns (uint256 packed) {
        if (ptr > MAX) revert PackedPtrLen__PtrOverflow();
        if (len > MAX) revert PackedPtrLen__LenOverflow();
        return (ptr << 128) | (len & MASK_LEN);
    }

    function getPtr(uint256 packed) internal pure returns (uint256) {
        return packed >> 128;
    }

    function getLen(uint256 packed) internal pure returns (uint256) {
        return packed & MASK_LEN;
    }

    function setPtr(uint256 packed, uint256 ptr) internal pure returns (uint256) {
        return (packed & MASK_PTR) | (ptr << 128);
    }

    function setLen(uint256 packed, uint256 len) internal pure returns (uint256) {
        return (packed & MASK_LEN) | (len);
    }
}
