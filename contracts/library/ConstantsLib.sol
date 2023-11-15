// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

library ConstantsLib {
    uint256 constant RATIO_MULTIPLE = 1000000;

    uint256 constant MIN_ENABLE_DELAY = 120; // Unit: second

    uint256 constant MAX_ENABLE_DELAY = 1800; // Unit: second

    uint256 constant DEALER_WITHDRAW_DELAY = 3600; // Unit: second

    uint256 constant WITHDRAW_DURATION = 3360; // Unit: second

    uint256 constant LOCK_DURATION = 240; // Unit: second

    uint constant EBC_AMOUNT_PARAMS_MODULUS = 100000;

    uint constant MIN_CHALLENGE_DEPOSIT_AMOUNT = 0.005 ether;
}
