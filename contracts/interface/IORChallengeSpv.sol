// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IORChallengeSpv {
    struct VerifyInfoSlot {
        address account; // Contract address
        bytes32 key;
        uint value;
    }

    struct VerifyInfoTxInfo {
        uint32 chainId;
        bytes32 txHash;
        uint from;
        uint to;
        uint token;
        uint amount;
        uint nonce;
        uint64 timestamp;
    }

    struct VerifyInfo {
        VerifyInfoTxInfo txInfo;
        VerifyInfoSlot[] slots;
    }

    function verifyChallenge(
        bytes calldata proof,
        bytes32 spvBlockHash,
        bytes32 verifyInfoHash
    ) external view returns (bool);
}
