// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {leftMask} from "./mem.sol";

/*
 * These functions are VERY DANGEROUS!
 * They operate directly on memory pointers, use with caution.
 *
 * Assembly here is marked as memory-safe for optimization.
 * The caller MUST use pointers in a memory-safe way!
 * https://docs.soliditylang.org/en/latest/assembly.html#memory-safety
 */

/// @dev 32 0x80 bytes. 0x80 = 1000_0000
uint256 constant ASCII_MASK = 0x80 * (type(uint256).max / type(uint8).max);

/**
 * @dev Efficiently checks if all bytes are within the ASCII range.
 */
function memIsAscii(uint256 textPtr, uint256 textLen) pure returns (bool) {
    uint256 tailLen;
    uint256 endPtr;
    // safe because tailLen <= textLen (ptr+len is implicitly safe)
    unchecked {
        tailLen = textLen % 32;
        endPtr = textPtr + (textLen - tailLen);
    }

    // check 32 byte chunks with the ascii mask
    uint256 b;
    while (textPtr < endPtr) {
        /// @solidity memory-safe-assembly
        assembly {
            b := mload(textPtr)
        }
        // break if any non-ascii byte is found
        if (b & ASCII_MASK != 0) {
            return false;
        }
        // safe because textPtr < endPtr, and endPtr = textPtr + n*32 (see tailLen)
        unchecked {
            textPtr += 32;
        }
    }

    // this mask removes any trailing bytes
    uint256 trailingMask = leftMask(tailLen);
    /// @solidity memory-safe-assembly
    assembly {
        b := and(mload(endPtr), trailingMask)
    }
    // check tail with the ascii mask
    return b & ASCII_MASK == 0;
}
