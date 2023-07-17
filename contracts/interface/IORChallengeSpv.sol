// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IORChallengeSpv {
    struct VerifyInfoSlot {
        address account; // Contract address
        bytes32 key;
        uint value;
    }

    struct VerifyInfo {
        uint[] data;
        VerifyInfoSlot[] slots;
    }

    function verifyChallenge(
        bytes calldata proof,
        bytes32[2] calldata spvBlockHashs,
        bytes32 verifyInfoHash
    ) external view returns (bool);
}
