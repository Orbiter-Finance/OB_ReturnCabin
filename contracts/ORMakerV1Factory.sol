// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./ORMakerDeposit.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interface/IORMakerV1Factory.sol";

contract ORMakerV1Factory is IORMakerV1Factory, OwnableUpgradeable {
    address public manager;
    uint256 public makerMaxLimit;
    uint256 public makerLimitUsed;
    mapping(address => address) public getMaker;

    function initialize(address _manager, uint256 _makerMaxLimit) public initializer {
        __Ownable_init();
        manager = _manager;
        makerMaxLimit = _makerMaxLimit;
    }

    function setManager(address value) external onlyOwner {
        require(value != address(0), "Manager Incorrect");
        manager = value;
    }

    // Set the Maker maximum to create an upper limit.
    function setMakerMaxLimit(uint256 maxLimit) external onlyOwner {
        makerMaxLimit = maxLimit;
    }

    function createMaker() external returns (address pool) {
        require(makerLimitUsed < makerMaxLimit, "Exceeded the Maker limit");
        makerLimitUsed++;
        require(getMaker[msg.sender] == address(0), "Exists Maker");
        ORMakerDeposit makerContract = new ORMakerDeposit{
            salt: keccak256(abi.encodePacked(address(this), msg.sender))
        }();
        getMaker[msg.sender] = address(makerContract);
        makerContract.initialize(msg.sender, address(this));
        pool = address(makerContract);
        emit MakerCreated(msg.sender, pool);
    }
}
