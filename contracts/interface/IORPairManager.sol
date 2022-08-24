// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORPairManager {
    function initializePair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] memory _pairs) external;

    function createPair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] memory _pairs) external;

    function updatePair(
        bytes32[] memory leafs,
        bytes32[] memory proofs,
        bool[] memory proofFlag,
        OperationsLib.pairChainInfo[] memory newPairs
    ) external returns (bytes32);

    function removePair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] memory _pairs) external;
}
