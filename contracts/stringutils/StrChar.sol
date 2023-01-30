// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {isValidUtf8 as _isValidUtf8, utf8CharWidth} from "./utils/utf8.sol";
import {decodeUtf8, encodeUtf8} from "./utils/unicode.sol";
import {leftMask} from "./utils/mem.sol";

/**
 * @title A single UTF-8 encoded character.
 * @dev Internally it is stored as UTF-8 encoded bytes starting from left/MSB.
 */
type StrChar is bytes32;

/*//////////////////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
//////////////////////////////////////////////////////////////////////////*/

error StrChar__InvalidUTF8();

/*//////////////////////////////////////////////////////////////////////////
                              STATIC FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

library StrChar__ {
    /**
     * @dev Converts the first 1-4 bytes of `bytes32` to a `StrChar`.
     * Starts from left/MSB, reverts if not valid UTF-8.
     * @param b UTF-8 encoded character in the most significant bytes.
     */
    function from(bytes32 b) internal pure returns (StrChar char) {
        uint256 charLen = _isValidUtf8(b);
        if (charLen == 0) revert StrChar__InvalidUTF8();
        return fromUnchecked(b, charLen);
    }

    /**
     * @dev Converts a unicode code point to a `StrChar`.
     * E.g. for '€' code point = 0x20AC; wheareas UTF-8 = 0xE282AC.
     */
    function fromCodePoint(uint256 code) internal pure returns (StrChar char) {
        return StrChar.wrap(encodeUtf8(code));
    }

    /**
     * @dev Like `from`, but does NO validity checks.
     * Uses provided `_len` instead of calculating it. This allows invalid/malformed characters.
     *
     * MSB of `bytes32` SHOULD be valid UTF-8.
     * And `bytes32` SHOULD be zero-padded after the first UTF-8 character.
     * Primarily for internal use.
     */
    function fromUnchecked(bytes32 b, uint256 _len) internal pure returns (StrChar char) {
        return
            StrChar.wrap(
                bytes32(
                    // zero-pad after the character
                    uint256(b) & leftMask(_len)
                )
            );
    }
}

/*//////////////////////////////////////////////////////////////////////////
                                GLOBAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {len, toBytes32, toString, toCodePoint, cmp, eq, ne, lt, lte, gt, gte, isValidUtf8, isAscii} for StrChar global;

/**
 * @dev Returns the character's length in bytes (1-4).
 * Returns 0 for some (not all!) invalid characters (e.g. due to unsafe use of fromUnchecked).
 */
function len(StrChar self) pure returns (uint256) {
    return
        utf8CharWidth(
            // extract the leading byte
            uint256(uint8(StrChar.unwrap(self)[0]))
        );
}

/**
 * @dev Converts a `StrChar` to its underlying bytes32 value.
 */
function toBytes32(StrChar self) pure returns (bytes32) {
    return StrChar.unwrap(self);
}

/**
 * @dev Converts a `StrChar` to a newly allocated `string`.
 */
function toString(StrChar self) pure returns (string memory str) {
    uint256 _len = self.len();
    str = new string(_len);
    /// @solidity memory-safe-assembly
    assembly {
        mstore(add(str, 0x20), self)
    }
    return str;
}

/**
 * @dev Converts a `StrChar` to its unicode code point (aka unicode scalar value).
 */
function toCodePoint(StrChar self) pure returns (uint256) {
    return decodeUtf8(StrChar.unwrap(self));
}

/**
 * @dev Compare characters lexicographically.
 * @return result 0 for equal, < 0 for less than and > 0 for greater than.
 */
function cmp(StrChar self, StrChar other) pure returns (int256 result) {
    uint256 selfUint = uint256(StrChar.unwrap(self));
    uint256 otherUint = uint256(StrChar.unwrap(other));
    if (selfUint > otherUint) {
        return 1;
    } else if (selfUint < otherUint) {
        return -1;
    } else {
        return 0;
    }
}

/// @dev `self` == `other`
function eq(StrChar self, StrChar other) pure returns (bool) {
    return uint256(StrChar.unwrap(self)) == uint256(StrChar.unwrap(other));
}

/// @dev `self` != `other`
function ne(StrChar self, StrChar other) pure returns (bool) {
    return uint256(StrChar.unwrap(self)) != uint256(StrChar.unwrap(other));
}

/// @dev `self` < `other`
function lt(StrChar self, StrChar other) pure returns (bool) {
    return uint256(StrChar.unwrap(self)) < uint256(StrChar.unwrap(other));
}

/// @dev `self` <= `other`
function lte(StrChar self, StrChar other) pure returns (bool) {
    return uint256(StrChar.unwrap(self)) <= uint256(StrChar.unwrap(other));
}

/// @dev `self` > `other`
function gt(StrChar self, StrChar other) pure returns (bool) {
    return uint256(StrChar.unwrap(self)) > uint256(StrChar.unwrap(other));
}

/// @dev `self` >= `other`
function gte(StrChar self, StrChar other) pure returns (bool) {
    return uint256(StrChar.unwrap(self)) >= uint256(StrChar.unwrap(other));
}

/**
 * @dev Returns true if `StrChar` is valid UTF-8.
 * Can be false if it was formed with an unsafe method (fromUnchecked, wrap).
 */
function isValidUtf8(StrChar self) pure returns (bool) {
    return _isValidUtf8(StrChar.unwrap(self)) != 0;
}

/**
 * @dev Returns true if `StrChar` is within the ASCII range.
 */
function isAscii(StrChar self) pure returns (bool) {
    return StrChar.unwrap(self)[0] < 0x80;
}
