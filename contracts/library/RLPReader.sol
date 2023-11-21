// SPDX-License-Identifier: Apache-2.0

/*
 * @author Hamdi Allam hamdi.allam97@gmail.com
 * Please reach out with any questions or concerns
 */
pragma solidity ^0.8.17;
import {RuleLib} from "../library/RuleLib.sol";

library RLPReader {
    uint8 constant STRING_SHORT_START = 0x80;
    uint8 constant STRING_LONG_START = 0xb8;
    uint8 constant LIST_SHORT_START = 0xc0;
    uint8 constant LIST_LONG_START = 0xf8;
    uint8 constant WORD_SIZE = 32;
    uint8 constant RULE_LENGTH = 18;

    struct RLPItem {
        uint256 len;
        uint256 memPtr;
    }

    function payloadLocation(RLPItem memory item) internal pure returns (uint256, uint256) {
        uint256 offset = _payloadOffset(item.memPtr);
        uint256 memPtr = item.memPtr + offset;
        uint256 len = item.len - offset; // data length
        return (memPtr, len);
    }

    function decodeRule(bytes memory item) internal pure returns (RuleLib.Rule memory rule) {
        uint256 memPtr;
        assembly {
            memPtr := add(item, 0x20)
        }
        RLPItem memory rlpItem = RLPItem(item.length, memPtr);
        require(item.length > 1);
        memPtr = rlpItem.memPtr + _payloadOffset(rlpItem.memPtr);
        uint256 dataLen;
        for (uint8 i = 0; ; ) {
            dataLen = _itemLength(memPtr);
            if (i == 0) {
                rule.chainId0 = uint64(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 1) {
                rule.chainId1 = uint64(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 2) {
                rule.status0 = uint8(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 3) {
                rule.status1 = uint8(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 4) {
                rule.token0 = toUint(RLPItem(dataLen, memPtr));
            } else if (i == 5) {
                rule.token1 = toUint(RLPItem(dataLen, memPtr));
            } else if (i == 6) {
                rule.minPrice0 = uint128(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 7) {
                rule.minPrice1 = uint128(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 8) {
                rule.maxPrice0 = uint128(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 9) {
                rule.maxPrice1 = uint128(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 10) {
                rule.withholdingFee0 = uint128(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 11) {
                rule.withholdingFee1 = uint128(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 12) {
                rule.tradingFee0 = uint32(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 13) {
                rule.tradingFee1 = uint32(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 14) {
                rule.responseTime0 = uint32(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 15) {
                rule.responseTime1 = uint32(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 16) {
                rule.compensationRatio0 = uint32(toUint(RLPItem(dataLen, memPtr)));
            } else if (i == 17) {
                rule.compensationRatio1 = uint32(toUint(RLPItem(dataLen, memPtr)));
            }
            memPtr = memPtr + dataLen;

            if (i == RULE_LENGTH - 1) {
                break;
            }

            unchecked {
                i += 1;
            }
        }
    }

    function toRlpItem(bytes memory item) internal pure returns (RLPItem[] memory) {
        uint256 memPtr;
        assembly {
            memPtr := add(item, 0x20)
        }
        RLPItem memory rlpItem = RLPItem(item.length, memPtr);
        require(item.length > 1);
        RLPItem[] memory result = new RLPItem[](RULE_LENGTH);
        memPtr = rlpItem.memPtr + _payloadOffset(rlpItem.memPtr);
        uint256 dataLen;
        for (uint256 i = 0; i < RULE_LENGTH; i++) {
            dataLen = _itemLength(memPtr);
            result[i] = RLPItem(dataLen, memPtr);
            memPtr = memPtr + dataLen;
        }
        return result;
    }

    function toUint(RLPItem memory item) internal pure returns (uint256) {
        require(item.len > 0 && item.len <= 33);

        (uint256 memPtr, uint256 len) = payloadLocation(item);

        uint256 result;
        assembly {
            result := mload(memPtr)
            if lt(len, 32) {
                result := div(result, exp(256, sub(32, len)))
            }
        }

        return result;
    }

    function numItems(RLPItem memory item) private pure returns (uint256) {
        if (item.len == 0) return 0;

        uint256 count = 0;
        uint256 currPtr = item.memPtr + _payloadOffset(item.memPtr);
        uint256 endPtr = item.memPtr + item.len;
        while (currPtr < endPtr) {
            currPtr = currPtr + _itemLength(currPtr); // skip over an item
            count++;
        }

        return count;
    }

    function _itemLength(uint256 memPtr) private pure returns (uint256) {
        uint256 itemLen;
        uint256 byte0;
        assembly {
            byte0 := byte(0, mload(memPtr))
        }

        if (byte0 < STRING_SHORT_START) {
            itemLen = 1;
        } else if (byte0 < STRING_LONG_START) {
            itemLen = byte0 - STRING_SHORT_START + 1;
        } else if (byte0 < LIST_SHORT_START) {
            assembly {
                let byteLen := sub(byte0, 0xb7) // # of bytes the actual length is
                memPtr := add(memPtr, 1) // skip over the first byte

                /* 32 byte word size */
                let dataLen := div(mload(memPtr), exp(256, sub(32, byteLen))) // right shifting to get the len
                itemLen := add(dataLen, add(byteLen, 1))
            }
        } else if (byte0 < LIST_LONG_START) {
            itemLen = byte0 - LIST_SHORT_START + 1;
        } else {
            assembly {
                let byteLen := sub(byte0, 0xf7)
                memPtr := add(memPtr, 1)

                let dataLen := div(mload(memPtr), exp(256, sub(32, byteLen))) // right shifting to the correct length
                itemLen := add(dataLen, add(byteLen, 1))
            }
        }

        return itemLen;
    }

    function _payloadOffset(uint256 memPtr) private pure returns (uint256) {
        uint256 byte0;
        assembly {
            byte0 := byte(0, mload(memPtr))
        }

        if (byte0 < STRING_SHORT_START) {
            return 0;
        } else if (byte0 < STRING_LONG_START || (byte0 >= LIST_SHORT_START && byte0 < LIST_LONG_START)) {
            return 1;
        } else if (byte0 < LIST_SHORT_START) {
            return byte0 - (STRING_LONG_START - 1) + 1;
        } else {
            return byte0 - (LIST_LONG_START - 1) + 1;
        }
    }
}
