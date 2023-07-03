// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library BridgeLib {
    struct TokenInfo {
        uint8 decimals;
        uint token; // uint160(address) will overflow in the token used for starknet
        address mainnetToken;
    }

    struct ChainInfo {
        uint32 id;
        uint224 batchLimit;
        address[] spvs;
        uint64 minVerifyChallengeSourceTxSecond;
        uint64 maxVerifyChallengeSourceTxSecond;
        uint64 minVerifyChallengeDestTxSecond;
        uint64 maxVerifyChallengeDestTxSecond;
        TokenInfo[] tokens;
    }
}
