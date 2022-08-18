// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
// import "./library/Spv.sol";
import "./interface/IORSpv.sol";

/// @title Simplified payment verification
/// @notice SPV proves that Source Tx has occurred in the Source Network.
contract ORSpv is IORSpv {
    address private owner;
    mapping(uint256 => bytes32) public makerTxTree;
    mapping(uint256 => bytes32) public userTxTree;
    mapping(bytes32 => bool) public verifyRecordsee;

    // event ChangeTxTree(uint256 indexed chain, bytes32 root);

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
    function setUserTxTreeRoot(uint256 chain, bytes32 root) external onlyOwner {
        userTxTree[chain] = root;
    }

    /// @notice Set the list of transactions for the market maker to delay payment collection roothash
    /// @param chain Public chain ID
    /// @param root New root hash
    function setMakerTxTreeRoot(uint256 chain, bytes32 root) external onlyOwner {
        makerTxTree[chain] = root;
    }

    function setVerifyRecordsee(bytes32 txid) public onlyOwner {
        require(verifyRecordsee[txid] != true, "Txid Verified");
        verifyRecordsee[txid] = true;
    }

    function isVerify(bytes32 txid) public view returns (bool) {
        // bytes32 txid = SpvLib.calculationTxId(_txInfo);
        return verifyRecordsee[txid];
    }

    /// @notice Transaction list of unpaid users
    /// @param _txInfo User transaction object
    /// @param _proofs Transaction proof path
    /// @return Exist or fail to verify
    function verifyUserTxProof(SpvLib.Transaction memory _txInfo, bytes32[] calldata _proofs)
        public
        view
        returns (bool)
    {
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
        bool _verify = SpvLib.verify(userTxTree[_txInfo.chain], _leaf, _proofs);
        return _verify;
    }

    /// @notice List of merchant transactions with delayed payment
    /// @param _txInfo User transaction object
    /// @param _proofs Transaction proof path
    /// @return Exist or fail to verify
    function verifyMakerTxProof(SpvLib.Transaction memory _txInfo, bytes32[] calldata _proofs)
        public
        view
        returns (bool)
    {
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
        bool _verify = SpvLib.verify(makerTxTree[_txInfo.chain], _leaf, _proofs);
        return _verify;
    }
}
