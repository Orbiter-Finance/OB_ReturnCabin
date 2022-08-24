// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORPairManager {
    enum PairEventType {
        INIT,
        CREATE,
        UPDATE,
        DELETE
    }
    event PairLogEvent(PairEventType index, OperationsLib.pairChainInfo[]);

    function initializePair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] memory pairs) external;

    function createPair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] memory pairs) external;

    function updatePair(
        bytes32 leaf,
        bytes32[] memory proof,
        OperationsLib.pairChainInfo memory newPairs
    ) external returns (bytes32);

    function deletePair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] memory pairs) external;

    function isSupportPair(bytes32 pair, bytes32[] memory proof) external view returns (bool);
}
