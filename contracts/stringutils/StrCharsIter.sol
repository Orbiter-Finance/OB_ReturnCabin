// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Slice, Slice__} from "./Slice.sol";
import {StrSlice} from "./StrSlice.sol";
import {SliceIter, SliceIter__, SliceIter__StopIteration} from "./SliceIter.sol";
import {StrChar, StrChar__, StrChar__InvalidUTF8} from "./StrChar.sol";
import {isValidUtf8, utf8CharWidth} from "./utils/utf8.sol";
import {leftMask} from "./utils/mem.sol";

/**
 * @title String chars iterator.
 * @dev This struct is created by the iter method on `StrSlice`.
 * Iterates 1 UTF-8 encoded character at a time (which may have 1-4 bytes).
 *
 * Note StrCharsIter iterates over UTF-8 encoded codepoints, not unicode scalar values.
 * This is mostly done for simplicity, since solidity doesn't care about unicode anyways.
 *
 * TODO think about actually adding char and unicode awareness?
 * https://github.com/devstein/unicode-eth attempts something like that
 */
struct StrCharsIter {
    uint256 _ptr;
    uint256 _len;
}

/*//////////////////////////////////////////////////////////////////////////
                                STATIC FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

library StrCharsIter__ {
    /**
     * @dev Creates a new `StrCharsIter` from `StrSlice`.
     * Note the `StrSlice` is assumed to be memory-safe.
     */
    function from(StrSlice slice) internal pure returns (StrCharsIter memory) {
        return StrCharsIter(slice.ptr(), slice.len());

        // TODO I'm curious about gas differences
        // return StrCharsIter(SliceIter__.from(str.asSlice()));
    }
}

/*//////////////////////////////////////////////////////////////////////////
                                GLOBAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {asStr, ptr, len, isEmpty, next, nextBack, unsafeNext, count, validateUtf8, unsafeCount} for StrCharsIter global;

/**
 * @dev Views the underlying data as a subslice of the original data.
 */
function asStr(StrCharsIter memory self) pure returns (StrSlice slice) {
    return StrSlice.wrap(Slice.unwrap(self.asSlice()));
}

/**
 * @dev Returns the pointer to the start of an in-memory string slice.
 * This method is primarily for internal use.
 */
function ptr(StrCharsIter memory self) pure returns (uint256) {
    return self._ptr;
}

/**
 * @dev Returns the length in bytes, not codepoints.
 */
function len(StrCharsIter memory self) pure returns (uint256) {
    return self._len;
}

/**
 * @dev Returns true if the iterator is empty.
 */
function isEmpty(StrCharsIter memory self) pure returns (bool) {
    return self._len == 0;
}

/**
 * @dev Advances the iterator and returns the next character.
 * Reverts if len == 0.
 * Reverts on invalid UTF-8.
 */
function next(StrCharsIter memory self) pure returns (StrChar) {
    if (self._len == 0) revert SliceIter__StopIteration();
    (bytes32 b, uint256 charLen) = self._nextRaw(true);
    // safe because _nextRaw guarantees charLen <= selfLen as long as selfLen != 0.
    unchecked {
        // charLen > 0 because of `revertOnInvalid` flag
        self._len -= charLen;
    }
    // safe because _nextRaw reverts on invalid UTF-8
    return StrChar__.fromUnchecked(b, charLen);
}

/**
 * @dev Advances the iterator from the back and returns the next character.
 * Reverts if len == 0.
 * Reverts on invalid UTF-8.
 */
function nextBack(StrCharsIter memory self) pure returns (StrChar char) {
    if (self._len == 0) revert SliceIter__StopIteration();

    // _self shares memory with self!
    SliceIter memory _self = self._sliceIter();

    bool isValid;
    uint256 b;
    for (uint256 i; i < 4; i++) {
        // an example of what's going on in the loop:
        // b = 0x0000000000..00
        // nextBack = 0x80
        // b = 0x8000000000..00 (not valid UTF-8)
        // nextBack = 0x92
        // b = 0x9280000000..00 (not valid UTF-8)
        // nextBack = 0x9F
        // b = 0x9F92800000..00 (not valid UTF-8)
        // nextBack = 0xF0
        // b = 0xF09F928000..00 (valid UTF-8, break)

        // safe because i < 4
        unchecked {
            // free the space in MSB
            b =
                (b >> 8) |
                (// get 1 byte in LSB
                uint256(_self.nextBack()) <<
                    // flip it to MSB
                    (31 * 8));
        }
        // break if the char is valid
        if (isValidUtf8(bytes32(b)) != 0) {
            isValid = true;
            break;
        }
    }
    if (!isValid) revert StrChar__InvalidUTF8();

    // construct the character;
    // wrap is safe, because UTF-8 was validated,
    // and the trailing bytes are 0 (since the loop went byte-by-byte)
    char = StrChar.wrap(bytes32(b));
    // the iterator was already advanced by `_self.nextBack()`
    return char;
}

/**
 * @dev Advances the iterator and returns the next character.
 * Does NOT validate iterator length. It could underflow!
 * Does NOT revert on invalid UTF-8.
 * WARNING: for invalid UTF-8 bytes, advances by 1 and returns an invalid `StrChar` with len 0!
 */
function unsafeNext(StrCharsIter memory self) pure returns (StrChar char) {
    // _nextRaw guarantees charLen <= selfLen IF selfLen != 0
    (bytes32 b, uint256 charLen) = self._nextRaw(false);
    if (charLen > 0) {
        // safe IF the caller ensures that self._len != 0
        unchecked {
            self._len -= charLen;
        }
        // ALWAYS produces a valid character
        return StrChar__.fromUnchecked(b, charLen);
    } else {
        // safe IF the caller ensures that self._len != 0
        unchecked {
            self._len -= 1;
        }
        // NEVER produces a valid character (this is always a single 0x80-0xFF byte)
        return StrChar__.fromUnchecked(b, 1);
    }
}

/**
 * @dev Consumes the iterator, counting the number of UTF-8 characters.
 * Note O(n) time!
 * Reverts on invalid UTF-8.
 */
function count(StrCharsIter memory self) pure returns (uint256 result) {
    uint256 endPtr;
    // (ptr+len is implicitly safe)
    unchecked {
        endPtr = self._ptr + self._len;
    }
    while (self._ptr < endPtr) {
        self._nextRaw(true);
        // +1 is safe because 2**256 cycles are impossible
        unchecked {
            result += 1;
        }
    }
    // _nextRaw does NOT modify len to allow optimizations like setting it once at the end
    self._len = 0;
    return result;
}

/**
 * @dev Consumes the iterator, validating UTF-8 characters.
 * Note O(n) time!
 * Returns true if all are valid; otherwise false on the first invalid UTF-8 character.
 */
function validateUtf8(StrCharsIter memory self) pure returns (bool) {
    uint256 endPtr;
    // (ptr+len is implicitly safe)
    unchecked {
        endPtr = self._ptr + self._len;
    }
    while (self._ptr < endPtr) {
        (, uint256 charLen) = self._nextRaw(false);
        if (charLen == 0) return false;
    }
    return true;
}

/**
 * @dev VERY UNSAFE - a single invalid UTF-8 character can severely alter the result!
 * Consumes the iterator, counting the number of UTF-8 characters.
 * Significantly faster than safe `count`, especially for long mutlibyte strings.
 *
 * Note `count` is actually a bit more efficient than `validateUtf8`.
 * `count` is much more efficient than calling `validateUtf8` and `unsafeCount` together.
 * Use `unsafeCount` only when you are already certain that UTF-8 is valid.
 * If you want speed and no validation, just use byte length, it's faster and more predictably wrong.
 *
 * Some gas usage metrics:
 * 1 ascii char:
 *   count:       571 gas
 *   unsafeCount: 423 gas
 * 100 ascii chars:
 *   count:       27406 gas
 *   unsafeCount: 12900 gas
 * 1000 chinese chars (3000 bytes):
 *   count:       799305 gas
 *   unsafeCount: 178301 gas
 */
function unsafeCount(StrCharsIter memory self) pure returns (uint256 result) {
    uint256 endPtr;
    // (ptr+len is implicitly safe)
    unchecked {
        endPtr = self._ptr + self._len;
    }
    while (self._ptr < endPtr) {
        uint256 leadingByte;
        // unchecked mload
        // (unsafe, the last character could move the pointer past the boundary, but only once)
        /// @solidity memory-safe-assembly
        assembly {
            leadingByte := byte(
                0,
                mload(
                    // load self._ptr (this is an optimization trick, since it's 1st in the struct)
                    mload(self)
                )
            )
        }
        unchecked {
            // this is a very unsafe version of `utf8CharWidth`,
            // basically 1 invalid UTF-8 character can severely change the count result
            // (no real infinite loop risks, only one potential corrupt memory read)
            if (leadingByte < 0x80) {
                self._ptr += 1;
            } else if (leadingByte < 0xE0) {
                self._ptr += 2;
            } else if (leadingByte < 0xF0) {
                self._ptr += 3;
            } else {
                self._ptr += 4;
            }
            // +1 is safe because 2**256 cycles are impossible
            result += 1;
        }
    }
    self._len = 0;

    return result;
}

/*//////////////////////////////////////////////////////////////////////////
                            FILE-LEVEL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {asSlice, _nextRaw, _sliceIter} for StrCharsIter;

/**
 * @dev Views the underlying data as a `bytes` subslice of the original data.
 */
function asSlice(StrCharsIter memory self) pure returns (Slice slice) {
    return Slice__.fromUnchecked(self._ptr, self._len);
}

/**
 * @dev Used internally to efficiently reuse iteration logic. Has a lot of caveats.
 * NEITHER checks NOR modifies iterator length.
 * (Caller MUST guarantee that len != 0. Caller MUST modify len correctly themselves.)
 * Does NOT form the character properly, and returns raw unmasked bytes and length.
 * Does advance the iterator pointer.
 *
 * Validates UTF-8.
 * For valid chars advances the pointer by charLen.
 * For invalid chars behaviour depends on `revertOnInvalid`:
 * revertOnInvalid == true: revert.
 * revertOnInvalid == false: advance the pointer by 1, but return charLen 0.
 *
 * @return b raw unmasked bytes; if not discarded, then charLen SHOULD be used to mask it.
 * @return charLen length of a valid UTF-8 char; 0 for invalid chars.
 * Guarantees that charLen <= self._len (as long as self._len != 0, which is the caller's guarantee)
 */
function _nextRaw(StrCharsIter memory self, bool revertOnInvalid) pure returns (bytes32 b, uint256 charLen) {
    // unchecked mload
    // (isValidUtf8 only checks the 1st character, which exists since caller guarantees len != 0)
    /// @solidity memory-safe-assembly
    assembly {
        b := mload(
            // load self._ptr (this is an optimization trick, since it's 1st in the struct)
            mload(self)
        )
    }
    // validate character (0 => invalid; 1-4 => valid)
    charLen = isValidUtf8(b);

    if (charLen > self._len) {
        // mload didn't check bounds,
        // so a character that goes out of bounds could've been seen as valid.
        if (revertOnInvalid) revert StrChar__InvalidUTF8();
        // safe because caller guarantees _len != 0
        unchecked {
            self._ptr += 1;
        }
        // invalid
        return (b, 0);
    } else if (charLen == 0) {
        if (revertOnInvalid) revert StrChar__InvalidUTF8();
        // safe because caller guarantees _len != 0
        unchecked {
            self._ptr += 1;
        }
        // invalid
        return (b, 0);
    } else {
        // safe because of the `charLen > self._len` check earlier
        unchecked {
            self._ptr += charLen;
        }
        // valid
        return (b, charLen);
    }
}

/**
 * @dev Returns the underlying `SliceIter`.
 * AVOID USING THIS EXTERNALLY!
 * Advancing the underlying slice could lead to invalid UTF-8 for StrCharsIter.
 */
function _sliceIter(StrCharsIter memory self) pure returns (SliceIter memory result) {
    assembly {
        result := self
    }
}
