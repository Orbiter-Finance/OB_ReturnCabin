// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IL2Bridge.sol";
import "./interface/IMakerFactory.sol";
import "./library/Type.sol";
import "hardhat/console.sol";
import "./interface/IManager.sol";

interface IMakerDeposit {
    function initialize() external;
}

contract MakerFactory is IMakerFactory, IL2Bridge, Ownable {
    IManager public manager;
    uint256 public makerMaxLimit;
    uint256 public makerLimitUsed;
    address public implementation;
    mapping(address => address) public makerByOwner;
    mapping(address => address) public makerL2ReceiveContract;

    event MakerCreated(address indexed owner, address indexed maker);

    constructor(IManager _manager, uint256 _makerMaxLimit, address _implementation) {
        require(address(_manager) != address(0), "Manager address is zero");
        manager = _manager;
        makerMaxLimit = _makerMaxLimit;
        implementation = _implementation;
    }

    function setManager(IManager _manager) external onlyOwner {
        require(address(_manager) != address(0), "Manager address is zero");
        manager = _manager;
    }

    function setMakerMaxLimit(uint256 _makerMaxLimit) external onlyOwner {
        makerMaxLimit = _makerMaxLimit;
    }

    function createMaker() external {
        require(makerLimitUsed < makerMaxLimit, "Maker creation limit reached");
        require(makerByOwner[msg.sender] == address(0), "Maker already created for owner");
        ++makerLimitUsed;
        address mdcAddr = Clones.cloneDeterministic(
            implementation,
            keccak256(abi.encodePacked(address(this), msg.sender))
        );
    
        makerByOwner[msg.sender] = mdcAddr;
        emit MakerCreated(msg.sender, mdcAddr);

        IMakerDeposit(mdcAddr).initialize();
    }

    function handleMessage(bytes calldata message) external {
        // TODO: L2 Message
    }
}
