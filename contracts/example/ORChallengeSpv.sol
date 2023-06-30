// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORChallengeSpv} from "../interface/IORChallengeSpv.sol";

contract ORChallengeSpv is IORChallengeSpv {
    function verifyChallenge(
        bytes calldata proof,
        bytes32 spvBlockHash,
        bytes32 verifyInfoHash
    ) external pure returns (bool) {
        proof;
        spvBlockHash;
        verifyInfoHash;

        // TODO: verify zkproof

        return true;
    }
}
