// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {IORRuleDecoder} from "../interface/IORRuleDecoder.sol";
import {RuleLib} from "../library/RuleLib.sol";
import {RLPReader} from "../library/RLPReader.sol";

contract RLPDecoder is IORRuleDecoder {
    using RLPReader for bytes;

    function decodeRule(bytes memory rlpBytes) public pure override returns (RuleLib.Rule memory rule) {
        rule = rlpBytes.decodeRule();
    }
}
