// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORSpvData} from "./interface/IORSpvData.sol";
import {IORManager} from "./interface/IORManager.sol";

contract ORSpvData is IORSpvData {
    IORManager private _manager;
    mapping(uint => bytes32) public blocks;

    constructor(address manager_) {
        require(manager_ != address(0), "MZ");
        _manager = IORManager(manager_);
    }

    function getBlockHash(uint blockNumber) external view returns (bytes32) {
        return blocks[blockNumber];
    }

    function saveHistoryBlock() external {
        uint64 spvBlockInterval = _manager.getSpvBlockInterval();

        for (uint i = 256; i > 0; ) {
            uint256 blockNumber = block.number - i;

            if (blockNumber % spvBlockInterval == 0) {
                if (blocks[blockNumber] == bytes32(0)) {
                    bytes32 blockHash = blockhash(blockNumber);
                    blocks[blockNumber] = blockHash;
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
    }
}
