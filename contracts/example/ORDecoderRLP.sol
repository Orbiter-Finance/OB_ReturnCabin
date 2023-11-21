// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {IORDecoderRLP} from "../interface/IORDecoderRLP.sol";
import {RuleLib} from "../library/RuleLib.sol";
import "hardhat/console.sol";

contract RLPDecoder is IORDecoderRLP {
    using RuleLib for bytes;

    function decodeRule(bytes memory rlpBytes) public view returns (RuleLib.Rule memory rule) {
        uint256 gas = gasleft();
        rule = rlpBytes.decodeRule();
        console.log("decodeRule gas used: %d", gas - gasleft());
    }
}
