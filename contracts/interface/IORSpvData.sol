// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IORSpvData {
    struct InjectionBlocksRoot {
        uint startBlockNumber;
        bytes32 blocksRoot;
    }

    event BlockIntervalUpdated(uint64 blockInterval);
    event InjectOwnerUpdated(address injectOwner);
    event HistoryBlocksRootSaved(uint indexed startBlockNumber, bytes32 blocksRoot, uint blockInterval);

    function getBlocksRoot(uint startBlockNumber) external view returns (bytes32);

    function saveHistoryBlocksRoots() external;

    function blockInterval() external view returns (uint64);

    function updateBlockInterval(uint64 blockInterval_) external;

    function injectOwner() external view returns (address);

    function updateInjectOwner(address injectOwner_) external;

    function injectBlocksRoots(
        uint blockNumber0,
        uint blockNumber1,
        InjectionBlocksRoot[] calldata injectionBlocksRoots
    ) external;
}
