// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/*
 * These functions are VERY DANGEROUS!
 * They operate directly on memory pointers, use with caution.
 *
 * Assembly here is marked as memory-safe for optimization.
 * The caller MUST use pointers in a memory-safe way!
 * https://docs.soliditylang.org/en/latest/assembly.html#memory-safety
 */

/**
 * @dev Load 1 byte from the pointer.
 * The result is in the least significant byte, hence uint8.
 */
function mload8(uint256 ptr) pure returns (uint8 item) {
    /// @solidity memory-safe-assembly
    assembly {
        item := byte(0, mload(ptr))
    }
    return item;
}

/**
 * @dev Copy `n` memory bytes.
 * WARNING: Does not handle pointer overlap!
 */
function memcpy(
    uint256 ptrDest,
    uint256 ptrSrc,
    uint256 length
) pure {
    // copy 32-byte chunks
    while (length >= 32) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(ptrDest, mload(ptrSrc))
        }
        // safe because total addition will be <= length (ptr+len is implicitly safe)
        unchecked {
            ptrDest += 32;
            ptrSrc += 32;
            length -= 32;
        }
    }
    // copy the 0-31 length tail
    // (the rest is an inlined `mstoreN`)
    uint256 mask = leftMask(length);
    /// @solidity memory-safe-assembly
    assembly {
        mstore(
            ptrDest,
            or(
                // store the left part
                and(mload(ptrSrc), mask),
                // preserve the right part
                and(mload(ptrDest), not(mask))
            )
        )
    }
}

/**
 * @dev mstore `n` bytes (left-aligned) of `data`
 */
function mstoreN(
    uint256 ptrDest,
    bytes32 data,
    uint256 n
) pure {
    uint256 mask = leftMask(n);
    /// @solidity memory-safe-assembly
    assembly {
        mstore(
            ptrDest,
            or(
                // store the left part
                and(data, mask),
                // preserve the right part
                and(mload(ptrDest), not(mask))
            )
        )
    }
}

/**
 * @dev Copy `n` memory bytes using identity precompile.
 */
function memmove(
    uint256 ptrDest,
    uint256 ptrSrc,
    uint256 n
) view {
    /// @solidity memory-safe-assembly
    assembly {
        pop(
            staticcall(
                gas(), // gas (unused is returned)
                0x04, // identity precompile address
                ptrSrc, // argsOffset
                n, // argsSize: byte size to copy
                ptrDest, // retOffset
                n // retSize: byte size to copy
            )
        )
    }
}

/**
 * @dev Compare `n` memory bytes lexicographically.
 * Returns 0 for equal, < 0 for less than and > 0 for greater than.
 *
 * https://doc.rust-lang.org/std/cmp/trait.Ord.html#lexicographical-comparison
 */
function memcmp(
    uint256 ptrSelf,
    uint256 ptrOther,
    uint256 n
) pure returns (int256) {
    // binary search for the first inequality
    while (n >= 32) {
        // safe because total addition will be <= n (ptr+len is implicitly safe)
        unchecked {
            uint256 nHalf = n / 2;
            if (memeq(ptrSelf, ptrOther, nHalf)) {
                ptrSelf += nHalf;
                ptrOther += nHalf;
                // (can't do n /= 2 instead of nHalf, some bytes would be skipped)
                n -= nHalf;
                // an explicit continue is better for optimization here
                continue;
            } else {
                n -= nHalf;
            }
        }
    }

    uint256 mask = leftMask(n);
    int256 diff;
    /// @solidity memory-safe-assembly
    assembly {
        // for <32 bytes subtraction can be used for comparison,
        // just need to shift away from MSB
        diff := sub(shr(8, and(mload(ptrSelf), mask)), shr(8, and(mload(ptrOther), mask)))
    }
    return diff;
}

/**
 * @dev Returns true if `n` memory bytes are equal.
 *
 * It's faster (up to 4x) than memcmp, especially on medium byte lengths like 32-320.
 * The benefit gets smaller for larger lengths, for 10000 it's only 30% faster.
 */
function memeq(
    uint256 ptrSelf,
    uint256 ptrOther,
    uint256 n
) pure returns (bool result) {
    /// @solidity memory-safe-assembly
    assembly {
        result := eq(keccak256(ptrSelf, n), keccak256(ptrOther, n))
    }
}

/**
 * @dev Left-aligned byte mask (e.g. for partial mload/mstore).
 * For length >= 32 returns type(uint256).max
 *
 * length 0:   0x000000...000000
 * length 1:   0xff0000...000000
 * length 2:   0xffff00...000000
 * ...
 * length 30:  0xffffff...ff0000
 * length 31:  0xffffff...ffff00
 * length 32+: 0xffffff...ffffff
 */
function leftMask(uint256 length) pure returns (uint256) {
    unchecked {
        return ~(type(uint256).max >> (length * 8));
    }
}
