// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {RuleLib} from "../library/RuleLib.sol";

interface IORRuleDecoder {
    function decodeRule(bytes memory rlpBytes) external view returns (RuleLib.Rule memory rule);
}
