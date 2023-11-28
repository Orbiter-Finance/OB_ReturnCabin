// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {IORDecoderRLP} from "../interface/IORDecoderRLP.sol";
import {RuleLib} from "../library/RuleLib.sol";
import {RLPReader} from "../library/RLPReader.sol";

contract RLPDecoder is IORDecoderRLP {
    using RLPReader for bytes;

    function decodeRule(bytes memory rlpBytes) public pure returns (RuleLib.Rule memory rule) {
        rule = rlpBytes.decodeRule();
    }
}
