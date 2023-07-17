// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORChallengeSpv} from "../interface/IORChallengeSpv.sol";

contract ORChallengeSpv is IORChallengeSpv {
    function verifyChallenge(
        bytes calldata proof,
        bytes32[2] calldata spvBlockHashs,
        bytes32 verifyInfoHash
    ) external pure returns (bool) {
        proof;
        spvBlockHashs;
        verifyInfoHash;

        // TODO: verify zkproof

        return true;
    }
}
