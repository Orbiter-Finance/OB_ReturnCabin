// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORSpvData} from "./interface/IORSpvData.sol";
import {IORManager} from "./interface/IORManager.sol";

contract ORSpvData is IORSpvData {
    IORManager private _manager;
    mapping(uint => bytes32) private _blocks;

    constructor(address manager_) {
        require(manager_ != address(0), "MZ");
        _manager = IORManager(manager_);
    }

    function getBlockHash(uint blockNumber) external view returns (bytes32) {
        return _blocks[blockNumber];
    }

    function saveHistoryBlock() external {
        uint64 spvBlockInterval = _manager.getSpvBlockInterval();

        for (uint i = 256; i > 0; ) {
            uint256 blockNumber = block.number - i;

            if (blockNumber % spvBlockInterval == 0) {
                if (_blocks[blockNumber] == bytes32(0)) {
                    bytes32 blockHash = blockhash(blockNumber);
                    _blocks[blockNumber] = blockHash;
                    emit SaveHistoryBlock(blockHash, blockNumber);
                }
            }

            unchecked {
                i--;
            }
        }
    }

    function injectByManager(
        uint startBlockNumber,
        uint endBlockNumber,
        InjectionBlock[] calldata injectionBlocks
    ) external {
        require(msg.sender == address(_manager), "PD");
        require(startBlockNumber < endBlockNumber, "SNLE");

        // Make sure the startBlockNumber and endBlockNumber at storage
        require(_blocks[startBlockNumber] != bytes32(0), "SZ");
        require(_blocks[endBlockNumber] != bytes32(0), "EZ");

        uint64 spvBlockInterval = _manager.getSpvBlockInterval();

        for (uint i = 0; i < injectionBlocks.length; ) {
            require(startBlockNumber < injectionBlocks[i].blockNumber, "SGEIB");
            require(endBlockNumber > injectionBlocks[i].blockNumber, "ELEIB");
            require(startBlockNumber + spvBlockInterval * (i + 1) == injectionBlocks[i].blockNumber, "IIB");

            _blocks[injectionBlocks[i].blockNumber] = injectionBlocks[i].blockHash;
            emit SaveHistoryBlock(injectionBlocks[i].blockHash, injectionBlocks[i].blockNumber);

            unchecked {
                i++;
            }
        }
    }
}
