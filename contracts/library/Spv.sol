// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./Operation.sol";

library SpvLib {
    function calculationTxId(OperationsLib.txInfo memory _txInfo) internal pure returns (bytes32 txid) {
        txid = keccak256(
            abi.encodePacked(
                _txInfo.chainID,
                _txInfo.txHash,
                _txInfo.lpid,
                _txInfo.sourceAddress,
                _txInfo.destAddress,
                _txInfo.nonce,
                _txInfo.amount,
                _txInfo.tokenAddress
            )
        );
    }

    /// @notice Validation exists in the merkle tree
    /// @param root This root will be compared to the calculated root
    /// @param leaf Leaf nodes that need proof
    /// @param proof Provide proof path
    /// @return true or false
    function verify(
        bytes32 root,
        bytes32 leaf,
        bytes32[] memory proof
    ) public pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}
