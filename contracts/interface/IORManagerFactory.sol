// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORManagerFactory {
    event AddPariChain(address indexed tokenAddress, Operations.pairChainInfo pairChain);
    event AddPariChains(address indexed tokenAddress, Operations.pairChainInfo[] pairChains);
    event MakerMap(address indexed makerAddress, address indexed contractAddress);

    function setPariChainInfo(address tokenAddress, Operations.pairChainInfo[] memory pairChain)
        external
        returns (bool);

    function setEBC(address ebcAddress) external returns (bool);

    function setChainInfo(
        uint256 chainID,
        bytes memory chainName,
        uint256 batchLimit,
        uint256 maxDisputeTime
    ) external returns (bool);

    function setTokenInfo(
        address tokenAddress,
        bytes memory tokenName,
        uint256 tokenPresion
    ) external returns (bool);

    function getPariChainInfo(address tokenAddress) external view returns (Operations.pairChainInfo[] memory);

    function getEBC(uint256 ebcid) external returns (address);

    function setChainInfoByChainID(
        uint256,
        bytes memory,
        uint256,
        uint256
    ) external;

    function getChainInfoByChainID(uint256 chainID) external returns (Operations.chainInfo memory);

    function getTokenInfoByTokenAddress(address tokenAddress) external returns (Operations.tokenInfo memory);

    function getTokenInfoByTokenName(bytes memory tokenName) external view returns (Operations.tokenInfo memory);

    function setOwner(address) external;

    function createMaker() external returns (address);
}
