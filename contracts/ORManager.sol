// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interface/IORManager.sol";
import "./ORMakerDeposit.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

contract ORManager is IORManager, Initializable, OwnableUpgradeable {
    mapping(uint256 => address) ebcPair;
    mapping(uint256 => OperationsLib.chainInfo) public chainList;
    mapping(uint256 => mapping(address => OperationsLib.tokenInfo)) public tokenInfos;
    uint256 ebcids;
    bytes32 public pairsRoot;
    address public spv;

    function initialize() public initializer {
        __Ownable_init();
    }

    function getEBCids() external view returns (uint256) {
        return ebcids;
    }

    function setSPV(address spvAddress) external onlyOwner returns (bool) {
        require(spvAddress != address(0), "SPV_INVALIDATE");
        spv = spvAddress;
        return true;
    }

    function getSPV() external view returns (address) {
        require(spv != address(0), "SPV_NOT_INSTALL");
        return spv;
    }

    function setEBC(address ebcAddress) external onlyOwner returns (bool) {
        ebcPair[++ebcids] = ebcAddress;
        return true;
    }

    function updateEBC(uint256 ebcid, address ebcAddress) external onlyOwner {
        require(ebcPair[ebcid] != address(0), "UPDATEEBC_ERROR");
        ebcPair[ebcid] = ebcAddress;
    }

    function getEBC(uint256 ebcid) external view returns (address) {
        require(ebcPair[ebcid] != address(0), "EBC_UNINSTALL");
        address ebcAddress = ebcPair[ebcid];
        return ebcAddress;
    }

    function setChainInfo(
        uint256 chainID,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        address[] memory tokenList
    ) external {
        require(chainList[chainID].isUsed == false, "CHAININFO_INSTALL_ALREADY");
        chainList[chainID] = OperationsLib.chainInfo(chainID, batchLimit, maxDisputeTime, tokenList, true);
    }

    function getChainInfoByChainID(uint256 chainID) public view returns (OperationsLib.chainInfo memory) {
        require(chainList[chainID].isUsed == true, "MANAGER_CHAININFO_UNINSTALL");
        OperationsLib.chainInfo memory info = chainList[chainID];
        return info;
    }

    function setTokenInfo(
        uint256 chainID,
        address tokenAddress,
        uint256 tokenPresion,
        address mainAddress
    ) external returns (bool) {
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
        }
        return false;
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
        bytes32 leaf = OperationsLib.getLpID(pair);
        return MerkleProof.verifyCalldata(proof, pairsRoot, leaf);
    }

    function pairObjectToHash(OperationsLib.pairChainInfo[] calldata pairs) internal pure returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](pairs.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            leaves[i] = OperationsLib.getLpID(pairs[i]);
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
