// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {RuleLib} from "../library/RuleLib.sol";

interface IOREventBinding {
    struct AmountParams {
        uint256 dealerIndex;
        uint256 ebcIndex;
        uint256 chainIdIndex;
    }

    function getSecurityCode(uint256 amount) external pure returns (uint256);

    function splitSecurityCode(uint256 securityCode) external pure returns (uint256[] memory);

    function getAmountParams(uint256 amount) external pure returns (AmountParams memory);

    function getResponseIntent(uint256 amount, RuleLib.RuleOneway calldata ro) external pure returns (bytes memory);

    function getResponseAmountFromIntent(bytes calldata intent) external pure returns (uint256);
}
