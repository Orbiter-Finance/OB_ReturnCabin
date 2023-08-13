// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ConstantsLib} from "./library/ConstantsLib.sol";

contract VersionAndEnableTime {
    uint192 private _version;
    uint64 private _enableTime;

    // TODO: modify requires more gas
    // modifier versionIncreaseAndEnableTime(uint64 enableTime) {
    //     require(enableTime - block.timestamp >= ConstantsLib.MIN_ENABLE_DELAY, "OFET");

    //     _;
    //     _version += 1;

    //     _enableTime = enableTime;
    // }

    function versionIncreaseAndEnableTime(uint64 enableTime) public {
        require(enableTime - block.timestamp >= ConstantsLib.MIN_ENABLE_DELAY, "OFET");

        _version += 1;
        _enableTime = enableTime;
    }

    function getVersionAndEnableTime() external view returns (uint192 version, uint64 enableTime) {
        return (_version, _enableTime);
    }
}
