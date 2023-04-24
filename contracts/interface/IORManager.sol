// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operation.sol";

interface IORManager {
    event DeletePair(bytes32 pairId);
    event RegisterChain(uint256 chain);
    event RegisterEBC(uint256 id, address ebcAddress);
    event RegisterPair(bytes32 pairId);
    event RegisterSPV(uint256 chain, address ebcAddress);
    event RegisterToken(uint256 indexed chainId, address indexed tokenAddress);

    function calculatePairPledgeAmount(
        OperationsLib.LPActionStruct[] memory _lps
    )
        external
        view
        returns (OperationsLib.CalculatePairPledgeResponse[] memory);

    function deletePair(bytes32 id) external;

    function ebcId() external view returns (uint256);

    function getChain(uint256)
        external
        view
        returns (
            uint256 id,
            uint256 batchLimit,
            uint256 maxDisputeTime,
            uint256 maxReceiptTime,
            uint256 stopDelayTime,
            uint256 maxBits
        );

    function getChainToken(bytes32)
        external
        view
        returns (
            uint256 chainID,
            uint8 decimals,
            address tokenAddress,
            address mainTokenAddress
        );

    function getEBC(address) external view returns (uint256);

    function getEBCAddress(uint256) external view returns (address);

    function getPairs(bytes32)
        external
        view
        returns (
            uint ebcId,
            uint256 sourceChain,
            uint256 destChain,
            address sourceToken,
            address destToken
        );

    function getSPV(uint256) external view returns (address);

    function getTokenInfo(uint256 chainID, address tokenAddress)
        external
        view
        returns (OperationsLib.TokenInfo memory);

    function isExistsPair(bytes32 id) external view returns (bool);

    function registerChain(
        uint256 id,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        uint256 maxReceiptTime,
        uint256 stopDelayTime,
        uint256 maxBits
    ) external;

    function registerEBC(address addr) external;

    function registerPair(OperationsLib.PairStruct memory pair) external;

    function registerSPV(uint256 chain, address addr) external;

    function registerToken(
        uint256 chainId,
        uint256 tokenPresion,
        address tokenAddress,
        address mainAddress
    ) external;
}