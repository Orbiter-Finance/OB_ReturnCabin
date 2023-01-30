// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {mload8, memmove, memcmp, memeq, leftMask} from "./utils/mem.sol";
import {memchr, memrchr} from "./utils/memchr.sol";
import {PackPtrLen} from "./utils/PackPtrLen.sol";

import {SliceIter, SliceIter__} from "./SliceIter.sol";

/**
 * @title A view into a contiguous sequence of 1-byte items.
 */
type Slice is uint256;

/*//////////////////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
//////////////////////////////////////////////////////////////////////////*/

error Slice__OutOfBounds();
error Slice__LengthMismatch();

/*//////////////////////////////////////////////////////////////////////////
                              STATIC FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

library Slice__ {
    /**
     * @dev Converts a `bytes` to a `Slice`.
     * The bytes are not copied.
     * `Slice` points to the memory of `bytes`, right after the length word.
     */
    function from(bytes memory b) internal pure returns (Slice slice) {
        uint256 _ptr;
        assembly {
            _ptr := add(b, 0x20)
        }
        return fromRawParts(_ptr, b.length);
    }

    /**
     * @dev Creates a new `Slice` directly from length and memory pointer.
     * Note that the caller MUST guarantee memory-safety.
     * This method is primarily for internal use.
     */
    function fromRawParts(uint256 _ptr, uint256 _len) internal pure returns (Slice slice) {
        return Slice.wrap(PackPtrLen.pack(_ptr, _len));
    }

    /**
     * @dev Like `fromRawParts`, but does NO validity checks.
     * _ptr and _len MUST fit into uint128.
     * The caller MUST guarantee memory-safety.
     * Primarily for internal use.
     */
    function fromUnchecked(uint256 _ptr, uint256 _len) internal pure returns (Slice slice) {
        return Slice.wrap((_ptr << 128) | (_len & PackPtrLen.MASK_LEN));
    }
}

/**
 * @dev Alternative to Slice__.from()
 * Put this in your file (using for global is only for user-defined types):
 * ```
 * using { toSlice } for bytes;
 * ```
 */
function toSlice(bytes memory b) pure returns (Slice slice) {
    return Slice__.from(b);
}

/*//////////////////////////////////////////////////////////////////////////
                              GLOBAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {
    ptr,
    len,
    isEmpty,
    toBytes,
    toBytes32,
    keccak,
    add,
    join,
    copyFromSlice,
    cmp,
    eq,
    ne,
    lt,
    lte,
    gt,
    gte,
    get,
    first,
    last,
    splitAt,
    getSubslice,
    getBefore,
    getAfter,
    getAfterStrict,
    find,
    rfind,
    contains,
    startsWith,
    endsWith,
    stripPrefix,
    stripSuffix,
    iter
} for // conversion
// concatenation
// copy
// compare
// index
// search
// modify
// iteration
Slice global;

/**
 * @dev Returns the pointer to the start of an in-memory slice.
 */
function ptr(Slice self) pure returns (uint256) {
    return Slice.unwrap(self) >> 128;
}

/**
 * @dev Returns the length in bytes.
 */
function len(Slice self) pure returns (uint256) {
    return Slice.unwrap(self) & PackPtrLen.MASK_LEN;
}

/**
 * @dev Returns true if the slice has a length of 0.
 */
function isEmpty(Slice self) pure returns (bool) {
    return Slice.unwrap(self) & PackPtrLen.MASK_LEN == 0;
}

/**
 * @dev Copies `Slice` to a new `bytes`.
 * The `Slice` will NOT point to the new `bytes`.
 */
function toBytes(Slice self) view returns (bytes memory b) {
    b = new bytes(self.len());
    uint256 bPtr;
    assembly {
        bPtr := add(b, 0x20)
    }

    memmove(bPtr, self.ptr(), self.len());
    return b;
}

/**
 * @dev Fills a `bytes32` (value type) with the first 32 bytes of `Slice`.
 * Goes from left(MSB) to right(LSB).
 * If len < 32, the leftover bytes are zeros.
 */
function toBytes32(Slice self) pure returns (bytes32 b) {
    uint256 selfPtr = self.ptr();

    // mask removes any trailing bytes
    uint256 selfLen = self.len();
    uint256 mask = leftMask(selfLen);

    /// @solidity memory-safe-assembly
    assembly {
        b := and(mload(selfPtr), mask)
    }
    return b;
}

/**
 * @dev Returns keccak256 of all the bytes of `Slice`.
 * Note that for any `bytes memory b`, keccak256(b) == b.toSlice().keccak()
 * (keccak256 does not include the length byte)
 */
function keccak(Slice self) pure returns (bytes32 result) {
    uint256 selfPtr = self.ptr();
    uint256 selfLen = self.len();
    /// @solidity memory-safe-assembly
    assembly {
        result := keccak256(selfPtr, selfLen)
    }
}

/**
 * @dev Concatenates two `Slice`s into a newly allocated `bytes`.
 */
function add(Slice self, Slice other) view returns (bytes memory b) {
    uint256 selfLen = self.len();
    uint256 otherLen = other.len();

    b = new bytes(selfLen + otherLen);
    uint256 bPtr;
    assembly {
        bPtr := add(b, 0x20)
    }

    memmove(bPtr, self.ptr(), selfLen);
    memmove(bPtr + selfLen, other.ptr(), otherLen);
    return b;
}

/**
 * @dev Flattens an array of `Slice`s into a single newly allocated `bytes`,
 * placing `self` as the separator between each.
 *
 * TODO this is the wrong place for this method, but there are no other places atm
 * (since there's no proper chaining/reducers/anything)
 */
function join(Slice self, Slice[] memory slices) view returns (bytes memory b) {
    uint256 slicesLen = slices.length;
    if (slicesLen == 0) return "";

    uint256 selfLen = self.len();
    uint256 repetitionLen;
    // -1 is safe because of ==0 check earlier
    unchecked {
        repetitionLen = slicesLen - 1;
    }
    // add separator repetitions length
    uint256 totalLen = selfLen * repetitionLen;
    // add slices length
    for (uint256 i; i < slicesLen; i++) {
        totalLen += slices[i].len();
    }

    b = new bytes(totalLen);
    uint256 bPtr;
    assembly {
        bPtr := add(b, 0x20)
    }
    for (uint256 i; i < slicesLen; i++) {
        Slice slice = slices[i];
        // copy slice
        memmove(bPtr, slice.ptr(), slice.len());
        bPtr += slice.len();
        // copy separator (skips the last cycle)
        if (i < repetitionLen) {
            memmove(bPtr, self.ptr(), selfLen);
            bPtr += selfLen;
        }
    }
}

/**
 * @dev Copies all elements from `src` into `self`.
 * The length of `src` must be the same as `self`.
 */
function copyFromSlice(Slice self, Slice src) view {
    uint256 selfLen = self.len();
    if (selfLen != src.len()) revert Slice__LengthMismatch();

    memmove(self.ptr(), src.ptr(), selfLen);
}

/**
 * @dev Compare slices lexicographically.
 * @return result 0 for equal, < 0 for less than and > 0 for greater than.
 */
function cmp(Slice self, Slice other) pure returns (int256 result) {
    uint256 selfLen = self.len();
    uint256 otherLen = other.len();
    uint256 minLen = selfLen;
    if (otherLen < minLen) {
        minLen = otherLen;
    }

    result = memcmp(self.ptr(), other.ptr(), minLen);
    if (result == 0) {
        // the longer slice is greater than its prefix
        // (lengths take only 16 bytes, so signed sub is safe)
        unchecked {
            return int256(selfLen) - int256(otherLen);
        }
    }
    // if not equal, return the diff sign
    return result;
}

/// @dev self == other
/// Note more efficient than cmp
function eq(Slice self, Slice other) pure returns (bool) {
    uint256 selfLen = self.len();
    if (selfLen != other.len()) return false;
    return memeq(self.ptr(), other.ptr(), selfLen);
}

/// @dev self != other
/// Note more efficient than cmp
function ne(Slice self, Slice other) pure returns (bool) {
    uint256 selfLen = self.len();
    if (selfLen != other.len()) return true;
    return !memeq(self.ptr(), other.ptr(), selfLen);
}

/// @dev `self` < `other`
function lt(Slice self, Slice other) pure returns (bool) {
    return self.cmp(other) < 0;
}

/// @dev `self` <= `other`
function lte(Slice self, Slice other) pure returns (bool) {
    return self.cmp(other) <= 0;
}

/// @dev `self` > `other`
function gt(Slice self, Slice other) pure returns (bool) {
    return self.cmp(other) > 0;
}

/// @dev `self` >= `other`
function gte(Slice self, Slice other) pure returns (bool) {
    return self.cmp(other) >= 0;
}

/**
 * @dev Returns the byte at `index`.
 * Reverts if index is out of bounds.
 */
function get(Slice self, uint256 index) pure returns (uint8 item) {
    if (index >= self.len()) revert Slice__OutOfBounds();

    // ptr and len are uint128 (because PackPtrLen); index < len
    unchecked {
        return mload8(self.ptr() + index);
    }
}

/**
 * @dev Returns the first byte of the slice.
 * Reverts if the slice is empty.
 */
function first(Slice self) pure returns (uint8 item) {
    if (self.len() == 0) revert Slice__OutOfBounds();
    return mload8(self.ptr());
}

/**
 * @dev Returns the last byte of the slice.
 * Reverts if the slice is empty.
 */
function last(Slice self) pure returns (uint8 item) {
    uint256 selfLen = self.len();
    if (selfLen == 0) revert Slice__OutOfBounds();
    // safe because selfLen > 0 (ptr+len is implicitly safe)
    unchecked {
        return mload8(self.ptr() + (selfLen - 1));
    }
}

/**
 * @dev Divides one slice into two at an index.
 */
function splitAt(Slice self, uint256 mid) pure returns (Slice, Slice) {
    uint256 selfPtr = self.ptr();
    uint256 selfLen = self.len();
    if (mid > selfLen) revert Slice__OutOfBounds();
    return (Slice__.fromUnchecked(selfPtr, mid), Slice__.fromUnchecked(selfPtr + mid, selfLen - mid));
}

/**
 * @dev Returns a subslice [start:end] of `self`.
 * Reverts if start/end are out of bounds.
 */
function getSubslice(
    Slice self,
    uint256 start,
    uint256 end
) pure returns (Slice) {
    if (!(start <= end && end <= self.len())) revert Slice__OutOfBounds();
    // selfPtr + start is safe because start <= selfLen (pointers are implicitly safe)
    // end - start is safe because start <= end
    unchecked {
        return Slice__.fromUnchecked(self.ptr() + start, end - start);
    }
}

/**
 * @dev Returns a subslice [:index] of `self`.
 * Reverts if `index` > length.
 */
function getBefore(Slice self, uint256 index) pure returns (Slice) {
    uint256 selfLen = self.len();
    if (index > selfLen) revert Slice__OutOfBounds();
    return Slice__.fromUnchecked(self.ptr(), index);
}

/**
 * @dev Returns a subslice [index:] of `self`.
 * Reverts if `index` > length.
 */
function getAfter(Slice self, uint256 index) pure returns (Slice) {
    uint256 selfLen = self.len();
    if (index > selfLen) revert Slice__OutOfBounds();
    // safe because index <= selfLen (ptr+len is implicitly safe)
    unchecked {
        return Slice__.fromUnchecked(self.ptr() + index, selfLen - index);
    }
}

/**
 * @dev Returns a non-zero subslice [index:] of `self`.
 * Reverts if `index` >= length.
 */
function getAfterStrict(Slice self, uint256 index) pure returns (Slice) {
    uint256 selfLen = self.len();
    if (index >= selfLen) revert Slice__OutOfBounds();
    // safe because index < selfLen (ptr+len is implicitly safe)
    unchecked {
        return Slice__.fromUnchecked(self.ptr() + index, selfLen - index);
    }
}

/**
 * @dev Returns the byte index of the first slice of `self` that matches `pattern`.
 * Returns type(uint256).max if the `pattern` does not match.
 */
function find(Slice self, Slice pattern) pure returns (uint256) {
    // offsetLen == selfLen initially, then starts shrinking
    uint256 offsetLen = self.len();
    uint256 patLen = pattern.len();
    if (patLen == 0) {
        return 0;
    } else if (offsetLen == 0 || patLen > offsetLen) {
        return type(uint256).max;
    }

    uint256 offsetPtr = self.ptr();
    uint256 patPtr = pattern.ptr();
    // low-level alternative to `first()` (safe because patLen != 0)
    uint8 patFirst = mload8(patPtr);

    while (true) {
        uint256 index = memchr(offsetPtr, offsetLen, patFirst);
        // not found
        if (index == type(uint256).max) return type(uint256).max;

        // move pointer to the found byte
        // safe because index < offsetLen (ptr+len is implicitly safe)
        unchecked {
            offsetPtr += index;
            offsetLen -= index;
        }
        // can't find, pattern won't fit after index
        if (patLen > offsetLen) {
            return type(uint256).max;
        }

        if (memeq(offsetPtr, patPtr, patLen)) {
            // found, return offset index
            return (offsetPtr - self.ptr());
        } else if (offsetLen == 1) {
            // not found and this was the last character
            return type(uint256).max;
        } else {
            // not found and can keep going;
            // increment pointer, memchr shouldn't receive what it returned (otherwise infinite loop)
            unchecked {
                // safe because offsetLen > 1 (see offsetLen -= index, and index < offsetLen)
                offsetPtr++;
                offsetLen--;
            }
        }
    }
    return type(uint256).max;
}

/**
 * @dev Returns the byte index of the last slice of `self` that matches `pattern`.
 * Returns type(uint256).max if the `pattern` does not match.
 */
function rfind(Slice self, Slice pattern) pure returns (uint256) {
    // offsetLen == selfLen initially, then starts shrinking
    uint256 offsetLen = self.len();
    uint256 patLen = pattern.len();
    if (patLen == 0) {
        return 0;
    } else if (offsetLen == 0 || patLen > offsetLen) {
        return type(uint256).max;
    }

    uint256 selfPtr = self.ptr();
    uint256 patPtr = pattern.ptr();
    uint8 patLast = pattern.last();
    // using indexes instead of lengths saves some gas on redundant increments/decrements
    uint256 patLastIndex;
    // safe because of patLen == 0 check earlier
    unchecked {
        patLastIndex = patLen - 1;
    }

    while (true) {
        uint256 endIndex = memrchr(selfPtr, offsetLen, patLast);
        // not found
        if (endIndex == type(uint256).max) return type(uint256).max;
        // can't find, pattern won't fit after index
        if (patLastIndex > endIndex) return type(uint256).max;

        // (endIndex - patLastIndex is safe because of the check just earlier)
        // (selfPtr + startIndex is safe because startIndex <= endIndex < offsetLen <= selfLen)
        // (ptr+len is implicitly safe)
        unchecked {
            // need startIndex, but memrchr returns endIndex
            uint256 startIndex = endIndex - patLastIndex;

            if (memeq(selfPtr + startIndex, patPtr, patLen)) {
                // found, return index
                return startIndex;
            } else if (endIndex > 0) {
                // not found and can keep going;
                // "decrement pointer", memrchr shouldn't receive what it returned
                // (index is basically a decremented length already, saves an op)
                // (I could even use 1 variable for both, but that'd be too confusing)
                offsetLen = endIndex;
                // an explicit continue is better for optimization here
                continue;
            } else {
                // not found and this was the last character
                return type(uint256).max;
            }
        }
    }
    return type(uint256).max;
}

/**
 * @dev Returns true if the given pattern matches a sub-slice of this `bytes` slice.
 */
function contains(Slice self, Slice pattern) pure returns (bool) {
    return self.find(pattern) != type(uint256).max;
}

/**
 * @dev Returns true if the given pattern matches a prefix of this slice.
 */
function startsWith(Slice self, Slice pattern) pure returns (bool) {
    uint256 selfLen = self.len();
    uint256 patLen = pattern.len();
    if (selfLen < patLen) return false;

    Slice prefix = self;
    // make prefix's length equal patLen
    if (selfLen > patLen) {
        prefix = self.getBefore(patLen);
    }
    return prefix.eq(pattern);
}

/**
 * @dev Returns true if the given pattern matches a suffix of this slice.
 */
function endsWith(Slice self, Slice pattern) pure returns (bool) {
    uint256 selfLen = self.len();
    uint256 patLen = pattern.len();
    if (selfLen < patLen) return false;

    Slice suffix = self;
    // make suffix's length equal patLen
    if (selfLen > patLen) {
        suffix = self.getAfter(selfLen - patLen);
    }
    return suffix.eq(pattern);
}

/**
 * @dev Returns a subslice with the prefix removed.
 * If it does not start with `prefix`, returns `self` unmodified.
 */
function stripPrefix(Slice self, Slice pattern) pure returns (Slice) {
    uint256 selfLen = self.len();
    uint256 patLen = pattern.len();
    if (patLen > selfLen) return self;

    (Slice prefix, Slice suffix) = self.splitAt(patLen);

    if (prefix.eq(pattern)) {
        return suffix;
    } else {
        return self;
    }
}

/**
 * @dev Returns a subslice with the suffix removed.
 * If it does not end with `suffix`, returns `self` unmodified.
 */
function stripSuffix(Slice self, Slice pattern) pure returns (Slice) {
    uint256 selfLen = self.len();
    uint256 patLen = pattern.len();
    if (patLen > selfLen) return self;

    uint256 index;
    // safe because selfLen >= patLen
    unchecked {
        index = selfLen - patLen;
    }
    (Slice prefix, Slice suffix) = self.splitAt(index);

    if (suffix.eq(pattern)) {
        return prefix;
    } else {
        return self;
    }
}

/**
 * @dev Returns an iterator over the slice.
 * The iterator yields items from either side.
 */
function iter(Slice self) pure returns (SliceIter memory) {
    return SliceIter__.from(self);
}
