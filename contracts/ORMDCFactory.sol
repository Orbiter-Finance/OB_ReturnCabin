// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interface/IORMDCFactory.sol";
import "./interface/IORMakerDeposit.sol";
import "./interface/IORManager.sol";

contract ORMDCFactory is IORMDCFactory {
    IORManager private _manager;
    address private _implementation;
    uint256 private _mdcCreatedTotal;

    constructor(address manager_, address implementation_) {
        require(manager_ != address(0), "MZ");
        require(manager_ != address(0), "IZ");

        _manager = IORManager(manager_);
        _implementation = implementation_;
    }

    function manager() external view returns (address) {
        return address(_manager);
    }

    function implementation() external view returns (address) {
        return _implementation;
    }

    function mdcCreatedTotal() external view returns (uint) {
        return _mdcCreatedTotal;
    }

    function createMDC() external {
        require(_mdcCreatedTotal < _manager.maxMDCLimit(), "MML");
        address mdc = Clones.cloneDeterministic(
            _implementation,
            keccak256(abi.encodePacked(address(this), msg.sender))
        );

        unchecked {
            ++_mdcCreatedTotal;
        }

        IORMakerDeposit(mdc).initialize(msg.sender);

        emit MDCCreated(msg.sender, mdc);
    }
}
