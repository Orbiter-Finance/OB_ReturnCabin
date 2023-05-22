// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operations.sol";

interface IORManager {
    event ChainInfoUpdated(uint indexed chainId, OperationsLib.ChainInfo chainInfo);

    function registerChain(OperationsLib.ChainInfo calldata chainInfo) external;

    function setChainSpvs(uint id, address[] calldata spvs) external;

    function setChainTokens(uint id, OperationsLib.TokenInfo[] calldata tokens) external;

    function getChainInfo(uint id) external view returns (OperationsLib.ChainInfo memory chainInfo);
}
