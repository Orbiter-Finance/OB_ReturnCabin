// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "hardhat/console.sol";
import "./library/Spv.sol";

contract ORSpv {
    mapping(uint256 => bytes32) public txTree;
    event ChangeTxTree(uint256 indexed chain, bytes32 root);

    function setMerkleRoot(uint256 chain, bytes32 root) external {
        txTree[chain] = root;
        emit ChangeTxTree(chain, root);
    }

    
    function verifyProof(SpvLib.Transaction memory _txInfo, bytes32[] calldata _proofs) external view returns (bool) {
        bytes32 _leaf = keccak256(abi.encodePacked(_txInfo.chain, _txInfo.id, _txInfo.from, _txInfo.to, _txInfo.nonce, _txInfo.value, _txInfo.token));
        bool _verify = SpvLib.verify(txTree[_txInfo.chain], _leaf, _proofs);
        return _verify;
    }
}
