// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IORMakerV1Factory {
    event MakerCreated(address merchant, address store);

    function initialize(address) external;

    function createMaker() external returns (address);

    function setManager(address) external;

    function getManager() external view returns (address);
}
