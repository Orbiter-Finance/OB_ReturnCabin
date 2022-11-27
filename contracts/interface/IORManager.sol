// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operation.sol";

interface IORManager {
    enum PairEventType {
        CREATE,
        DELETE
    }
    event ChangeChain(uint256 indexed chainId, OperationsLib.chainInfo chain);
    event ChangeToken(uint256 indexed chainId, address indexed tokenAddress, OperationsLib.tokenInfo token);
    event PairLogEvent(PairEventType indexed opType, OperationsLib.pairChainInfo[] pairs);

    function chainList(uint256)
        external
        view
        returns (
            uint256 chainid,
            uint256 batchLimit,
            uint256 maxDisputeTime,
            uint256 maxReceiptTime,
            uint256 stopDelay,
            bool isUsed
        );

    function createPair(
        OperationsLib.pairChainInfo[] memory pairs,
        bytes32 rootHash,
        bytes32[] memory proof,
        bool[] memory proofFlags
    ) external;

    function deletePair(
        OperationsLib.pairChainInfo[] memory pairs,
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 rootHash
    ) external;

    function ebc(uint256) external view returns (address);

    function ebcId() external view returns (uint256);

    function getChainInfoByChainID(uint256 chainId) external view returns (OperationsLib.chainInfo memory);

    function getEBC(uint256 id) external view returns (address);

    function getTokenInfo(uint256 chainID, address tokenAddress) external view returns (OperationsLib.tokenInfo memory);

    function initialize() external;

    function isSupportChain(uint256 chainID, address token) external view returns (bool);

    function isSupportPair(bytes32 pair, bytes32[] memory proof) external view returns (bool);

    function isSupportPair(OperationsLib.pairChainInfo memory pair, bytes32[] memory proof)
        external
        view
        returns (bool);

    function pairsRoot() external view returns (bytes32);

    function setChainInfo(
        uint256 chainID,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        uint256 maxReceiptTime,
        uint256 stopDelay,
        address[] memory tokenList
    ) external;

    function setEBC(address addr) external;

    function setSPV(address spvAddress) external;

    function setTokenInfo(
        uint256 chainID,
        address tokenAddress,
        uint256 tokenPresion,
        address mainAddress
    ) external;

    function spv() external view returns (address);

    function tokenInfos(uint256, address)
        external
        view
        returns (
            uint256 chainID,
            address tokenAddress,
            uint256 tokenPresion,
            address mainTokenAddress
        );

    function updateEBC(uint256 id, address addr) external;
}
