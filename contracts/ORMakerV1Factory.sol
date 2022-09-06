// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./ORMakerDeposit.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interface/IORMakerV1Factory.sol";

contract ORMakerV1Factory is IORMakerV1Factory, OwnableUpgradeable {
    address private manager;
    mapping(address => address) public getMaker;

    function initialize(address _manager) public initializer {
        __Ownable_init();
        manager = _manager;
    }

    function setManager(address value) external onlyOwner {
        require(value != address(0), "Manager Incorrect");
        manager = value;
    }

    function getManager() external view returns (address) {
        return manager;
    }

    function createMaker() external returns (address pool) {
        require(getMaker[msg.sender] == address(0), "Exists Maker");
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, block.timestamp));
        ORMakerDeposit makerContract = new ORMakerDeposit{salt: salt}();
        makerContract.initialize(msg.sender, address(this));
        pool = address(makerContract);
        getMaker[msg.sender] = pool;
        emit MakerCreated(msg.sender, pool);
    }
}
