// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/**
 * Zk-Snark Verifier
 */
interface IVerifier {
    function verify(bytes calldata proof) external view;
}
