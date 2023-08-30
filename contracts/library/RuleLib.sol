// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {ConstantsLib} from "./ConstantsLib.sol";

library RuleLib {
    struct Rule {
        uint64 chainId0; // 59144
        uint64 chainId1; // 10
        uint8 status0;
        uint8 status1;
        uint token0;
        uint token1;
        uint128 minPrice0;
        uint128 minPrice1;
        uint128 maxPrice0;
        uint128 maxPrice1;
        uint128 withholdingFee0;
        uint128 withholdingFee1;
        uint32 tradingFee0;
        uint32 tradingFee1;
        uint32 responseTime0;
        uint32 responseTime1;
        uint32 compensationRatio0;
        uint32 compensationRatio1;
    }

    struct RootWithVersion {
        bytes32 root;
        uint32 version;
    }

    struct RuleOneway {
        uint64 sourceChainId;
        uint64 destChainId;
        uint8 status;
        uint sourceToken;
        uint destToken;
        uint128 minPrice;
        uint128 maxPrice;
        uint128 withholdingFee;
        uint32 tradingFee;
        uint32 responseTime;
        uint32 compensationRatio;
    }

    function checkChainIds(uint64 chainId0, uint64 chainId1) internal pure {
        require(chainId0 < chainId1, "C0LC1");
    }

    function checkWithholdingFees(uint128 withholdingFee0, uint128 withholdingFee1) internal pure {
        require(
            (withholdingFee0 / ConstantsLib.EBC_AMOUNT_PARAMS_MODULUS) * ConstantsLib.EBC_AMOUNT_PARAMS_MODULUS ==
                withholdingFee0,
            "WFI0"
        );
        require(
            (withholdingFee1 / ConstantsLib.EBC_AMOUNT_PARAMS_MODULUS) * ConstantsLib.EBC_AMOUNT_PARAMS_MODULUS ==
                withholdingFee1,
            "WFI1"
        );
    }

    function convertToOneway(
        Rule memory rule,
        uint64 sourceChainId
    ) internal pure returns (RuleOneway memory ruleOneway) {
        require(sourceChainId == rule.chainId0 || sourceChainId == rule.chainId1, "SCI");

        if (sourceChainId == rule.chainId0) {
            return
                RuleOneway(
                    rule.chainId0,
                    rule.chainId1,
                    rule.status0,
                    rule.token0,
                    rule.token1,
                    rule.minPrice0,
                    rule.maxPrice0,
                    rule.withholdingFee0,
                    rule.tradingFee0,
                    rule.responseTime0,
                    rule.compensationRatio0
                );
        } else {
            return
                RuleOneway(
                    rule.chainId1,
                    rule.chainId0,
                    rule.status1,
                    rule.token1,
                    rule.token0,
                    rule.minPrice1,
                    rule.maxPrice1,
                    rule.withholdingFee1,
                    rule.tradingFee1,
                    rule.responseTime1,
                    rule.compensationRatio1
                );
        }
    }
}
