// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./library/Operation.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PairManager {
    bytes32 public pairsHash;
    event InitializePair(Operations.Pair[]);
    event ChangePair(string index, Operations.Pair[]);

    function initializePair(bytes32 _pairsHash, Operations.Pair[] memory _pairs) external {
        pairsHash = _pairsHash;
        //  bytes32[] memory newLeafs = new bytes32[](_pairs.length);
        // for (uint256 i = 0; i < _pairs.length; i++) {
        //     bytes32 pairHash = Operations.pairToHash(_pairs[i]);
        //     newLeafs[i] = pairHash;
        // }
        emit InitializePair(_pairs);
    }

    function updatePair(
        bytes32[] memory leafs,
        bytes32[] memory proofs,
        bool[] memory proofFlag,
        Operations.Pair[] memory _newPairs
    ) external returns (bytes32) {
        require(leafs.length == _newPairs.length, "Array length is inconsistent");
        bool isVerify = MerkleProof.multiProofVerify(proofs, proofFlag, pairsHash, leafs);
        require(isVerify, "Verify failed");
        bytes32[] memory newLeafs = new bytes32[](leafs.length);
        for (uint256 i = 0; i < _newPairs.length; i++) {
            bytes32 pairHash = Operations.pairToHash(_newPairs[i]);
            newLeafs[i] = pairHash;
        }
        bytes32 newRoot = MerkleProof.processMultiProof(proofs, proofFlag, newLeafs);
        pairsHash = newRoot;
        emit ChangePair("Update", _newPairs);
        return pairsHash;
    }

    function removePair(bytes32 _pairsHash, Operations.Pair[] memory _pairs) external {
        pairsHash = _pairsHash;
        emit ChangePair("Remove", _pairs);
    }

    function createPair(bytes32 _pairsHash, Operations.Pair[] memory _pairs) external {
        pairsHash = _pairsHash;
        emit ChangePair("Create", _pairs);
    }
}
