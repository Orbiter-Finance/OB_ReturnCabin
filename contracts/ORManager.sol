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

    // TODO: setting the same chainId or token affect the protocol?
    function registerChains(OperationsLib.ChainInfo[] calldata chains_) external onlyOwner {
        unchecked {
            for (uint i = 0; i < chains_.length; i++) {
                chains[chains_[i].id] = chains_[i];
                emit ChainInfoUpdated(chains_[i].id, chains_[i]);
            }
        }
    }

    function updateChainSpvs(uint id, address[] calldata spvs, uint[] calldata indexs) external onlyOwner {
        unchecked {
            for (uint i = 0; i < spvs.length; i++) {
                if (i < indexs.length) {
                    chains[id].spvs[indexs[i]] = spvs[i];
                } else {
                    chains[id].spvs.push(spvs[i]);
                }
            }
        }
        emit ChainInfoUpdated(id, chains[id]);
    }

    function updateChainTokens(
        uint id,
        OperationsLib.TokenInfo[] calldata tokens,
        uint[] calldata indexs
    ) external onlyOwner {
        unchecked {
            for (uint i = 0; i < tokens.length; i++) {
                if (i < indexs.length) {
                    chains[id].tokens[indexs[i]] = tokens[i];
                } else {
                    chains[id].tokens.push(tokens[i]);
                }
            }
        }
        emit ChainInfoUpdated(id, chains[id]);
    }

    function getChainInfo(uint id) external view returns (OperationsLib.ChainInfo memory chainInfo) {
        chainInfo = chains[id];
    }
}
