// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {mload8} from "./utils/mem.sol";
import {Slice, Slice__} from "./Slice.sol";

/**
 * @title Slice iterator.
 * @dev This struct is created by the iter method on `Slice`.
 * Iterates only 1 byte (uint8) at a time.
 */
struct SliceIter {
    uint256 _ptr;
    uint256 _len;
}

/*//////////////////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
//////////////////////////////////////////////////////////////////////////*/

error SliceIter__StopIteration();

/*//////////////////////////////////////////////////////////////////////////
                              STATIC FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

library SliceIter__ {
    /**
     * @dev Creates a new `SliceIter` from `Slice`.
     * Note the `Slice` is assumed to be memory-safe.
     */
    function from(Slice slice) internal pure returns (SliceIter memory) {
        return SliceIter(slice.ptr(), slice.len());
    }
}

/*//////////////////////////////////////////////////////////////////////////
                              GLOBAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {asSlice, ptr, len, isEmpty, next, nextBack} for SliceIter global;

/**
 * @dev Views the underlying data as a subslice of the original data.
 */
function asSlice(SliceIter memory self) pure returns (Slice slice) {
    return Slice__.fromUnchecked(self._ptr, self._len);
}

/**
 * @dev Returns the pointer to the start of an in-memory slice.
 */
function ptr(SliceIter memory self) pure returns (uint256) {
    return self._ptr;
}

/**
 * @dev Returns the length in bytes.
 */
function len(SliceIter memory self) pure returns (uint256) {
    return self._len;
}

/**
 * @dev Returns true if the iterator is empty.
 */
function isEmpty(SliceIter memory self) pure returns (bool) {
    return self._len == 0;
}

/**
 * @dev Advances the iterator and returns the next value.
 * Reverts if len == 0.
 */
function next(SliceIter memory self) pure returns (uint8 value) {
    uint256 selfPtr = self._ptr;
    uint256 selfLen = self._len;
    if (selfLen == 0) revert SliceIter__StopIteration();

    // safe because selfLen != 0 (ptr+len is implicitly safe and 1<=len)
    unchecked {
        // advance the iterator
        self._ptr = selfPtr + 1;
        self._len = selfLen - 1;
    }

    return mload8(selfPtr);
}

/**
 * @dev Advances the iterator from the back and returns the next value.
 * Reverts if len == 0.
 */
function nextBack(SliceIter memory self) pure returns (uint8 value) {
    uint256 selfPtr = self._ptr;
    uint256 selfLen = self._len;
    if (selfLen == 0) revert SliceIter__StopIteration();

    // safe because selfLen != 0 (ptr+len is implicitly safe)
    unchecked {
        // advance the iterator
        self._len = selfLen - 1;

        return mload8(selfPtr + (selfLen - 1));
    }
}
