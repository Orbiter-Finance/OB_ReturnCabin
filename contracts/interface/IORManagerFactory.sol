// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IORManagerFactory {
    event MakerMap(address indexed makerAddress, address indexed contractAddress);

    function setSPV(address spvAddress) external returns (bool);

    function getSPV() external view returns (address);

    function setEBC(address ebcAddress) external returns (bool);

    function getEBC(uint256 ebcid) external returns (address);

    function updateEBC(uint256 ebcid, address ebcAddress) external;

    function setChainInfo(
        uint256,
        uint256,
        uint256,
        address[] memory
    ) external;

    function getChainInfoByChainID(uint256 chainID) external returns (OperationsLib.chainInfo memory);

    function setTokenInfo(
        uint256,
        address,
        uint256,
        address
    ) external returns (bool);

    function getTokenInfo(uint256, address) external view returns (OperationsLib.tokenInfo memory);

    function createMaker() external returns (address);
}
