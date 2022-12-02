// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interface/IORSpv.sol";

/// @title Simplified payment verification
/// @notice SPV proves that Source Tx has occurred in the Source Network.
contract ORSpv is IORSpv, Initializable, OwnableUpgradeable {
    mapping(uint256 => bytes32) public getMakerTxHash;
    mapping(uint256 => bytes32) public getUserTxHash;

    function initialize() external initializer {
        __Ownable_init();
    }

    /// @notice Set new transaction tree root hash
    /// @param chain Public chain ID
    /// @param root New root hash
    function setUserTxTreeRoot(uint256 chain, bytes32 root) external onlyOwner {
        getUserTxHash[chain] = root;
    }

    /// @notice Set the list of transactions for the market maker to delay payment collection roothash
    /// @param chain Public chain ID
    /// @param root New root hash
    function setMakerTxTreeRoot(uint256 chain, bytes32 root) external onlyOwner {
        getMakerTxHash[chain] = root;
    }

    function getSpvTxId(OperationsLib.txInfo calldata _txInfo) internal pure returns (bytes32) {
        bytes32 id = keccak256(
            abi.encodePacked(
                _txInfo.lpid,
                _txInfo.chainID,
                _txInfo.txHash,
                _txInfo.sourceAddress,
                _txInfo.destAddress,
                _txInfo.nonce,
                _txInfo.amount,
                _txInfo.tokenAddress,
                _txInfo.timestamp,
                _txInfo.responseAmount,
                _txInfo.responseSafetyCode,
                _txInfo.ebcid
            )
        );
        return id;
    }

    /// @notice Transaction list of unpaid users
    /// @param _txInfo User transaction object
    /// @param _proof Transaction proof path
    /// @return Exist or fail to verify
    function verifyUserTxProof(OperationsLib.txInfo calldata _txInfo, bytes32[] calldata _proof)
        public
        view
        returns (bool)
    {
        bytes32 _leaf = getSpvTxId(_txInfo);
        return verify(getUserTxHash[_txInfo.chainID], _leaf, _proof);
    }

    /// @notice List of merchant transactions with delayed payment
    /// @param _txInfo User transaction object
    /// @param _proof Transaction proof path
    /// @return Exist or fail to verify
    function verifyMakerTxProof(OperationsLib.txInfo calldata _txInfo, bytes32[] calldata _proof)
        public
        view
        returns (bool)
    {
        bytes32 _leaf = getSpvTxId(_txInfo);
        return verify(getMakerTxHash[_txInfo.chainID], _leaf, _proof);
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
    ) internal pure returns (bool) {
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
