// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract L1BlockHash {
    event setBlockHash(uint256 currentlyBlockNumber, bytes32 currentlyBlockHash);

    mapping(uint256 => bytes32) public blockHash;

    function setStorageBlockHash() external returns (bool) {
        uint256 currentlyBlockNumber = block.number - 1;
        bytes32 currentlyBlockHash = blockhash(currentlyBlockNumber);
        blockHash[currentlyBlockNumber] = currentlyBlockHash;

        emit setBlockHash(currentlyBlockNumber, currentlyBlockHash);
        return true;
    }
}
