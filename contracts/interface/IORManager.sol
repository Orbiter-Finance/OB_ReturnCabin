// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operation.sol";

interface IORManager {
    event ChangeChain(uint256 indexed chainId, OperationsLib.ChainInfo chain);
    event ChangeToken(uint256 indexed chainId, address indexed tokenAddress, OperationsLib.TokenInfo token);
    event SupportPair(uint256 op, bytes32 indexed pairId);

    function addEBC(address ebc) external;

    function addPair(OperationsLib.PairStruct memory pair) external;

    function getChain(uint256)
        external
        view
        returns (
            uint256 id,
            uint256 chainId,
            uint256 batchLimit,
            uint256 maxDisputeTime,
            uint256 maxReceiptTime,
            uint256 stopDelayTime,
            uint256 maxBits
        );

    function getPairIds() external view returns (bytes32[] memory);

    function getPairs(bytes32)
        external
        view
        returns (
            uint256 sourceChain,
            uint256 destChain,
            address sourceToken,
            address destToken,
            address ebc
        );
 function calculatePairPledgeAmount(
        OperationsLib.LPActionStruct[] calldata _lps
    ) external view returns (OperationsLib.CalculatePairPledgeResponse[] memory);
    function getSPV() external view returns (address);

    function getTokenInfo(uint256 chainID, address tokenAddress) external view returns (OperationsLib.TokenInfo memory);

    function idChainID(uint256) external view returns (uint256);

    function initialize() external;

    function isSupportPair(bytes32 pairId) external view returns (bool);

    function removePair(bytes32 id) external;

    function revemoEBC(address ebc) external;

    function setChainInfo(
        uint256 id,
        uint256 chainId,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        uint256 maxReceiptTime,
        uint256 stopDelayTime,
        uint256 maxBits
    ) external;

    function setSPV(address spv) external;

    function setTokenInfo(
        uint256 chainId,
        uint256 tokenPresion,
        address tokenAddress,
        address mainAddress
    ) external;

    function tokenInfos(bytes32)
        external
        view
        returns (
            uint256 chainID,
            uint8 decimals,
            address tokenAddress,
            address mainTokenAddress
        );
}
