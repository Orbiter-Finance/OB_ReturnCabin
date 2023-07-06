// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IORChallengeSpv {
    struct VerifyInfoSlot {
        address account; // Contract address
        bytes32 key;
        uint value;
    }

    struct VerifyInfo {
        uint[] txInfos; // chainId, hash, from, to, token, amount, nonce, timestamp, others...
        VerifyInfoSlot[] slots;
    }

    function verifyChallenge(
        bytes calldata proof,
        bytes32 spvBlockHash,
        bytes32 verifyInfoHash
    ) external view returns (bool);
}
