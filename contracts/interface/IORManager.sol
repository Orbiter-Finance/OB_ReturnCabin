// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operations.sol";

interface IORManager {
    event ChainInfoUpdated(uint indexed id, OperationsLib.ChainInfo chainInfo);

    function registerChains(OperationsLib.ChainInfo[] calldata chains_) external;

    function updateChainSpvs(uint id, address[] calldata spvs, uint[] calldata indexs) external;

    function updateChainTokens(uint id, OperationsLib.TokenInfo[] calldata token, uint[] calldata indexs) external;

    function getChainInfo(uint id) external view returns (OperationsLib.ChainInfo memory chainInfo);
}
