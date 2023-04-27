// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./library/Type.sol";
import "hardhat/console.sol";
import "./interface/IEventBinding.sol";

contract EventBinding is IEventBinding {
    constructor() {}
    function getResponseHash(Types.Transaction memory tx, bool isSource) external view returns (bytes32) {
        bytes32 data;
        return data;
    }
}
