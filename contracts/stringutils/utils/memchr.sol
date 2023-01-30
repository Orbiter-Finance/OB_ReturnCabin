// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/*
 * These functions are VERY DANGEROUS!
 * They operate directly on memory pointers, use with caution.
 *
 * Assembly here is marked as memory-safe for optimization.
 * The caller MUST use pointers in a memory-safe way!
 * https://docs.soliditylang.org/en/latest/assembly.html#memory-safety
 *
 * Loosely based on https://doc.rust-lang.org/1.65.0/core/slice/memchr/
 */

/**
 * @dev Returns the first index matching the byte `x` in text;
 * or type(uint256).max if not found.
 */
function memchr(
    uint256 ptrText,
    uint256 lenText,
    uint8 x
) pure returns (uint256 index) {
    if (lenText <= 32) {
        // Fast path for small slices.
        return memchrWord(ptrText, lenText, x);
    }

    uint256 ptrStart = ptrText;
    uint256 lenTail;
    uint256 ptrEnd;
    // safe because lenTail <= lenText (ptr+len is implicitly safe)
    unchecked {
        // (unchecked % saves a little gas)
        lenTail = lenText % 32;
        ptrEnd = ptrText + (lenText - lenTail);
    }
    uint256 repeatedX = repeatByte(x);
    while (ptrText < ptrEnd) {
        // any bytes equal to `x` become zeros
        // (this helps find `x` faster, values of non-zero bytes don't matter)
        uint256 chunkXZero;
        /// @solidity memory-safe-assembly
        assembly {
            chunkXZero := xor(mload(ptrText), repeatedX)
        }
        // break if there is a matching byte
        if (nonZeroIfXcontainsZeroByte(chunkXZero) != 0) {
            // - is safe because ptrText >= ptrStart (ptrText = ptrStart + 32*n)
            // + is safe because index + offsetLen < lenText
            // (ptr+len is implicitly safe)
            unchecked {
                return
                    // index
                    memchrWord(ptrText, 32, x) +
                    // + offsetLen
                    (ptrText - ptrStart);
            }
        }

        // safe because ptrText < ptrEnd, and ptrEnd = ptrText + n*32 (see lenTail)
        unchecked {
            ptrText += 32;
        }
    }

    if (lenTail == 0) return type(uint256).max;

    index = memchrWord(ptrEnd, lenTail, x);
    if (index == type(uint256).max) {
        return type(uint256).max;
    } else {
        // - is safe because ptrEnd >= ptrStart (ptrEnd = ptrStart + lenText - lenTail)
        // + is safe because index + offsetLen < lenText
        // (ptr+len is implicitly safe)
        unchecked {
            return
                index +
                // + offsetLen
                (ptrEnd - ptrStart);
        }
    }
}

/**
 * @dev Returns the last index matching the byte `x` in text;
 * or type(uint256).max if not found.
 */
function memrchr(
    uint256 ptrText,
    uint256 lenText,
    uint8 x
) pure returns (uint256) {
    if (lenText <= 32) {
        // Fast path for small slices.
        return memrchrWord(ptrText, lenText, x);
    }

    uint256 lenTail;
    uint256 offsetPtr;
    // safe because pointers are guaranteed to be valid by the caller
    unchecked {
        // (unchecked % saves a little gas)
        lenTail = lenText % 32;
        offsetPtr = ptrText + lenText;
    }

    if (lenTail != 0) {
        // remove tail length
        // - is safe because lenTail <= lenText <= offsetPtr
        unchecked {
            offsetPtr -= lenTail;
        }
        // return if there is a matching byte
        uint256 index = memrchrWord(offsetPtr, lenTail, x);
        if (index != type(uint256).max) {
            // - is safe because offsetPtr > ptrText (offsetPtr = ptrText + lenText - lenTail)
            // + is safe because index + offsetLen < lenText
            unchecked {
                return
                    index +
                    // + offsetLen
                    (offsetPtr - ptrText);
            }
        }
    }

    uint256 repeatedX = repeatByte(x);
    while (offsetPtr > ptrText) {
        // - is safe because 32 <= lenText <= offsetPtr
        unchecked {
            offsetPtr -= 32;
        }

        // any bytes equal to `x` become zeros
        // (this helps find `x` faster, values of non-zero bytes don't matter)
        uint256 chunkXZero;
        /// @solidity memory-safe-assembly
        assembly {
            chunkXZero := xor(mload(offsetPtr), repeatedX)
        }
        // break if there is a matching byte
        if (nonZeroIfXcontainsZeroByte(chunkXZero) != 0) {
            // - is safe because offsetPtr > ptrText (see the while condition)
            // + is safe because index + offsetLen < lenText
            unchecked {
                return
                    // index
                    memrchrWord(offsetPtr, 32, x) +
                    // + offsetLen
                    (offsetPtr - ptrText);
            }
        }
    }
    // not found
    return type(uint256).max;
}

/**
 * @dev Returns the first index matching the byte `x` in text;
 * or type(uint256).max if not found.
 *
 * WARNING: it works ONLY for length 32 or less.
 * This is for use by memchr after its chunk search.
 */
function memchrWord(
    uint256 ptrText,
    uint256 lenText,
    uint8 x
) pure returns (uint256) {
    uint256 chunk;
    /// @solidity memory-safe-assembly
    assembly {
        chunk := mload(ptrText)
    }

    uint256 i;
    if (lenText > 32) {
        lenText = 32;
    }

    ////////binary search start
    // Some manual binary searches, cost ~50gas, could save up to ~1500
    // (comment them out and the function will work fine)
    if (lenText >= 16 + 2) {
        uint256 repeatedX = chunk ^ repeatByte(x);

        if (nonZeroIfXcontainsZeroByte(repeatedX | type(uint128).max) == 0) {
            i = 16;

            if (lenText >= 24 + 2) {
                if (nonZeroIfXcontainsZeroByte(repeatedX | type(uint64).max) == 0) {
                    i = 24;
                }
            }
        } else if (nonZeroIfXcontainsZeroByte(repeatedX | type(uint192).max) == 0) {
            i = 8;
        }
    } else if (lenText >= 8 + 2) {
        uint256 repeatedX = chunk ^ repeatByte(x);

        if (nonZeroIfXcontainsZeroByte(repeatedX | type(uint192).max) == 0) {
            i = 8;
        }
    }
    ////////binary search end

    // ++ is safe because lenText <= 32
    unchecked {
        for (i; i < lenText; i++) {
            uint8 b;
            assembly {
                b := byte(i, chunk)
            }
            if (b == x) return i;
        }
    }
    // not found
    return type(uint256).max;
}

/**
 * @dev Returns the last index matching the byte `x` in text;
 * or type(uint256).max if not found.
 *
 * WARNING: it works ONLY for length 32 or less.
 * This is for use by memrchr after its chunk search.
 */
function memrchrWord(
    uint256 ptrText,
    uint256 lenText,
    uint8 x
) pure returns (uint256) {
    if (lenText > 32) {
        lenText = 32;
    }
    uint256 chunk;
    /// @solidity memory-safe-assembly
    assembly {
        chunk := mload(ptrText)
    }

    while (lenText > 0) {
        // -- is safe because lenText > 0
        unchecked {
            lenText--;
        }
        uint8 b;
        assembly {
            b := byte(lenText, chunk)
        }
        if (b == x) return lenText;
    }
    // not found
    return type(uint256).max;
}

/// @dev repeating low bit for containsZeroByte
uint256 constant LO_U256 = 0x0101010101010101010101010101010101010101010101010101010101010101;
/// @dev repeating high bit for containsZeroByte
uint256 constant HI_U256 = 0x8080808080808080808080808080808080808080808080808080808080808080;

/**
 * @dev Returns a non-zero value if `x` contains any zero byte.
 * (returning a bool would be less efficient)
 *
 * From *Matters Computational*, J. Arndt:
 *
 * "The idea is to subtract one from each of the bytes and then look for
 * bytes where the borrow propagated all the way to the most significant bit."
 */
function nonZeroIfXcontainsZeroByte(uint256 x) pure returns (uint256) {
    unchecked {
        return (x - LO_U256) & (~x) & HI_U256;
    }
    /*
     * An example of how it works:
     *                                              here is 00
     * x    0x0101010101010101010101010101010101010101010101000101010101010101
     * x-LO 0xffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000
     * ~x   0xfefefefefefefefefefefefefefefefefefefefefefefefffefefefefefefefe
     * &1   0xfefefefefefefefefefefefefefefefefefefefefefefeff0000000000000000
     * &2   0x8080808080808080808080808080808080808080808080800000000000000000
     */
}

/// @dev Repeat byte `b` 32 times
function repeatByte(uint8 b) pure returns (uint256) {
    // safe because uint8 can't cause overflow:
    // e.g. 0x5A * 0x010101..010101 = 0x5A5A5A..5A5A5A
    // and  0xFF * 0x010101..010101 = 0xFFFFFF..FFFFFF
    unchecked {
        return b * (type(uint256).max / type(uint8).max);
    }
}
