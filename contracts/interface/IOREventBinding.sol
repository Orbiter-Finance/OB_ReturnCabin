// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {RuleLib} from "../library/RuleLib.sol";

interface IOREventBinding {
    struct AmountParams {
        uint dealerIndex;
        uint ebcIndex;
        uint chainIdIndex;
    }

    function getSecurityCode(uint amount) external pure returns (uint);

    function splitSecurityCode(uint securityCode) external pure returns (uint[] memory);

    function getAmountParams(uint amount) external pure returns (AmountParams memory);

    function getResponseIntent(uint amount, RuleLib.RuleOneway calldata ro) external pure returns (bytes memory);

    function getResponseAmountFromIntent(bytes calldata intent) external pure returns (uint);
}
