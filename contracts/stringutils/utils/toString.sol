// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

uint256 constant ASCII_DIGIT_OFFSET = 0x30;
// 96 = 78 rounded up to a multiple of 32
// 78 = ceil(log10(2**256))
uint256 constant MAX_UINT256_STRING_LENGTH = 96;

/**
 * @dev uint256 to string (decimal).
 * WARNING: this function is very optimized for gas, it's almost pure assembly.
 * Just use OpenZeppelin's toString for safety and readability.
 *
 * (this is ~100 gas/digit, OZ is ~1000)
 *
 * Derived from https://github.com/moodlezoup/sol2string
 */
function toString(uint256 value) pure returns (string memory str) {
    if (value <= 9) {
        // very fast path for 1 digit
        /// @solidity memory-safe-assembly
        assembly {
            // allocate memory (0x20 for length, 0x20 for content)
            str := mload(0x40)
            mstore(0x40, add(str, 0x40))
            // store length
            mstore(str, 1)
            // store content
            mstore8(add(str, 0x20), add(value, ASCII_DIGIT_OFFSET))
        }
        return str;
    }

    uint256 startPtr;
    uint256 slidingPtr;
    /// @solidity memory-safe-assembly
    assembly {
        // slidingPtr is confusing, here's an example if MAX_UINT256_STRING_LENGTH were equal 5:
        //  length (0x20)                                                    (5)
        // |0000000000000000000000000000000000000000000000000000000000000000|0000000000|
        //  ^startPtr ^slidingPtr; mstore will write to the 32 bytes which end   here ^
        //           <== and the pointer slides from right to left, filling each LSB

        startPtr := mload(0x40)
        // note how slidingPtr doesn't include 0x20 for length
        slidingPtr := add(startPtr, MAX_UINT256_STRING_LENGTH)
        // overallocate memory
        // 0x20 for length, MAX_UINT256_STRING_LENGTH for content
        mstore(0x40, add(0x20, slidingPtr))
    }

    // populate from right to left (lsb to msb)
    while (value != 0) {
        /// @solidity memory-safe-assembly
        assembly {
            let char := add(mod(value, 10), ASCII_DIGIT_OFFSET)
            mstore(slidingPtr, char)
            slidingPtr := sub(slidingPtr, 1)
            value := div(value, 10)
        }
    }

    /// @solidity memory-safe-assembly
    assembly {
        let realLen := sub(MAX_UINT256_STRING_LENGTH, sub(slidingPtr, startPtr))
        // move `str` pointer to the start of the string
        str := slidingPtr
        // store the real length
        mstore(str, realLen)
    }
    return str;
}
