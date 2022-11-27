// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operation.sol";

interface IORManager {
    enum PairEventType {
        CREATE,
        DELETE
    }
    event PairLogEvent(PairEventType indexed opType, OperationsLib.pairChainInfo[] pairs);
    event ChangeChain(uint256 indexed chainId, OperationsLib.chainInfo chain);
    event ChangeToken(uint256 indexed chainId, address indexed tokenAddress, OperationsLib.tokenInfo token);

    function setSPV(address spvAddress) external;

    function getSPV() external view returns (address);

    function setEBC(address ebcAddress) external;

    function getEBC(uint256 ebcid) external view returns (address);

    function updateEBC(uint256 ebcid, address ebcAddress) external;

    function setChainInfo(
        uint256,
        uint256,
        uint256,
        uint256,
        address[] memory
    ) external;

    function getChainInfoByChainID(uint256 chainID) external view returns (OperationsLib.chainInfo memory);

    function setTokenInfo(
        uint256,
        address,
        uint256,
        address
    ) external;

    function getTokenInfo(uint256, address) external view returns (OperationsLib.tokenInfo memory);

    function createPair(
        OperationsLib.pairChainInfo[] calldata pairs,
        bytes32 rootHash,
        bytes32[] calldata proof,
        bool[] calldata proofFlags
    ) external;

    function deletePair(
        OperationsLib.pairChainInfo[] calldata pairs,
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 rootHash
    ) external;

    function isSupportChain(uint256 chainID, address token) external view returns (bool);

    function isSupportPair(bytes32 pair, bytes32[] memory proof) external view returns (bool);

    function isSupportPair(OperationsLib.pairChainInfo calldata pair, bytes32[] calldata proof)
        external
        view
        returns (bool);
}
