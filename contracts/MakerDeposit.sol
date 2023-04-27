// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MakerDeposit {
    address public owner;
    function initialize(address _owner) public {
        require(_owner != address(0), "Owner address error");
        require(owner == address(0), "Already initialized");
        owner = _owner;
    }
    
}
