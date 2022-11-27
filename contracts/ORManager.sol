// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "hardhat/console.sol";

import "./interface/IORManager.sol";
import "./ORMakerDeposit.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ORManager is IORManager, Initializable, OwnableUpgradeable {
    mapping(uint256 => OperationsLib.chainInfo) public chainList;

    // chainId => tokenAddress
    mapping(uint256 => mapping(address => OperationsLib.tokenInfo)) private tokenInfos;
    uint256 private ebcId;
    mapping(uint256 => address) private ebc;
    bytes32 public pairsRoot;
    address private spv;

    function initialize() public initializer {
        __Ownable_init();
    }

    function setSPV(address spvAddress) external onlyOwner {
        spv = spvAddress;
    }

    function getSPV() external view returns (address) {
        return spv;
    }

    function setEBC(address addr) external onlyOwner {
        ebc[++ebcId] = addr;
    }

    function updateEBC(uint256 id, address addr) external onlyOwner {
        require(ebc[id] != address(0), "UPDATEEBC_ERROR");
        ebc[id] = addr;
    }

    function getEBC(uint256 id) external view returns (address) {
        require(ebc[id] != address(0), "EBC_UNINSTALL");
        address ebcAddress = ebc[id];
        return ebcAddress;
    }

    function setChainInfo(
        uint256 chainID,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        uint256 maxReceiptTime,
        address[] memory tokenList
    ) external onlyOwner {
        chainList[chainID] = OperationsLib.chainInfo(
            chainID,
            batchLimit,
            maxDisputeTime,
            maxReceiptTime,
            tokenList,
            true
        );
        emit ChangeChain(chainID, chainList[chainID]);
    }

    function getChainInfoByChainID(uint256 chainId) public view returns (OperationsLib.chainInfo memory) {
        require(chainList[chainId].isUsed == true, "MANAGER_CHAININFO_UNINSTALL");
        OperationsLib.chainInfo memory info = chainList[chainId];
        return info;
    }

    function setTokenInfo(
        uint256 chainID,
        address tokenAddress,
        uint256 tokenPresion,
        address mainAddress
    ) external onlyOwner {
        require(chainList[chainID].tokenList.length != 0, "SETTOKENINFO_UNSUPPORTTOKEN");
        for (uint256 i = 0; i < chainList[chainID].tokenList.length; i++) {
            address supportTokenAddress = chainList[chainID].tokenList[i];
            if (supportTokenAddress == tokenAddress) {
                tokenInfos[chainID][tokenAddress] = OperationsLib.tokenInfo(
                    chainID,
                    tokenAddress,
                    tokenPresion,
                    mainAddress
                );
            }
            emit ChangeToken(chainID, tokenAddress, tokenInfos[chainID][tokenAddress]);
        }
    }

    function getTokenInfo(uint256 chainID, address tokenAddress)
        external
        view
        returns (OperationsLib.tokenInfo memory)
    {
        require(chainList[chainID].isUsed == true, "CHAINID_NOTINSTALL");
        require(chainList[chainID].tokenList.length != 0, "CHAINID_UNSUPPORTTOKEN");
        for (uint256 i = 0; i < chainList[chainID].tokenList.length; i++) {
            address supportAddress = chainList[chainID].tokenList[i];
            if (supportAddress == tokenAddress) {
                return tokenInfos[chainID][tokenAddress];
            }
        }
        revert("UNSUPPORTTOKEN");
    }

    function isSupportChain(uint256 chainID, address token) public view returns (bool) {
        bool isSupportToken = false;
        for (uint256 i = 0; i < chainList[chainID].tokenList.length; i++) {
            if (chainList[chainID].tokenList[i] == token) {
                isSupportToken = true;
                break;
            }
        }
        return isSupportToken;
    }

    function createPair(
        OperationsLib.pairChainInfo[] calldata pairs,
        bytes32 rootHash,
        bytes32[] calldata proof,
        bool[] calldata proofFlags
    ) external {
        // is support chain
        bool isSupport = pairMultiProofVerifyCalldata(pairs, rootHash, proof, proofFlags);
        require(isSupport, "Hash Inconsistent");
        pairsRoot = rootHash;
        emit PairLogEvent(PairEventType.CREATE, pairs);
    }

    function deletePair(
        OperationsLib.pairChainInfo[] calldata pairs,
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 rootHash
    ) external {
        bool isSupport = pairMultiProofVerifyCalldata(pairs, pairsRoot, proof, proofFlags);
        require(isSupport, "Hash Inconsistent");
        pairsRoot = rootHash;
        emit PairLogEvent(PairEventType.DELETE, pairs);
    }

    function isSupportPair(bytes32 pair, bytes32[] calldata proof) public view returns (bool) {
        return MerkleProof.verifyCalldata(proof, pairsRoot, pair);
    }

    function isSupportPair(OperationsLib.pairChainInfo calldata pair, bytes32[] calldata proof)
        public
        view
        returns (bool)
    {
        bytes32 pairId = OperationsLib.getPairID(pair);
        return isSupportPair(pairId, proof);
    }

    function pairObjectToHash(OperationsLib.pairChainInfo[] calldata pairs) internal pure returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](pairs.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            leaves[i] = OperationsLib.getPairID(pairs[i]);
        }
        return leaves;
    }

    function pairMultiProofVerifyCalldata(
        OperationsLib.pairChainInfo[] calldata pairs,
        bytes32 root,
        bytes32[] calldata proof,
        bool[] calldata proofFlags
    ) internal pure returns (bool isSupport) {
        bytes32[] memory leaves = pairObjectToHash(pairs);
        return MerkleProof.multiProofVerifyCalldata(proof, proofFlags, root, leaves);
    }
}
