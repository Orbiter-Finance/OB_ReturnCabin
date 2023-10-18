// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORSpvData} from "./interface/IORSpvData.sol";
import {IORManager} from "./interface/IORManager.sol";

// TODO: test
import "hardhat/console.sol";

contract ORSpvData is IORSpvData {
    IORManager private _manager;
    uint64 private _blockInterval = 20;

    mapping(uint => bytes32) private _blocks;

    constructor(address manager_) {
        require(manager_ != address(0), "MZ");
        _manager = IORManager(manager_);
    }

    modifier onlyManager() {
        require(msg.sender == address(_manager), "Forbidden: caller is not the manager");
        _;
    }

    function getBlockHash(uint blockNumber) external view returns (bytes32) {
        return _blocks[blockNumber];
    }

    function saveHistoryBlocks() external {
        for (uint i = 256; i > 0; ) {
            uint256 blockNumber = block.number - i;

            if (blockNumber % _blockInterval == 0) {
                if (_blocks[blockNumber] == bytes32(0)) {
                    bytes32 blockHash = blockhash(blockNumber);
                    _blocks[blockNumber] = blockHash;
                    emit HistoryBlockSaved(blockNumber, blockHash);
                }
            }

            unchecked {
                i--;
            }
        }
    }

    function getBlockInterval() external view returns (uint64) {
        return _blockInterval;
    }

    function updateBlockInterval(uint64 blockInterval) external onlyManager {
        require(blockInterval > 0, "IV");
        _blockInterval = blockInterval;

        emit BlockIntervalUpdated(blockInterval);
    }

    function injectBlocksByManager(
        uint startBlockNumber,
        uint endBlockNumber,
        InjectionBlock[] calldata injectionBlocks
    ) external onlyManager {
        require(startBlockNumber < endBlockNumber, "SNLE");

        // Make sure the startBlockNumber and endBlockNumber at storage
        require(_blocks[startBlockNumber] != bytes32(0), "SZ");
        require(_blocks[endBlockNumber] != bytes32(0), "EZ");

        for (uint i = 0; i < injectionBlocks.length; ) {
            require(startBlockNumber < injectionBlocks[i].blockNumber, "SGEIB");
            require(endBlockNumber > injectionBlocks[i].blockNumber, "ELEIB");
            require(startBlockNumber + _blockInterval * (i + 1) == injectionBlocks[i].blockNumber, "IIB");

            _blocks[injectionBlocks[i].blockNumber] = injectionBlocks[i].blockHash;
            emit HistoryBlockSaved(injectionBlocks[i].blockNumber, injectionBlocks[i].blockHash);

            unchecked {
                i++;
            }
        }
    }
}
