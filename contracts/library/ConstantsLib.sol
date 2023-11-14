// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

library ConstantsLib {
    uint256 constant RATIO_MULTIPLE = 1000000;

    uint256 constant MIN_ENABLE_DELAY = 120; // Unit: second

    uint256 constant MAX_ENABLE_DELAY = 1800; // Unit: second

    uint256 constant DEALER_WITHDRAW_DELAY = 3600; // Unit: second

    uint256 constant WITHDRAW_DURATION = 3360; // Unit: second

    uint256 constant LOCK_DURATION = 240; // Unit: second

    // uint256 constant DEALER_WITHDRAW_DELAY = 30; // Unit: second for test off-chain

    // uint256 constant WITHDRAW_DURATION = 300; // Unit: second for test off-chain

    // uint256 constant LOCK_DURATION = 180; // Unit: second for test off-chain

    uint256 constant EBC_AMOUNT_PARAMS_MODULUS = 100000;
}
