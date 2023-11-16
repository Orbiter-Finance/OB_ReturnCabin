// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IORSpvData {
    struct InjectionBlocksRoot {
        uint256 startBlockNumber;
        bytes32 blocksRoot;
    }

    event BlockIntervalUpdated(uint64 blockInterval);
    event InjectOwnerUpdated(address injectOwner);
    event HistoryBlocksRootSaved(uint256 indexed startBlockNumber, bytes32 blocksRoot, uint256 blockInterval);

    function getBlocksRoot(uint256 startBlockNumber) external view returns (bytes32);

    function saveHistoryBlocksRoots() external;

    function blockInterval() external view returns (uint64);

    function updateBlockInterval(uint64 blockInterval_) external;

    function injectOwner() external view returns (address);

    function updateInjectOwner(address injectOwner_) external;

    function injectBlocksRoots(
        uint256 blockNumber0,
        uint256 blockNumber1,
        InjectionBlocksRoot[] calldata injectionBlocksRoots
    ) external;
}
