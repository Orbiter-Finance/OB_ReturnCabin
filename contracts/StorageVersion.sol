// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract StorageVersion {
    uint private _storageVersion;

    modifier storageVersionIncrease() {
        _;
        _storageVersion += 1;
    }

    function storageVersion() external view returns (uint) {
        return _storageVersion;
    }
}
