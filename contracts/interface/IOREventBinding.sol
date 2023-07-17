// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IOREventBinding {
    struct AmountParams {
        uint dealerIndex;
        uint ebcIndex;
        uint chainIdIndex;
    }

    function getSecurityCode(uint amount) external pure returns (uint);

    function splitSecurityCode(uint securityCode) external pure returns (uint[] memory);

    function getAmountParams(uint amount) external pure returns (AmountParams memory);

    function getResponseIntent(uint amount, uint[] calldata ruleValues) external pure returns (bytes memory);
}
