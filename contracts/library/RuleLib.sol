// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

library RuleLib {
    struct Rule {
        uint16 chainId0;
        uint16 chainId1;
        uint8 status0;
        uint8 status1;
        uint token0;
        uint token1;
        uint128 minPrice;
        uint128 maxPrice;
        uint128 withholdingFee0;
        uint128 withholdingFee1;
        uint16 tradingFee0;
        uint16 tradingFee1;
        uint32 responseTime0;
        uint32 responseTime1;
        uint32 compensationRatio0;
        uint32 compensationRatio1;
    }

    function decode(bytes memory ruleBytes) internal pure returns (bytes32, Rule memory) {
        RuleLib.Rule memory _rule = abi.decode(ruleBytes, (RuleLib.Rule));

        require(_rule.chainId0 < _rule.chainId1, "C0LC1");

        bytes32 key = keccak256(abi.encodePacked(_rule.chainId0, _rule.chainId1, _rule.token0, _rule.token1));

        return (key, _rule);
    }

    // There is no direct abi.decode for bit operations to save gas
    // function decode(bytes memory ruleBytes) internal pure returns (Rule memory) {
    //     Rule memory rule;

    //     rule.chainId0 = _decode16(ruleBytes, 0);
    //     rule.chainId1 = _decode16(ruleBytes, 2);
    //     rule.status0 = uint8(ruleBytes[4]);
    //     rule.status1 = uint8(ruleBytes[5]);
    //     rule.token0 = _decode256(ruleBytes, 6);
    //     rule.token1 = _decode256(ruleBytes, 38);
    //     rule.minPrice = _decode128(ruleBytes, 70);
    //     rule.maxPrice = _decode128(ruleBytes, 86);
    //     rule.withholdingFee0 = _decode128(ruleBytes, 102);
    //     rule.withholdingFee1 = _decode128(ruleBytes, 118);
    //     rule.tradingFee0 = _decode16(ruleBytes, 134);
    //     rule.tradingFee1 = _decode16(ruleBytes, 136);
    //     rule.responseTime0 = _decode32(ruleBytes, 138);
    //     rule.responseTime1 = _decode32(ruleBytes, 142);
    //     rule.compensationRatio0 = _decode32(ruleBytes, 146);
    //     rule.compensationRatio1 = _decode32(ruleBytes, 150);

    //     return rule;
    // }

    // function _decode16(bytes memory b, uint start) internal pure returns (uint16) {
    //     return uint16(bytes2(b[start]) | (bytes2(b[start + 1]) >> 8));
    // }

    // function _decode32(bytes memory b, uint start) internal pure returns (uint32) {
    //     bytes4 b4 = bytes4(b[start]);

    //     unchecked {
    //         for (uint i = 1; i < 4; i++) {
    //             b4 = b4 | (bytes4(b[start + i]) >> (8 * i));
    //         }
    //     }

    //     return uint32(b4);
    // }

    // function _decode64(bytes memory b, uint start) internal pure returns (uint64) {
    //     bytes8 b8 = bytes8(b[start]);

    //     unchecked {
    //         for (uint i = 1; i < 8; i++) {
    //             b8 = b8 | (bytes8(b[start + i]) >> (8 * i));
    //         }
    //     }

    //     return uint64(b8);
    // }

    // function _decode128(bytes memory b, uint start) internal pure returns (uint128) {
    //     bytes16 b16 = bytes16(b[start]);

    //     unchecked {
    //         for (uint i = 1; i < 16; i++) {
    //             b16 = b16 | (bytes16(b[start + i]) >> (8 * i));
    //         }
    //     }

    //     return uint128(b16);
    // }

    // function _decode256(bytes memory b, uint start) internal pure returns (uint256) {
    //     bytes32 b32 = bytes32(b[start]);

    //     unchecked {
    //         for (uint i = 1; i < 32; i++) {
    //             b32 = b32 | (bytes32(b[start + i]) >> (8 * i));
    //         }
    //     }

    //     return uint256(b32);
    // }
}
