// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interface/IORPairManager.sol";

contract ORPairManager is IORPairManager {
    bytes32 public pairsRoot;

    function initializePair(bytes32 _pairsRoot, OperationsLib.pairChainInfo[] calldata pairs) external {
        pairsRoot = _pairsRoot;
        emit PairLogEvent(PairEventType.INIT, pairs);
    }

    function updatePair(
        bytes32 leaf,
        bytes32[] calldata proof,
        OperationsLib.pairChainInfo memory pair
    ) external returns (bytes32) {
        // require(leafs.length == newPairs.length, "ArrayLengthInconsistent");
        bool isVerify = MerkleProof.verifyCalldata(proof, pairsRoot, leaf);
        require(isVerify, "VerifyFailed");
        // bytes32[] memory newLeafs = new bytes32[](leafs.length);
        // for (uint256 i = 0; i < newPairs.length; i++) {
        //     bytes32 pairHash = OperationsLib.getLpID(newPairs[i]);
        //     newLeafs[i] = pairHash;
        // }
        bytes32 newPairHash = OperationsLib.getLpID(pair);
        bytes32 newRoot = MerkleProof.processProofCalldata(proof, newPairHash);
        pairsRoot = newRoot;
        OperationsLib.pairChainInfo[] memory _pairs = new OperationsLib.pairChainInfo[](1);
        _pairs[0] = pair;
        emit PairLogEvent(PairEventType.UPDATE, _pairs);
        return pairsRoot;
    }

    function deletePair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] calldata pairs) external {
        pairsRoot = _pairsHash;
        emit PairLogEvent(PairEventType.DELETE, pairs);
    }

    function createPair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] calldata pairs) external {
        pairsRoot = _pairsHash;
        emit PairLogEvent(PairEventType.CREATE, pairs);
    }

    function isSupportPair(bytes32 pair, bytes32[] calldata proof) public view returns (bool isSupport) {
        isSupport = MerkleProof.verifyCalldata(proof, pairsRoot, pair);
    }
}
