// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ConstantsLib} from "./library/ConstantsLib.sol";

contract VersionAndEnableTime {
    // uint192 private _version;
    uint128 private _version;
    uint64 private _blockNumber;
    uint64 private _enableTime;

    // TODO: modify requires more gas
    // modifier versionIncreaseAndEnableTime(uint64 enableTime) {
    //     require(enableTime - block.timestamp >= ConstantsLib.MIN_ENABLE_DELAY, "OFET");

    //     _;
    //     _version += 1;

    //     _enableTime = enableTime;
    // }

    function versionIncreaseAndEnableTime(uint64 enableTime) public {
        require(
            (enableTime - block.timestamp >= ConstantsLib.MIN_ENABLE_DELAY) &&
                (enableTime - block.timestamp <= ConstantsLib.MAX_ENABLE_DELAY) &&
                (enableTime > _enableTime),
            "OFET"
        );
        uint64 curBlockNumber = uint64(block.number);
        require(curBlockNumber > _blockNumber, "BNE");

        _version += 1;
        _blockNumber = curBlockNumber;
        _enableTime = enableTime;
    }

    function getVersionAndEnableTime() external view returns (uint128 version, uint64 blockNumber, uint64 enableTime) {
        return (_version, _blockNumber, _enableTime);
    }
}
