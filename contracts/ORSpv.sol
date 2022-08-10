// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "hardhat/console.sol";
import "./library/Spv.sol";

/// @title Simplified payment verification
/// @notice SPV proves that Source Tx has occurred in the Source Network.
contract ORSpv {
    address private owner;
    mapping(uint256 => bytes32) public txTree;
    mapping(bytes32 => bool) public verifyRecordsee;
    event ChangeTxTree(uint256 indexed chain, bytes32 root);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /// @notice Set new transaction tree root hash
    /// @param chain Public chain ID
    /// @param root New root hash
    function setMerkleRoot(uint256 chain, bytes32 root) external onlyOwner {
        txTree[chain] = root;
        emit ChangeTxTree(chain, root);
    }

    function setVerifyRecordsee(bytes32 txid) public onlyOwner {
        require(verifyRecordsee[txid] != true, "Txid Verified");
        verifyRecordsee[txid] = true;
    }

    function isVerify(bytes32 txid) public view returns (bool) {
        // bytes32 txid = SpvLib.calculationTxId(_txInfo);
        return verifyRecordsee[txid];
    }

    /// @notice Verify that the transaction is included in the tree
    /// @param _txInfo User transaction object
    /// @param _proofs Transaction proof path
    /// @return Exist or fail to verify
    function verifyProof(SpvLib.Transaction memory _txInfo, bytes32[] calldata _proofs) public view returns (bool) {
        bytes32 _leaf = keccak256(
            abi.encodePacked(
                _txInfo.chain,
                _txInfo.id,
                _txInfo.from,
                _txInfo.to,
                _txInfo.nonce,
                _txInfo.value,
                _txInfo.token
            )
        );
        bool _verify = SpvLib.verify(txTree[_txInfo.chain], _leaf, _proofs);
        return _verify;
    }
}
