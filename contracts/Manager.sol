// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IManager.sol";
import "./library/Type.sol";

contract Manager is IManager, Ownable {
    event RegisterSPV(uint8 indexed chain, address indexed addr);
    event RegisterChain(uint8 indexed id);
    event RegisterChainToken(uint8 indexed chain, uint indexed token);

    mapping(uint8 => Types.ChainInfo) public chains;
    mapping(uint8 => address) public spvs;

    constructor() {}

    function registerSPV(uint8 chain, address addr) external onlyOwner {
        // only owner can register SPV
        require(addr != address(0), "zero-check");
        spvs[chain] = addr;
        emit RegisterSPV(chain, addr);
    }

    function registerChain(uint8 id, uint16 batchLimit, Types.TokenInfo[] memory tokenInfos) external onlyOwner {
        // only owner can register chain
        require(msg.sender == owner(), "Only owner can register chain");

        Types.ChainInfo storage chain = chains[id];
        chain.id = id;
        chain.batchLimit = batchLimit;

        for (uint256 i = 0; i < tokenInfos.length; ) {
            chain.tokens[tokenInfos[i].tokenAddress] = tokenInfos[i];
            unchecked {
                ++i;
            }
        }
        emit RegisterChain(id);
    }

    function registerToken(
        uint8 chainId,
        uint8 decimals,
        uint256 tokenAddress,
        address layer1Token
    ) external onlyOwner {
        // only owner can register token
        require(msg.sender == owner(), "Only owner can register token");

        Types.ChainInfo storage chain = chains[chainId];
        Types.TokenInfo storage token = chain.tokens[tokenAddress];

        token.decimals = decimals;
        token.tokenAddress = tokenAddress;
        token.layer1Token = layer1Token;
        emit RegisterChainToken(chainId, tokenAddress);
    }

    function getTokenInfo(uint8 chainID, uint tokenAddress) public view returns (Types.TokenInfo memory) {
        Types.ChainInfo storage chain = chains[chainID];
        return chain.tokens[tokenAddress];
    }
}
