// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/IORManager.sol";
import "./interface/IORProtocal.sol";
import "./Multicall.sol";

contract ORManager is IORManager, Ownable, Multicall {
    mapping(uint => OperationsLib.ChainInfo) chains;

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    function registerChain(OperationsLib.ChainInfo calldata chainInfo) external onlyOwner {
        chains[chainInfo.id] = chainInfo;
        emit ChainInfoUpdated(chainInfo.id, chainInfo);
    }

    function setChainSpvs(uint id, address[] calldata spvs) external onlyOwner {
        chains[id].spvs = spvs;
        emit ChainInfoUpdated(id, chains[id]);
    }

    function setChainTokens(uint id, OperationsLib.TokenInfo[] calldata tokens) external onlyOwner {
        // OperationsLib.TokenInfo[] storage tokens = new OperationsLib.TokenInfo[](0);

        // tokens = new OperationsLib.TokenInfo[](0);
        for (uint i = 0; i < tokens.length; i++) {
            // tokens.push(tokens[i]);
        }

        emit ChainInfoUpdated(id, chains[id]);
    }

    function getChainInfo(uint id) external view returns (OperationsLib.ChainInfo memory chainInfo) {
        chainInfo = chains[id];
    }
}
