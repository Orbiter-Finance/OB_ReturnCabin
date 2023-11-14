// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IOREventBinding} from "../interface/IOREventBinding.sol";
import {ConstantsLib} from "../library/ConstantsLib.sol";
import {RuleLib} from "../library/RuleLib.sol";

contract OREventBinding is IOREventBinding {
    function getSecurityCode(uint256 amount) public pure returns (uint256) {
        return uint16(amount % ConstantsLib.EBC_AMOUNT_PARAMS_MODULUS);
    }

    function splitSecurityCode(uint256 securityCode) public pure returns (uint256[] memory) {
        uint256[] memory splits = new uint256[](3);

        unchecked {
            splits[0] = securityCode / 1000;
            splits[1] = (securityCode / 100) % 10;
            splits[2] = securityCode % 100;
        }

        return splits;
    }

    function getAmountParams(uint256 amount) public pure returns (AmountParams memory) {
        uint256[] memory params = splitSecurityCode(getSecurityCode(amount));

        require(params[0] > 0, "P0Z");
        require(params[1] > 0, "P1Z");
        require(params[2] > 0, "P2Z");

        return AmountParams(params[0], params[1], params[2]);
    }

    /**
     * Get intent
     * @param amount Source tx amount
     * @param ro Rule oneway
     */
    function getResponseIntent(uint256 amount, RuleLib.RuleOneway calldata ro) external pure returns (bytes memory) {
        uint256 securityCode = getSecurityCode(amount);
        require(securityCode > 0, "SCZ");

        uint256 tradeAmount = amount - securityCode - ro.withholdingFee;
        require(tradeAmount >= ro.minPrice, "MINOF");
        require(tradeAmount <= ro.maxPrice, "MAXOF");

        uint256 fee = (tradeAmount * ro.tradingFee) / ConstantsLib.RATIO_MULTIPLE;
        require(tradeAmount > fee, "FOF");

        uint256 responseAmount = ((tradeAmount - fee) / ConstantsLib.EBC_AMOUNT_PARAMS_MODULUS) *
            ConstantsLib.EBC_AMOUNT_PARAMS_MODULUS; // Clear out empty digits

        return abi.encode(responseAmount);
    }

    /**
     * Get response amount from intent
     * @param intent Intent
     */
    function getResponseAmountFromIntent(bytes calldata intent) external pure returns (uint256) {
        uint256 responseAmount = abi.decode(intent, (uint256));
        return responseAmount;
    }
}
