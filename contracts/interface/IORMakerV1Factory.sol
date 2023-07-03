// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./IORManager.sol";

interface IORMakerV1Factory {
    event MakerCreated(address maker, address pool);
    event ChangeMakerMaxLimit(uint256 max);

    function initialize(address _manager, uint256 _makerMaxLimit, address _implementation) external;

    function createMaker() external;

    function setMakerMaxLimit(uint256 maxLimit) external;

    function setManager(address) external;

    function getManager() external view returns (IORManager manager);
}
