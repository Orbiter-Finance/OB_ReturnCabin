// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

error NotEmptyRootHash();

error NotEqualNodeValue();

error InvalidRootHash(bytes32 wantRootHash, bytes32 getRootHash);

error InvalidTxHash(bytes32 wantTxHash, bytes32 getTxHash);

error InvalidTxInfo();

error InvalidBlockHash(bytes32 wantBlockHash, bytes32 getBlockHash);

error InvalidMPTProofs();

error InvalidProofOfInclusion();

error L1InputNotContainL2Tx();

error MaxTrackBlockNumber();
