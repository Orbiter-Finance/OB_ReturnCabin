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

    function blockInterval() external view returns (uint64);

    function updateBlockInterval(uint64 blockInterval_) external;

    function saveHistoryBlocksRoots() external;

    function getStartBlockNumber(bytes32 blocksRoot) external view returns (uint);

    function injectOwner() external view returns (address);

    function updateInjectOwner(address injectOwner_) external;

    function injectBlocksRoots(
        bytes32 blocksRoot0,
        bytes32 blocksRoot1,
        InjectionBlocksRoot[] calldata injectionBlocksRoots
    ) external;
}
