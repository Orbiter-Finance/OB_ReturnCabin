// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IORSpvData {
    event SavePreviousBlock(bytes32 indexed previousBlockHash, uint256 indexed previousBlockNumber);

    function getBlockNumber(bytes32 blockHash) external view returns (uint);

    function savePreviousBlock() external;
}
