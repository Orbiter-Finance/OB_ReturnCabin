// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./ORMakerDeposit.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interface/IORMakerV1Factory.sol";

contract ORMakerV1Factory is IORMakerV1Factory, OwnableUpgradeable {
    IORManager public getManager;
    uint256 public getMakerMaxLimit;
    uint256 public getMakerLimitUsed;
    mapping(address => address) public getMaker;

    function initialize(address _manager, uint256 _makerMaxLimit) external initializer {
        require(_manager != address(0), "Zero Check");
        __Ownable_init();
        getManager = IORManager(_manager);
        getMakerMaxLimit = _makerMaxLimit;
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
        getMakerLimitUsed++;
        require(getMaker[msg.sender] == address(0), "Exist Maker");
        ORMakerDeposit makerContract = new ORMakerDeposit{
            salt: keccak256(abi.encodePacked(address(this), msg.sender))
        }();
        getMaker[msg.sender] = address(makerContract);
        emit MakerCreated(msg.sender, address(makerContract));
        makerContract.initialize(msg.sender, address(this));
    }
}
