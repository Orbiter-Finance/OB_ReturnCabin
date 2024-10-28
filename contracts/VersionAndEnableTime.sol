// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ConstantsLib} from "./library/ConstantsLib.sol";

contract VersionAndEnableTime {
    // uint192 private _version;
    uint128 private _version = 1;
    uint64 private _blockNumber = 1;
    uint64 private _enableTime = 100;

    // TODO: modify requires more gas
    // modifier versionIncreaseAndEnableTime(uint64 enableTime) {
    //     require(enableTime - block.timestamp >= ConstantsLib.MIN_ENABLE_DELAY, "OFET");

    //     _;
    //     _version += 1;

    //     _enableTime = enableTime;
    // }

    function versionIncreaseAndEnableTime(uint64 enableTime) internal {
        require(
            (enableTime >= ConstantsLib.MIN_ENABLE_DELAY + block.timestamp) &&
                (enableTime <= ConstantsLib.MAX_ENABLE_DELAY + block.timestamp) &&
                (enableTime > _enableTime),
            "OFET"
        );
        uint64 blockNumberCurrent = uint64(block.number);
        require(blockNumberCurrent > _blockNumber, "BNE");

        _version += 1;
        _blockNumber = blockNumberCurrent;
        _enableTime = enableTime;
    }

    function getVersionAndEnableTime() external view returns (uint128 version, uint64 blockNumber, uint64 enableTime) {
        return (_version, _blockNumber, _enableTime);
    }
}
