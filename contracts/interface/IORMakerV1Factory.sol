// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IORMakerV1Factory {
    event MakerCreated(address maker, address pool);

    function initialize(address _manager, uint256 _makerMaxLimit) external;

    function createMaker() external returns (address);

    function setMakerMaxLimit(uint256 maxLimit) external;

    function setManager(address) external;

    function getManager() external view returns (address);
}
