// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract L1StorageBlockHash {
    event SetL1StorageBlockHash(uint256 indexed currentlyBlockNumber, bytes32 indexed currentlyBlockHash);

    mapping(uint256 => bytes32) public storageBlockHash;

    function setStorageBlockHash() external {
        uint256 currentlyBlockNumber = block.number - 1;
        bytes32 currentlyBlockHash = blockhash(currentlyBlockNumber);
        storageBlockHash[currentlyBlockNumber] = currentlyBlockHash;

        emit SetL1StorageBlockHash(currentlyBlockNumber, currentlyBlockHash);
    }
}
