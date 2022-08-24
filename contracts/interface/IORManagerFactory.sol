// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IORManagerFactory {
    event MakerMap(address indexed makerAddress, address indexed contractAddress);

    function setEBC(address ebcAddress) external returns (bool);

    function setChainInfo(
        uint256 chainID,
        bytes memory chainName,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        address[] memory tokenList
        // OperationsLib.tokenInfo[] memory tokenList
    ) external;

    function setTokenInfo(
        uint256,
        address,
        uint256,
        bytes memory,
        address
    ) external returns (bool);

    function getTokenInfo(uint256, address) external view returns (OperationsLib.tokenInfo memory);

    function getEBC(uint256 ebcid) external returns (address);

    function updateEBC(uint256 ebcid, address ebcAddress) external;

    function getChainInfoByChainID(uint256 chainID) external returns (OperationsLib.chainInfo memory);

    function createMaker() external returns (address);
}
