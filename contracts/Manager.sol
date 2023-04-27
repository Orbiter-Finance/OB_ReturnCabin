// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IManager.sol";
import "./library/Type.sol";

contract Manager is IManager, Ownable {
    event RegisterSPV(uint256 indexed chain, address indexed addr);
    event RegisterChain(uint256 indexed id);

    mapping(uint256 => Types.ChainInfo) public chains;
    mapping(uint256 => address) public spvs;

    constructor() {}

    function registerSPV(uint256 chain, address addr) public {
        // only owner can register SPV
        require(addr != address(0), "zero-check");
        spvs[chain] = addr;
        emit RegisterSPV(chain, addr);
    }

    function registerChain(uint256 id, uint256 batchLimit, Types.TokenInfo[] memory tokenInfos) public {
        // only owner can register chain
        require(msg.sender == owner(), "Only owner can register chain");

        Types.ChainInfo storage chain = chains[id];
        chain.id = id;
        chain.batchLimit = batchLimit;

        for (uint256 i = 0; i < tokenInfos.length; i++) {
            chain.tokens[tokenInfos[i].tokenAddress] = tokenInfos[i];
        }
        emit RegisterChain(id);
    }

    function registerToken(uint256 chainId, uint256 tokenPrecision, address tokenAddress, address mainAddress) public {
        // only owner can register token
        require(msg.sender == owner(), "Only owner can register token");

        Types.ChainInfo storage chain = chains[chainId];
        Types.TokenInfo storage token = chain.tokens[tokenAddress];

        token.precision = tokenPrecision;
        token.tokenAddress = tokenAddress;
        token.mainAddress = mainAddress;
    }

    function getTokenInfo(uint256 chainID, address tokenAddress) public view returns (Types.TokenInfo memory) {
        Types.ChainInfo storage chain = chains[chainID];
        return chain.tokens[tokenAddress];
    }
}
