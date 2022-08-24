// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interface/IORPairManager.sol";

contract ORPairManager is IORPairManager {
    bytes32 public pairsHash;

    function initializePair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] memory pairs) external {
        pairsHash = _pairsHash;
        emit PairLogEvent(PairEventType.INIT, pairs);
    }

    function updatePair(
        bytes32[] memory leafs,
        bytes32[] memory proof,
        bool[] memory proofFlag,
        OperationsLib.pairChainInfo[] memory newPairs
    ) external returns (bytes32) {
        require(leafs.length == newPairs.length, "ArrayLengthInconsistent");
        bool isVerify = MerkleProof.multiProofVerify(proof, proofFlag, pairsHash, leafs);
        require(isVerify, "VerifyFailed");
        bytes32[] memory newLeafs = new bytes32[](leafs.length);
        for (uint256 i = 0; i < newPairs.length; i++) {
            bytes32 pairHash = OperationsLib.getLpID(newPairs[i]);
            newLeafs[i] = pairHash;
        }
        bytes32 newRoot = MerkleProof.processMultiProof(proof, proofFlag, newLeafs);
        pairsHash = newRoot;
        emit PairLogEvent(PairEventType.UPDATE, newPairs);
        return pairsHash;
    }

    function deletePair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] memory pairs) external {
        pairsHash = _pairsHash;
        emit PairLogEvent(PairEventType.DELETE, pairs);
    }

    function createPair(bytes32 _pairsHash, OperationsLib.pairChainInfo[] memory pairs) external {
        pairsHash = _pairsHash;
        emit PairLogEvent(PairEventType.CREATE, pairs);
    }

    function isSupportPair(bytes32 pair, bytes32[] memory proof) public view returns (bool isSupport) {
        isSupport = MerkleProof.verify(proof, pairsHash, pair);
    }
}
