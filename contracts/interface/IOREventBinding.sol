// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IOREventBinding {
    function getSecurityCode(uint amount) external pure returns (uint);

    function splitSecurityCode(uint securityCode) external pure returns (uint[] memory);

    function getResponseIntent(
        uint amount,
        address dest,
        uint[] calldata ruleValues
    ) external pure returns (bytes memory);
}
