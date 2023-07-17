// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IOREventBinding} from "../interface/IOREventBinding.sol";

contract OREventBinding is IOREventBinding {
    function getSecurityCode(uint amount) public pure returns (uint) {
        return uint16(amount % 10000);
    }

    function splitSecurityCode(uint securityCode) public pure returns (uint[] memory) {
        uint[] memory splits = new uint[](3);

        unchecked {
            splits[0] = (securityCode / 1000) % 10;
            splits[1] = (securityCode / 100) % 10;
            splits[2] = securityCode % 100;
        }

        return splits;
    }

    function getAmountParams(uint amount) public pure returns (AmountParams memory) {
        uint[] memory splits = splitSecurityCode(getSecurityCode(amount));
        return AmountParams(splits[0], splits[1], splits[2]);
    }

    /**
     * Get preview
     * @param amount Source tx amount
     * @param ruleValues [minPrice, maxPrice, withholdingFee, tradeFee]
     */
    function getResponseIntent(uint amount, uint[] calldata ruleValues) external pure returns (bytes memory) {
        uint securityCode = getSecurityCode(amount);
        require(securityCode > 0, "SCZ");

        uint tradeAmount = amount - securityCode;
        require(tradeAmount > ruleValues[0], "MINOF");
        require(tradeAmount < ruleValues[1], "MAXOF");

        uint fee = (tradeAmount * ruleValues[3]) / 10000 + ruleValues[2];
        require(tradeAmount > fee, "FOF");

        uint responseAmount = tradeAmount - fee;

        return abi.encode(responseAmount);
    }
}
