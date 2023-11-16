// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interface/IORMDCFactory.sol";
import "./interface/IORMakerDeposit.sol";
import "./interface/IORManager.sol";
import {HelperLib} from "./library/HelperLib.sol";

contract ORMDCFactory is IORMDCFactory {
    using HelperLib for bytes;

    IORManager private _manager;
    address private _implementation;
    uint256 private _mdcCreatedTotal;

    constructor(address manager_, address implementation_) {
        require(manager_ != address(0), "MZ");
        require(implementation_ != address(0), "IZ");

        _manager = IORManager(manager_);
        _implementation = implementation_;
    }

    function manager() external view returns (address) {
        return address(_manager);
    }

    function implementation() external view returns (address) {
        return _implementation;
    }

    function mdcCreatedTotal() external view returns (uint256) {
        return _mdcCreatedTotal;
    }

    function createMDC() external {
        require(_mdcCreatedTotal < _manager.maxMDCLimit(), "MML");
        address mdcAddress = Clones.cloneDeterministic(_implementation, abi.encode(address(this), msg.sender).hash());

        unchecked {
            ++_mdcCreatedTotal;
        }

        IORMakerDeposit(mdcAddress).initialize(msg.sender);

        emit MDCCreated(msg.sender, mdcAddress);
    }

    function predictMDCAddress() external view returns (address) {
        address mdcAddress = Clones.predictDeterministicAddress(
            _implementation,
            abi.encode(address(this), msg.sender).hash()
        );
        return mdcAddress;
    }
}
