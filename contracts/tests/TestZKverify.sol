// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVerifier} from "../interface/IVerifier.sol";

contract Verifier is IVerifier {
    function verify(bytes calldata proof) external pure override {
        (proof);
    }
}
