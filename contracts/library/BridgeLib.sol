// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library BridgeLib {
    struct TokenInfo {
        uint token; // uint160(address) will overflow in the token used for starknet
        address mainnetToken;
        uint8 decimals;
    }

    struct ChainInfo {
        uint32 id;
        uint224 batchLimit;
        uint64 minVerifyChallengeSourceTxSecond;
        uint64 maxVerifyChallengeSourceTxSecond;
        uint64 minVerifyChallengeDestTxSecond;
        uint64 maxVerifyChallengeDestTxSecond;
        address[] spvs;
    }
}
