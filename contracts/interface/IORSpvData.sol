// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IORSpvData {
    struct InjectionBlock {
        uint blockNumber;
        bytes32 blockHash;
    }

    event SaveHistoryBlock(bytes32 indexed blockHash, uint256 indexed blockNumber);

    function getBlockHash(uint blockNumber) external view returns (bytes32);

    function saveHistoryBlock() external;

    function injectByManager(
        uint startBlockNumber,
        uint endBlockNumber,
        InjectionBlock[] calldata injectionBlocks
    ) external;
}
