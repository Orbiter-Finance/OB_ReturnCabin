// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interface/IORMakerV1Factory.sol";
interface  IMakerImplementation {
    function initialize(address _owner) external;
}
contract ORMakerV1Factory is IORMakerV1Factory, OwnableUpgradeable {
    IORManager public getManager;
    uint256 public getMakerMaxLimit;
    uint256 public getMakerLimitUsed;
    address public implementation;
    mapping(address => address) public getMaker;

    function initialize(address _manager, uint256 _makerMaxLimit,address _implementation) external initializer {
        require(_manager != address(0), "Zero Check");
        __Ownable_init();
        getManager = IORManager(_manager);
        getMakerMaxLimit = _makerMaxLimit;
        implementation = _implementation;
    }

    function setManager(address value) external onlyOwner {
        require(value != address(0), "Manager Zero");
        getManager = IORManager(value);
    }

    // Set the Maker maximum to create an upper limit.
    function setMakerMaxLimit(uint256 maxLimit) external onlyOwner {
        getMakerMaxLimit = maxLimit;
        emit ChangeMakerMaxLimit(maxLimit);
    }
    function createMaker() external {
        require(getMakerLimitUsed < getMakerMaxLimit, "Maker Max limit");
        require(getMaker[msg.sender] == address(0), "Exist Maker");
        address makerPoolAddr = Clones.cloneDeterministic(implementation, keccak256(abi.encodePacked(address(this), msg.sender)));
        getMaker[msg.sender] = makerPoolAddr;
        getMakerLimitUsed++;
        emit MakerCreated(msg.sender, makerPoolAddr);
        IMakerImplementation(makerPoolAddr).initialize(msg.sender);
    }
}
