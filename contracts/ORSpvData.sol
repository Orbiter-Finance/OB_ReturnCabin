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

    function getBlockHash(uint blkNumber) external view returns (bytes32) {
        return _blocks[blkNumber];
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

        uint i = 0;
        uint ni = 0;
        for (; i < injectionBlocks.length; ) {
            unchecked {
                ni = i + 1;
            }

            InjectionBlock memory injectionBlock = injectionBlocks[i];

            require(startBlockNumber < injectionBlock.blkNumber, "SGEIB");
            require(endBlockNumber > injectionBlock.blkNumber, "ELEIB");
            require(startBlockNumber + _blockInterval * ni == injectionBlock.blkNumber, "IIB");
            require(_blocks[injectionBlock.blkNumber] == bytes32(0), "BE");

            _blocks[injectionBlock.blkNumber] = injectionBlock.blockHash;
            emit HistoryBlockSaved(injectionBlock.blkNumber, injectionBlock.blockHash);

            i = ni;
        }
    }
}
