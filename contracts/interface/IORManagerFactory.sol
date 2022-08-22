// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IORManagerFactory {
    event AddPariChain(address indexed tokenAddress, Operations.pairChainInfo pairChain);
    event AddPariChains(address indexed tokenAddress, Operations.pairChainInfo[] pairChains);
    event MakerMap(address indexed makerAddress, address indexed contractAddress);

    function initPariChainInfo(Operations.pairChainInfo[] memory) external returns (bool);

    function addPariChainInfo(
        Operations.pairChainInfo[] memory,
        bytes32,
        bool[] memory
    ) external returns (bool);

    function updatePariChainInfo(
        Operations.pairChainInfo[] memory,
        Operations.pairChainInfo[] memory,
        bytes32,
        bool[] memory
    ) external returns (bool);

    function deletePariChainInfo(
        Operations.pairChainInfo[] memory,
        bytes32,
        bool[] memory
    ) external returns (bool);

    function setEBC(address ebcAddress) external returns (bool);

    function setChainInfo(
        uint256 chainID,
        bytes memory chainName,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        Operations.tokenInfo[] memory tokenList
    ) external;

    function setTokenInfo(
        uint256,
        address,
        uint256
    ) external returns (bool);

    function getTokenInfo(
        uint256,
        address,
        bytes8
    ) external view returns (Operations.tokenInfo memory);

    function getEBC(uint256 ebcid) external returns (address);

    function updateEBC(uint256 ebcid, address ebcAddress) external;

    function getChainInfoByChainID(uint256 chainID) external returns (Operations.chainInfo memory);

    function createMaker() external returns (address);
}
