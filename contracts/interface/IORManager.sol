// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operation.sol";

interface IORManager {
    event ChangeChain(uint256 indexed chainId, OperationsLib.chainInfo chain);
    event ChangeToken(uint256 indexed chainId, address indexed tokenAddress, OperationsLib.tokenInfo token);
    event PairLogEvent(uint8 indexed opType, OperationsLib.pairChainInfo[] pairs);

    function calcLpPledgeAmount(
        OperationsLib.calcLpNeedPledgeAmountParams[] memory _lpinfos
    ) external view returns (address pledgedToken, OperationsLib.lpPledgeCalculate[] memory);

    function createPair(
        OperationsLib.pairChainInfo[] memory pairs,
        bytes32 rootHash,
        bytes32[] memory proof,
        bool[] memory proofFlags
    ) external;

    function deletePair(
        OperationsLib.pairChainInfo[] memory pairs,
        bytes32[] memory proof,
        bytes32 rootHash,
        bool[] memory proofFlags
    ) external;

    function ebcId() external view returns (uint256);

    function getChain(
        uint256
    )
        external
        view
        returns (
            uint16 chainid,
            uint256 batchLimit,
            uint256 maxDisputeTime,
            uint256 maxReceiptTime,
            uint256 stopDelayTime
        );

    function getEBC(uint256) external view returns (address);

    function getSPV() external view returns (address);

    function getTokenInfo(uint256 chainID, address tokenAddress) external view returns (OperationsLib.tokenInfo memory);

    function initialize() external;

    function isSupportPair(bytes32 pair, bytes32[] memory proof) external view returns (bool);

    function pairsRoot() external view returns (bytes32);

    function setChainInfo(
        uint256 chainID,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        uint256 maxReceiptTime,
        uint256 stopDelayTime
    ) external;

    function setEBC(address ebc) external;

    function setSPV(address spv) external;

    function setTokenInfo(uint256 chainID, uint256 tokenPresion, address tokenAddress, address mainAddress) external;

    function updateEBC(uint256 id, address addr) external;
}
