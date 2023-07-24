// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IORFeeManager {
    struct DealerInfo {
        uint feeRatio; // 10,000 percent
        bytes32 extraInfoHash;
    }

    event DealerUpdated(address indexed dealer, uint feeRatio, bytes extraInfo);
}
