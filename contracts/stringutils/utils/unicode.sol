// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {utf8CharWidth} from "./utf8.sol";

/*
 * IMPORTANT: Here `uint256` represents 1 code point (aka unicode scalar values),
 * NOT a UTF-8 encoded character!
 * E.g. for '€' code point = 0x20AC; wheareas UTF-8 encoding = 0xE282AC.
 *
 * Only conversion to/from UTF-8 is addressed here.
 * Note that UTF-16 surrogate halves are invalid code points even if UTF-16 was supported.
 */

error Unicode__InvalidCode();

/// @dev The highest valid code point.
uint256 constant MAX = 0x10FFFF;

// UTF-8 ranges
uint256 constant MAX_ONE_B = 0x80;
uint256 constant MAX_TWO_B = 0x800;
uint256 constant MAX_THREE_B = 0x10000;
// and tags for encoding characters
uint256 constant TAG_CONT = 0x80;
uint256 constant TAG_TWO_B = 0xC0;
uint256 constant TAG_THREE_B = 0xE0;
uint256 constant TAG_FOUR_B = 0xF0;
// and continuation byte mask
uint256 constant MASK_CONT = 0x3F;

/**
 * @dev Encodes a unicode code point as UTF-8.
 * Reverts if the code point is invalid.
 * The result is 1-4 bytes starting at MSB.
 */
function encodeUtf8(uint256 code) pure returns (bytes32) {
    if (code < MAX_ONE_B) {
        return bytes32((code) << (31 * 8));
    } else if (code < MAX_TWO_B) {
        return bytes32((((code >> 6) | TAG_TWO_B) << (31 * 8)) | (((code & MASK_CONT) | TAG_CONT) << (30 * 8)));
    } else if (code < MAX_THREE_B) {
        if (code & 0xF800 == 0xD800) {
            // equivalent to `code >= 0xD800 && code <= 0xDFFF`
            // U+D800–U+DFFF are invalid UTF-16 surrogate halves
            revert Unicode__InvalidCode();
        }
        return
            bytes32(
                (((code >> 12) | TAG_THREE_B) << (31 * 8)) |
                    ((((code >> 6) & MASK_CONT) | TAG_CONT) << (30 * 8)) |
                    (((code & MASK_CONT) | TAG_CONT) << (29 * 8))
            );
    } else if (code <= MAX) {
        return
            bytes32(
                (((code >> 18) | TAG_FOUR_B) << (31 * 8)) |
                    ((((code >> 12) & MASK_CONT) | TAG_CONT) << (30 * 8)) |
                    ((((code >> 6) & MASK_CONT) | TAG_CONT) << (29 * 8)) |
                    (((code & MASK_CONT) | TAG_CONT) << (28 * 8))
            );
    } else {
        revert Unicode__InvalidCode();
    }
}

/**
 * @dev Decodes a UTF-8 character into its code point.
 * Validates ONLY the leading byte, use `isValidCodePoint` on the result if UTF-8 wasn't validated.
 * The input is 1-4 bytes starting at MSB.
 */
function decodeUtf8(bytes32 str) pure returns (uint256) {
    uint256 leadingByte = uint256(uint8(str[0]));
    uint256 width = utf8CharWidth(leadingByte);

    if (width == 1) {
        return leadingByte;
    } else if (width == 2) {
        uint256 byte1 = uint256(uint8(str[1]));
        return
            uint256(
                // 0x1F = 0001_1111
                ((leadingByte & 0x1F) << 6) | (byte1 & MASK_CONT)
            );
    } else if (width == 3) {
        uint256 byte1 = uint256(uint8(str[1]));
        uint256 byte2 = uint256(uint8(str[2]));
        return
            uint256(
                // 0x0F = 0000_1111
                ((leadingByte & 0x0F) << 12) | ((byte1 & MASK_CONT) << 6) | (byte2 & MASK_CONT)
            );
    } else if (width == 4) {
        uint256 byte1 = uint256(uint8(str[1]));
        uint256 byte2 = uint256(uint8(str[2]));
        uint256 byte3 = uint256(uint8(str[3]));
        return
            uint256(
                // 0x07 = 0000_0111
                ((leadingByte & 0x07) << 18) |
                    ((byte1 & MASK_CONT) << 12) |
                    ((byte2 & MASK_CONT) << 6) |
                    (byte3 & MASK_CONT)
            );
    } else {
        revert Unicode__InvalidCode();
    }
}

/**
 * @dev Returns the length of a code point in UTF-8 encoding.
 * Does NOT validate it.
 * WARNING: atm this function is neither used nor tested in this repo
 */
function lenUtf8(uint256 code) pure returns (uint256) {
    if (code < MAX_ONE_B) {
        return 1;
    } else if (code < MAX_TWO_B) {
        return 2;
    } else if (code < MAX_THREE_B) {
        return 3;
    } else {
        return 4;
    }
}

/**
 * @dev Returns true if the code point is valid.
 * WARNING: atm this function is neither used nor tested in this repo
 */
function isValidCodePoint(uint256 code) pure returns (bool) {
    // U+D800–U+DFFF are invalid UTF-16 surrogate halves
    if (code < 0xD800) {
        return true;
    } else {
        return code > 0xDFFF && code <= MAX;
    }
}
