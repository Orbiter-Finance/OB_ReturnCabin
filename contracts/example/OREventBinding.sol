// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IOREventBinding} from "../interface/IOREventBinding.sol";

// TODO: for dev
import "hardhat/console.sol";

contract OREventBinding {
    function getAmountSecurityCode(uint amount) public pure returns (uint16) {
        return uint16(amount % 10000);
    }

    /**
     * Get preview
     * @param amount Source tx amount
     * @param dest Dest account address
     * @param ruleValues [minPrice, maxPrice, withholdingFee, tradeFee]
     */
    function getResponsePreview(
        uint amount,
        address dest,
        uint[] calldata ruleValues
    ) external pure returns (bytes memory) {
        uint16 securityCode = getAmountSecurityCode(amount);
        require(securityCode > 0, "SCZ");

        uint tradeAmount = amount - securityCode;
        require(tradeAmount > ruleValues[0], "MINOF");
        require(tradeAmount < ruleValues[1], "MAXOF");

        uint fee = (tradeAmount * ruleValues[3]) / 10000 + ruleValues[2];
        require(tradeAmount > fee, "FOF");

        uint responseAmount = tradeAmount - fee;

        return abi.encode(dest, responseAmount);
    }
}
