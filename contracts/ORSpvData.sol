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
        uint256 previousBlockNumber = block.number - 1;
        bytes32 previousBlockHash = blockhash(previousBlockNumber);
        blocks[previousBlockHash] = previousBlockNumber;
        emit SaveHistoryBlock(previousBlockHash, previousBlockNumber);
    }

    function injectByManager(
        uint startBlockNumber,
        uint endBlockNumber,
        InjectionBlock[] calldata injectionBlocks
    ) external {
        require(msg.sender == address(_manager), "PD");
    }
}
