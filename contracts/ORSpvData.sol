// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORSpvData} from "./interface/IORSpvData.sol";

contract ORSpvData is IORSpvData {
    mapping(bytes32 => uint) public _blockNumbers;

    function getBlockNumber(bytes32 blockHash) external view returns (uint) {
        return _blockNumbers[blockHash];
    }

    function savePreviousBlock() external {
        uint256 previousBlockNumber = block.number - 1;
        bytes32 previousBlockHash = blockhash(previousBlockNumber);
        _blockNumbers[previousBlockHash] = previousBlockNumber;
        emit SavePreviousBlock(previousBlockHash, previousBlockNumber);
    }
}
