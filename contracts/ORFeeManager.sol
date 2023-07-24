// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IORFeeManager.sol";
import "./interface/IORManager.sol";

contract ORFeeManager is IORFeeManager, Ownable {
    // Ownable._owner use a slot

    IORManager private _manager;
    mapping(address => DealerInfo) private _dealers;

    constructor(address owner_, address manager_) {
        require(owner_ != address(0), "OZ");
        require(manager_ != address(0), "MZ");

        _transferOwnership(owner_);
        _manager = IORManager(manager_);
    }

    function updateDealer(uint feeRatio, bytes calldata extraInfo) external {
        bytes32 extraInfoHash = keccak256(extraInfo);

        _dealers[msg.sender] = DealerInfo(feeRatio, extraInfoHash);

        emit DealerUpdated(msg.sender, feeRatio, extraInfo);
    }

    function getDealerInfo(address dealer) external view returns (DealerInfo memory) {
        return _dealers[dealer];
    }
}
